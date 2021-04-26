################################################
#
# TODO
#
################################################

<#

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


################################################
#
# FUNCTIONS
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$accessToken = Read-Host -AsSecureString "Please enter the accessToken for syniverse"
$accessTokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessToken).GetNetworkCredential().Password)

$authentication = @{
    accessToken = $accessTokenEncrypted
}


#-----------------------------------------------
# SEND SMS
#-----------------------------------------------

$sendMethod = "sender_id" # sender_id|channel
$senderId = ""

if ($sendMethod -eq "sender_id") {
    $senderId = Read-Host "Please enter the senderId for syniverse"
}


$countryMap = @{
    "+44"="uk"
    #"+33"="fr"
    "+49"="de"
    #"+34"="es"
    #"+45"="dk"
    #"+46"="se"
}

# public shared channel ids
# require no provisioning and no monthly or set up fees to use.
# limitations are shared with other SDC users, only support 1-way mobile terminated messages
# sender number is not fixed.
# we have public shared codes available for 58 countries listed here
$channelIds = @{
    "uk"="JXxaP5zAitsUnd66Ynavc" #"DJm-vHcnSBKbeK4b2FAOLQ"
    #"fr"="RUHDTglIodfuVx2vBg7qg3"
    "de"="JXxaP5zAitsUnd66Ynavc" #"qSOdzTqaSfO0bmwLEQGNdw"
    #"es"="zm8lO9Y9QKGKTeS-BoHCKA"
    #"dk"="o4u6_YvUSLas0SjuFYCtDw"
    #"se"="qAQwTeyCQsi5UturUnJApQ"
}


#-----------------------------------------------
# APTECO SETTINGS
#-----------------------------------------------

# connection string of response database
$mssqlConnectionString = "Data Source=localhost;Initial Catalog=RS_LumaYoga;User Id=faststats_service;Password=abc123;"


#-----------------------------------------------
# EVERYTHING TOGETHER
#-----------------------------------------------

$settings = @{

    # General
    base="https://api.syniverse.com/"					# Default url
    changeTLS = $true                      	            # should tls be changed on the system?
    nameConcatChar = " / "                 	            # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\syn_sms.log"		        # path and name of log file
    providername = "synsms"                             # identifier for this custom integration, this is used for the response allocation

    # Proxy settings, if needed... this needs to be commented in in the code
    proxyUrl = "http://proxyurl:8080"

    # Authentication
    authentication = $authentication
    
    # Upload settings
    uploadsFolder = "$( $scriptPath )\uploads"
    rowsPerUpload = 100
    sendMethod = $sendMethod
    senderId = $senderId

    # Detail settings
    countryMap = $countryMap
    channels = $channelIds
    responseDB = $mssqlConnectionString

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

#-----------------------------------------------
# SAVE
#-----------------------------------------------

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8


################################################
#
# CHECK SOME FOLDERS
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