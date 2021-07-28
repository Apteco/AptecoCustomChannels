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
        "scriptPath" = "D:\Scripts\Syniverse\WalletNotification_v2"
        "MessageName" = "2d27878b-1419-49f8-94b7-bef8fb19f5c1 | SMS Wallet Offer"
        "EmailFieldName" = "Email"
        "SmsFieldName" = "WalletUrl"
        "Path" = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_2d27878b-1419-49f8-94b7-bef8fb19f5c1  SMS Wallet Offer_c3474932-d91f-47c8-8d53-ff6f043eafb1.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "2d27878b-1419-49f8-94b7-bef8fb19f5c1 | SMS Wallet Offer"
        "CommunicationKeyFieldName" = "Communication Key"
    }
}


################################################
#
# NOTES
#
################################################

<#

# TODO [ ] use split file process for larger files
# TODO [ ] load parameters from creative template for default values


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
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Loading settings from file
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

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


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# DECRYPT CONNECTION STRING
#-----------------------------------------------

$mssqlConnectionString = Get-SecureToPlaintext -String $settings.login.sqlserver


#-----------------------------------------------
# READ TEMPLATE
#-----------------------------------------------

$chosenTemplate = [Mailing]::new($params.MessageName)

Write-Log -message "Loading template with name $( $params.MessageName )"

Write-Log "Loading notification templates from SQLSERVER"

$mssqlConnection = [System.Data.SqlClient.SqlConnection]::new()
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

"Trying to load the data from MSSQL"

# define query -> currently the age of the date in the query has to be less than 12 hours
$mssqlQuery = Get-Content -Path ".\sql\getmessages.sql" -Encoding UTF8

# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = new-object System.Data.DataTable
$mssqlTable.Load($mssqlResult)
    

$mssqlConnection.Close()

# Find the right template
$template = $mssqlTable | where { $_.CreativeTemplateId -eq $chosenTemplate.mailingId }

# Regex patterns
$regexForValuesBetweenCurlyBrackets = "(?<={{)(.*?)(?=}})"
$regexForLinks = "(http[s]?)(:\/\/)({{(.*?)}}|[^\s,])+"

# extract the important template information
# https://stackoverflow.com/questions/34212731/powershell-get-all-strings-between-curly-braces-in-a-file
$creativeTemplateText = $template.Creative
$creativeTemplateToken = [Regex]::Matches($creativeTemplateText, $regexForValuesBetweenCurlyBrackets) | Select -ExpandProperty Value
$creativeTemplateLinks = [Regex]::Matches($creativeTemplateText, $regexForLinks) | Select -ExpandProperty Value



#-----------------------------------------------
# IMPORT FILE
#-----------------------------------------------

Write-Log -message "Loading the csv file"

$data = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8


#-----------------------------------------------
# PREPARE DATA TO UPLOAD
#-----------------------------------------------

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

# Filenames
$tempFolder = "$( $uploadsFolder )\$( $processId )"
New-Item -ItemType Directory -Path $tempFolder

# Export data to upload
$parsedData | Export-Csv -Path "$( $tempFolder )\upload.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation


#-----------------------------------------------
# AUTHENTICATION + HEADERS
#-----------------------------------------------

$baseUrl = $settings.base
$contentType = $settings.contentType
$headers = @{
    "Authorization"="Basic $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
    "X-API-Version"="2"
    "int-companyid"=$settings.companyId
}


#-----------------------------------------------
# UPLOAD MESSAGES
#-----------------------------------------------

$notificationResponses = [System.Collections.ArrayList]@()
$notificationErrors = [System.Collections.ArrayList]@()
$parsedData | ForEach {
    
    $text = $_.message
    $mobile = $_.mdn

    $notificationBody = @{
                   "passbook"=@{
                        "notification"=$text
                   }
               } | ConvertTo-Json -Compress
    
    $walletItemDetailUrl = "$( $baseUrl )$( $mobile )"

    #Write-Log -message "Push to: '$( $walletItemDetailUrl )' and content '$( $notificationBody )'"
    $notificationParams = @{
        Uri = $walletItemDetailUrl
        Method = "Put"
        Verbose = $true
        Headers = $headers
        Body = $notificationBody
        ContentType = $contentType
    }

    try {
        $notificationResponse = Invoke-RestMethod @notificationParams
        [void]$notificationResponses.Add($notificationResponse)
    } catch {
        $e = ParseErrorForResponseBody -err $_
        [void]$notificationErrors.Add([PsCustomObject]@{
            "item" = $mobile
            "text" = $text
            "error" = $e.errors.message
        })
        #Write-Log $e
    }
    
    #Write-Log -message "Push result: $( $notificationResponse | ConvertTo-Json -Compress )"

}


$notificationResponses | ConvertTo-Json -Depth 20 | Set-Content -Path "$( $tempFolder )\response.json" -Encoding UTF8
$notificationErrors | ConvertTo-Json -Depth 20 | Set-Content -Path "$( $tempFolder )\errors.json" -Encoding UTF8


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [ ] check return results

# count the number of successful upload rows
$recipients = $notificationResponses.Count # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference for the upload in Epi
$transactionId = $processId #$recipientListID

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername
    "ProcessId" = $processId

    # More information about the different status of the import
    #"RecipientsIgnored" = 
    #"RecipientsQueued" = $queued
    #"RecipientsSent" = 
    "RecipientsFailed" = $notificationErrors.Count

}

# return the results
$return
