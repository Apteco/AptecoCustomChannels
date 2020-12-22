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
	    Password= "def"
	    scriptPath= "D:\Scripts\TriggerDialog\v2"
	    abc= "def"
	    Username= "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#

Good hints on PowerShell Classes and inheritance

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
$processId = [guid]::NewGuid()
$modulename = "TRUPLOAD"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}



################################################
#
# FUNCTIONS AND ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

Add-Type -AssemblyName System.Security


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
# PROCESS
#
################################################


#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

# TODO [ ] implement loading bigger files later

# Get file item
$file = Get-Item -Path $params.Path
$filename = $file.Name -replace $file.Extension

# Load data from file
$dataCsv = @()
$dataCsv += import-csv -Path $file.FullName -Delimiter "`t" -Encoding UTF8


#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$contentType = $settings.contentType
$headers = @{
    "accept" = $settings.contentType
}


#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

Get-TriggerDialogSession
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret $settings.authentication.authenticationSecret
$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )

$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# PARSE MESSAGE NAME
#-----------------------------------------------

$message = [TriggerDialogMailing]::new($params.MessageName)


#-----------------------------------------------
# LOAD EXISTING FIELDS
#-----------------------------------------------

$variableDefinitions = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings/$( $message.mailingId )/variabledefinitions?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose

#-----------------------------------------------
# TRANSFORM UPLOAD DATA
#-----------------------------------------------



#-----------------------------------------------
# UPLOAD DATA
#-----------------------------------------------

$body = @{
    "campaignId" = $campaign.id
    "customerId" = $customerId
    "recipients" = @(
        
        # This is the data of 1 recipient
        @{
            "recipientData" = @(                    
                @{
                    "label" = "zip"
                    "value" = "48309"
                }
                @{
                    "label" = "city"
                    "value" = "Dover"
                }
            )
            "recipientIdExt" = "null"
        },

        # This is the data of 1 recipient
        @{
            "recipientData" = @(                    
                @{
                    "label" = "zip"
                    "value" = "52080"
                }
                @{
                    "label" = "city"
                    "value" = "Aachen"
                }
            )
            "recipientIdExt" = "null"
        }
        


    )
}

$bodyJson = $body | ConvertTo-Json -Depth 8
$newCustomers = Invoke-RestMethod -Method Post -Uri "$( $settings.base )/recipients" -Verbose -Headers $headers -ContentType $contentType -Body $bodyJson
$newCustomers.elements | Out-GridView

<#

If uploaded failed, you get an http422

If succeeded, you a correlationId back

id on a upload at 2020-10-14: d7513861-894b-4b8b-b88e-34e992f0c1ba

#>

# Send back id
$newCustomers.correlationId


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

If ( $queued -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"=$queued 
    "TransactionId"=$processId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$moduleName
    "ProcessId" = $processId

    # Some more information for the broadcasts script
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName

    # More information about the different status of the import
    #"RecipientsIgnored" = $ignored
    #"RecipientsQueued" = $queued

}

# return the results
$return