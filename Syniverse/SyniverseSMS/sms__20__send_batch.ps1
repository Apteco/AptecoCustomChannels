################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{

        ReplyToSMS = ""
        EmailFieldName = "Email"
        Username = "a"
        MessageName ="Transaktionsbestätigung DEU"
        ReplyToEmail = ""
        UrnFieldName = "Bestell ID"
        Password = "b"
        ListName = "Transaktionsbestätigung DEU"
        TransactionType = "Replace"
        Path = "c:\faststats\Publish\Handel\system\Deliveries\PowerShell_Transaktionsbestätigung DEU_e8c49206-91c3-4d7d-8bc3-1340f3918a75.txt"
        SmsFieldName = "mdn"
        CommunicationKeyFieldName = "Communication Key"   
    }
}

################################################
#
# NOTES
#
################################################

<#

https://github.com/Syniverse/QuickStart-BatchNumberLookup-Python/blob/master/ABA-example-external.py

FILEUPLOAD UP TO 2 GB allowed

#>

################################################
#
# SCRIPT ROOT
#
################################################

if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"
$moduleName = "UPLOAD"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
$maxWriteCount = $settings.rowsPerUpload
$uploadsFolder = $settings.uploadsFolder
$mssqlConnectionString = $settings.responseDB

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data  #, System.Text.Encoding

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $moduleName )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message " $( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# READ TEMPLATE
#-----------------------------------------------

# TODO [ ] replace this with the generic mssql functions

Write-Log -message "Loading template with name $( $params.MessageName )"

$mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

"Trying to load the data from MSSQL"

# define query -> currently the age of the date in the query has to be less than 12 hours
$mssqlQuery = @"
SELECT *
FROM (
 SELECT *
  ,row_number() OVER (
   PARTITION BY CreativeTemplateId ORDER BY Revision DESC
   ) AS prio
 FROM [dbo].[CreativeTemplate]
 ) ct
WHERE ct.prio = '1' and MessageContentType = 'SMS' and Name = '$( $params.MessageName )'
ORDER BY CreatedOn
"@

# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = new-object System.Data.DataTable
$mssqlTable.Load($mssqlResult)
    
# close connection
$mssqlConnection.Close()

# extract the important template information
# https://stackoverflow.com/questions/34212731/powershell-get-all-strings-between-curly-braces-in-a-file
$creativeTemplateText = $mssqlTable[0].Creative
$creativeTemplateToken = [Regex]::Matches($creativeTemplateText, '(?<={{)(.*?)(?=}})') | Select -ExpandProperty Value

#-----------------------------------------------
# DEFINE NUMBERS
#-----------------------------------------------

Write-Log -message "Start to create a new file"

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values

$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8


#-----------------------------------------------
# PREPARE HEADERS
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}

#-----------------------------------------------
# SINGLE SMS SEND
#-----------------------------------------------

# TODO [ ] put this workflow in parallel groups


$parsedData = @()
$data | ForEach {

    $row = $_
    $txt = $creativeTemplateText
    
    # replace all tokens in text with personalised data
    $creativeTemplateToken | ForEach {
        $token = $_
        $txt = $txt -replace "{{$( $token )}}", $row.$token
    }

    # create new object with data
    $newRow = New-Object PSCustomObject
    $newRow | Add-Member -MemberType NoteProperty -Name "mdn" -Value $row."$( $params.SmsFieldName )"
    $newRow | Add-Member -MemberType NoteProperty -Name "message" -Value $txt
    
    # add to array
    $parsedData += $newRow
}

# create new guid
$smsId = [guid]::NewGuid()

# Filenames
$tempFolder = "$( $uploadsFolder )\$( $smsId )"
New-Item -ItemType Directory -Path $tempFolder
$smsFile = "$( $tempFolder )\sms.csv"

$parsedData | Export-Csv -Path $smsFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

$url = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests"


$parsedData | ForEach {
    
    $text = $_.message
    $mobile = $_.mdn
    $mobileCountry = $settings.countryMap.($mobile.Substring(0,3))
    $mobileChannel = $settings.channels.($mobileCountry)

    $bodyContent = @{
        "from"="channel:$( $mobileChannel )"
        "to"=@($mobile)
        #"media_urls"=@()
        #"attachments"=@()
        #"pause_before_transmit"=$false
        #"verify_number"=$false
        "body"=$text #$smsTextTranslations.Item($mobileCountry)
        #"consent_requirement"="NONE"
    }
   

    Write-Log -message "SMS to: '$( $bodyContent.to )' with channel '$( $bodyContent.from )' and content '$( $bodyContent.body )'"
    #$res

    $body = $bodyContent | ConvertTo-Json -Depth 8 -Compress
    #$body
    $res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose -ContentType "application/json;charset=UTF-8" 

    Write-Log -message "SMS result: $( $res.id )"


}

#$res
#$res

#$messages = Invoke-RestMethod -Uri $url -Method Get -Verbose -Headers $headers
#$messages.list | Out-GridView


<#
################################################
#
# INSERT COMMUNICATION KEY IN SQLITE
#
################################################

$cols = @($params.UrnFieldName,$params.CommunicationKeyFieldName)
$commExportId = Split-File -inputPath $params.Path -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $cols -writeCount -1 -outputDoubleQuotes $true

Write-Log -message "Done with export id $( $commExportId )!" >> $logfile
$commFile = Get-ChildItem -Path "$( $scriptPath )\$( $commExportId )" | Select -First 1
$commFilePath = $commFile.FullName -replace "\\","/"

".mode csv",".separator \t",".import $( $commFilePath ) communications" | .\sqlite3.exe syniverse.sqlite
#>


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [ ] check return results

# count the number of successful upload rows
$recipients = 0 # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference for the upload in Epi
$transactionId = 0 #$recipientListID

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername

}

# return the results
$return
