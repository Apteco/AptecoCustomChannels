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

$debug = $false

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	   "TransactionType"="Replace"
        "Password"="b"
        "scriptPath"="D:\Scripts\Syniverse\SMS"
        "MessageName"="SMS Wallet Offer"
        "EmailFieldName"="Email"
        "SmsFieldName"="mdn"
        "Path"="d:\faststats\Publish\Handel\system\Deliveries\PowerShell_SMS Wallet Offer_2aa41347-0c0a-43ae-987c-dc7210ba9281.txt"
        "ReplyToEmail"=""
        "Username"="a"
        "ReplyToSMS"=""
        "UrnFieldName"="Kunden ID"
        "ListName"="SMS Wallet Offer"
        "CommunicationKeyFieldName"="Communication Key"
    }
}

#Copy-Item -Path $params.Path -Destination "D:\Scripts\Syniverse\SMS"

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
$moduleName = "SYNSMSUPLOAD"
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
$maxWriteCount = 100 #$settings.rowsPerUpload
$uploadsFolder = "$( $scriptPath )\upload" #$settings.uploadsFolder
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

Add-Type -AssemblyName System.Data #, System.Web  #, System.Text.Encoding

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


#-----------------------------------------------
# REGEX FOR EXTRACT OF LINKS AND TOKENS IN TEMPLATE
#-----------------------------------------------

<#
# some notes and other way for selections
# https://www.regextester.com/97589
$hash=@{}
$creativeTemplateText | select-string -AllMatches '(http[s]?)(:\/\/)([^\s,]+)' | %{ $hash."Valid URLs"=$_.Matches.value }
$hash
#>

# Regex patterns
$regexForValuesBetweenCurlyBrackets = "(?<={{)(.*?)(?=}})"
$regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"

# extract the important template information
# https://stackoverflow.com/questions/34212731/powershell-get-all-strings-between-curly-braces-in-a-file
$creativeTemplateText = $mssqlTable[0].Creative
$creativeTemplateToken = [Regex]::Matches($creativeTemplateText, $regexForValuesBetweenCurlyBrackets) | Select -ExpandProperty Value
$creativeTemplateLinks = [Regex]::Matches($creativeTemplateText, $regexForLinks) | Select -ExpandProperty Value


#-----------------------------------------------
# SWITCH TO UTF8
#-----------------------------------------------
# Call an external program first so the console encoding command works in ISE, too. Good explanation here: https://social.technet.microsoft.com/Forums/scriptcenter/en-US/b92b15c8-6854-4d3e-8a35-51b4b56276ba/powershell-ise-vs-consoleoutputencoding?forum=ITCG
ping | Out-Null

# Change the console output to UTF8
$originalConsoleCodePage = [Console]::OutputEncoding.CodePage
[Console]::OutputEncoding = [text.encoding]::utf8

#$PSVersionTable | Out-File "D:\Scripts\Syniverse\SMS\test.txt"

#-----------------------------------------------
# DEFINE NUMBERS
#-----------------------------------------------

Write-Log -message "Start to create a new file"

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values

#$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8
$data = get-content -path "$( $params.Path )" -encoding UTF8 -raw | ConvertFrom-Csv -Delimiter "`t"


#-----------------------------------------------
# PREPARE HEADERS
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}

$contentType = "application/json; charset=utf-8"


#-----------------------------------------------
# SINGLE SMS SEND
#-----------------------------------------------

# TODO [ ] put this workflow in parallel groups
Write-Log -message "Parsing data and putting links into syniverse functions via regex"


