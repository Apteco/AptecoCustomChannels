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
        TransactionType= "Replace"
        Password= "def"
        scriptPath= "D:\Scripts\CleverReach\Tagging"
        MessageName= ""
        EmailFieldName= "Email"
        SmsFieldName= ""
        Path= "D:\Apteco\Publish\CleverReach\system\Deliveries\PowerShell_Free Try Automation_25cb7d21-58d9-4136-a1a0-ca1886a0670b.txt"
        ReplyToEmail= ""
        Username= "abc"
        ReplyToSMS= ""
        UrnFieldName= "RC Id"
        ListName= "Free Try Automation"
        CommunicationKeyFieldName= "Communication Key"
    }
}

################################################
#
# NOTES
#
################################################

<#


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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "SYNWALNOTIFICATION"
$processId = [guid]::NewGuid()

# Load settings
$settings = @{
    nameConcatChar = " | "
    logfile = "wallets.log"
}

#$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$walletIds = @("abcdeg")
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<compandId>"
$token = "<token>"
$mssqlConnectionString = "Data Source=localhost;Initial Catalog=RS_Handel;Trusted_Connection=True;"



# Current timestamp
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
#if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
#}

# more settings
$logfile = "wallets.log" #$settings.logfile

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

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>



################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
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
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}



################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# PREPARE
#-----------------------------------------------

$contentType = "application/json" 

$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId 



#-----------------------------------------------
# READ TEMPLATE
#-----------------------------------------------

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tLoading template with name $( $params.MessageName )" >> $logfile


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
 FROM [RS_FUG].[dbo].[CreativeTemplate]
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

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile
#$cols = ,@($params.SmsFieldName)
#$exportId = Split-File -inputPath $params.Path -header $true -writeHeader $false -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $cols -writeCount -1 -outputDoubleQuotes $true
#$exportId = "75c3978f-4c94-4a28-ace6-b497494df2aa"

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values

$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8


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
$walletId = [guid]::NewGuid()

# Filenames
$tempFolder = "$( $scriptPath )\$( $walletId )"
New-Item -ItemType Directory -Path $tempFolder
$walletFile = "$( $tempFolder )\wallet.csv"

$parsedData | Export-Csv -Path $walletFile -Encoding UTF8 -Delimiter "`t" -NoTypeInformation







$contentType = "application/json" 



$notificationResponse = @()
$parsedData | ForEach {
    
    $text = $_.message
    $mobile = $_.mdn

    
    $notificationBody = @{
                   "passbook"=@{
                        "notification"=$text
                   }
               } | ConvertTo-Json -Compress
    
    <#
    $messageBody =  @{
               "message"=@{
                    "template"=$text
                    "header"="You have an update"
               }
           } | ConvertTo-Json -Compress
           #>
    #$walletItemDetail = $_
    $walletItemDetailUrl = "$( $baseUrl )$( $mobile )"

    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tPush to: '$( $walletItemDetailUrl )' and content '$( $notificationBody )'" >> $logfile

    $notificationResponse = Invoke-RestMethod -ContentType $contentType -Method Put -Uri $walletItemDetailUrl -Headers $headers -Body $notificationBody -Verbose

    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tPush result: $( $notificationResponse | ConvertTo-Json -Compress )" >> $logfile


}

<#
$messageBody =  @{
               "message"=@{
                    "template"="Update for all!"
                    "header"="Header, only Android"
               }
           } | ConvertTo-Json -Compress


$messageUrl = "https://public-api.cm.syniverse.eu/companies/SIBYdQOa/campaigns/wallet/icsjv5/messages"
$notificationResponse = Invoke-RestMethod -ContentType $contentType -Method Post -Uri $messageUrl -Headers $headers -Body $messageBody -Verbose

#$res
#$res

#$messages = Invoke-RestMethod -Uri $url -Method Get -Verbose -Headers $headers
#$messages.list | Out-GridView
#>

################################################
#
# SEND NOTIFICATION TO SINGLE WALLET
#
################################################

