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
        "TransactionType" = "Replace"
        "Password" = "b"
        "scriptPath" = "D:\Scripts\Syniverse\WalletNotification"
        "MessageName" = "Wallet Notification"
        "EmailFieldName" = "Email"
        "SmsFieldName" = "WalletUrl"
        "Path" = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_Wallet Notification_b8919dd5-a92b-4a7e-b70b-7ddac8e8ebee.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "Wallet Notification"
        "CommunicationKeyFieldName" = "Communication Key"
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
$walletIds = @("abcde5")
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>"
$token = "<token>"
$mssqlConnectionString = "Data Source=localhost;Initial Catalog=RS_Handel;User Id=faststats_service;Password=abc123;"

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
$logfile = $settings.logfile

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
}


#-----------------------------------------------
# READ TEMPLATE
#-----------------------------------------------

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

# Regex patterns
$regexForValuesBetweenCurlyBrackets = "(?<={{)(.*?)(?=}})"
$regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"

# extract the important template information
# https://stackoverflow.com/questions/34212731/powershell-get-all-strings-between-curly-braces-in-a-file
$creativeTemplateText = $mssqlTable[0].Creative
$creativeTemplateToken = [Regex]::Matches($creativeTemplateText, $regexForValuesBetweenCurlyBrackets) | Select -ExpandProperty Value
$creativeTemplateLinks = [Regex]::Matches($creativeTemplateText, $regexForLinks) | Select -ExpandProperty Value


#-----------------------------------------------
# DEFINE NUMBERS
#-----------------------------------------------

Write-Log -message "Start to create a new file"

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values

$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8


#-----------------------------------------------
# PREPARE DATA TO UPLOAD
#-----------------------------------------------

# TODO [ ] put this workflow in parallel groups


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
        }

        $txt = $txt -replace [regex]::Escape($linkTemplate), $linkReplaced
    }    

    # replace all remaining tokens in text with personalised data
    $creativeTemplateToken | ForEach {
        $token = $_
        $txt = $txt -replace [regex]::Escape("{{$( $token )}}"), $row.$token
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


#-----------------------------------------------
# UPLOAD MESSAGES
#-----------------------------------------------

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

    Write-Log -message "Push to: '$( $walletItemDetailUrl )' and content '$( $notificationBody )'"

    $notificationResponse = Invoke-RestMethod -ContentType $contentType -Method Put -Uri $walletItemDetailUrl -Headers $headers -Body $notificationBody -Verbose

    Write-Log -message "Push result: $( $notificationResponse | ConvertTo-Json -Compress )"


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