$parsedData = @()
$data | ForEach {

    $row = $_
    $txt = $creativeTemplateText
    
    # replace all tokens in links in text with personalised data
    $creativeTemplateLinks | ForEach {
        $linkTemplate = $_
        $linkReplaced = $_
        $creativeTemplateToken | ForEach {
            $token = $_
            $linkReplaced = $linkReplaced -replace [regex]::Escape("{{$( $token )}}"), [uri]::EscapeDataString($row.$token)
            Write-Log -message "$( ($row.$token).toString() ) - $( [uri]::EscapeDataString($row.$token) )"
        }
        # the #track function in syniverse automatically creates a trackable short link in the SMS
        $txt = $txt -replace [regex]::Escape($linkTemplate), "#track(""$( $linkReplaced )"")"
    }    

    # replace all remaining tokens in text with personalised data
    $creativeTemplateToken | ForEach {
        $token = $_
        $txt = $txt -replace [regex]::Escape("{{$( $token )}}"), $row.$token
    }

    # Unescape and escape data to catch remaining umlauts in the template
    #$txt = [uri]::EscapeDataString([uri]::UnescapeDataString($txt))

    # create new object with data
    $newRow = New-Object PSCustomObject
    $newRow | Add-Member -MemberType NoteProperty -Name "mdn" -Value $row."$( $params.SmsFieldName )"
    $newRow | Add-Member -MemberType NoteProperty -Name "message" -Value $txt
    $newRow | Add-Member -MemberType NoteProperty -Name "Urn" -Value $row.($params.UrnFieldName)
    $newRow | Add-Member -MemberType NoteProperty -Name "CommunicationKey" -Value $row.($params.CommunicationKeyFieldName)
    
    # add to array
    $parsedData += $newRow
}

# create new guid
$smsId = $processId.Guid

# Filenames
$tempFolder = "$( $uploadsFolder )\$( $smsId )"
New-Item -ItemType Directory -Path $tempFolder
Write-Log -message "Creating files in $( $tempFolder )"
$smsFile = "$( $tempFolder )\sms.csv"

$parsedData | Export-Csv -Path $smsFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

$url = "$( $settings.base )scg-external-api/api/v1/messaging/message_requests"

$results = @()
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
    $res = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -Verbose -ContentType $contentType

    Write-Log -message "SMS result: $( $res.id )"

    # create new object with data
    $newResult = New-Object PSCustomObject
    $newResult | Add-Member -MemberType NoteProperty -Name "messageid" -Value $res.id
    $newResult | Add-Member -MemberType NoteProperty -Name "Urn" -Value $parsedData.Urn
    $newResult | Add-Member -MemberType NoteProperty -Name "CommunicationKey" -Value $parsedData.CommunicationKey

    $results += $newResult

}

# Get message requests
#Invoke-RestMethod -Uri "https://api.syniverse.com/scg-external-api/api/v1/messaging/message_requests/nbFtqIqiLcqPQLA1HukB" -Method Get -Headers $headers -Verbose -ContentType "application/json" 
#$res

#$messages = Invoke-RestMethod -Uri $url -Method Get -Verbose -Headers $headers
#$messages.list | Out-GridView



################################################
#
# INSERT COMMUNICATION KEY IN MSSQL
#
################################################

Write-Log -message "Putting results in response database"

# open connection again
$mssqlConnection.Open()

$results | ForEach {
    
    $res = $_

    $insert = @"
        INSERT INTO [dbo].[Messages] ([service],[Urn],[BroadcastTransactionID],[MessageID],[CommunicationKey])
          VALUES ('SYNSMS','$( $res.Urn )','$( $processId.Guid )','$( $res.messageid )','$( $res.CommunicationKey )')
"@

    try {

        # execute command
        $levelUpdateMssqlCommand = $mssqlConnection.CreateCommand()
        $levelUpdateMssqlCommand.CommandText = $insert
        $updateResult = $levelUpdateMssqlCommand.ExecuteScalar() #$mssqlCommand.ExecuteNonQuery()
    
    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        Write-Log -message $errText


    } finally {
    
            

    }


}

# close connection
$mssqlConnection.Close()



################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [ ] check return results

# count the number of successful upload rows
$recipients = $results.count # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference, but saving and using the current GUI, that will be saved in the broadcastdetails
$transactionId = $processId.Guid #$recipientListID

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
