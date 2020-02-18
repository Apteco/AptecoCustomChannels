################################################
#
# INPUT
#
################################################

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# NOTES
#
################################################

<#

TODO [ ] implement more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
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
$moduleName = "RESPONSEDOWNLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS
#
################################################

# Load all functions in subfolder
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
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

Write-Log -message "Opening a new session in EpiServer valid for $( $settings.ttl )"

Get-EpiSession

#-----------------------------------------------
# CURRENT TIME
#-----------------------------------------------

Get-EpiTime

# get mailings via SOAP API
$maxDays = 14
$secondsForXDays = 60*60*24*1000*$maxDays
$maxRows = 1000
$currentTimestamp = Get-Unixtime -inMilliseconds

# create directory
New-Item -ItemType Directory -Path ".\$( $guid )"

# log after loop
#Write-Log -message "Updatet $( $result ) rows in Broadcasts for Mailings $( $mailingsToTransform -join ',' )"


#-----------------------------------------------
# GET RESPONSES
#-----------------------------------------------

# export data
#$recipients = Get-EpiResponses -responseType Recipients -maxDays $maxDays
#$recipients | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\recipients.csv" -Delimiter "`t"

$opens = Get-EpiResponses -responseType Opens -maxDays $maxDays
$opens | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\opens.csv" -Delimiter "`t"

#$clicks = Get-EpiResponses -responseType Clicks -maxDays $maxDays
#$clicks | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\clicks.csv" -Delimiter "`t"

#$unsubscribes = Get-EpiResponses -responseType Unsubscribes -maxDays $maxDays
#$unsubscribes | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\unsubscribes.csv" -Delimiter "`t"

#$responses = Get-EpiResponses -responseType Responses -maxDays $maxDays
#$responses | Export-Csv -Encoding UTF8 -NoTypeInformation -Path ".\$( $guid )\responses.csv" -Delimiter "`t"










