################################################
#
# TODO
#
################################################

<#

[ ] possibly a user token could make sense

To access these APIs , customers need to authenticate and authorize their access within the API call.
This requires passing the access token, and potentially the user token, in the API call headers.
User token requirement is dependent on how the company environment has been setup by the customer. 


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

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------
<#
$consumerSecret = Read-Host -AsSecureString "Please enter the consumerSecret for syniverse"
$consumerSecretEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$consumerSecret).GetNetworkCredential().Password)
#>
$accessToken = Read-Host -AsSecureString "Please enter the accessToken for syniverse"
$accessTokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessToken).GetNetworkCredential().Password)

$authentication = @{
    #consumerKey = "<consumerkey>"
    #consumerSecret = $consumerSecretEncrypted 
    accessToken = $accessTokenEncrypted
}


#-----------------------------------------------
# SEND SMS
#-----------------------------------------------

$sendMethod = "sender_id" # sender_id|channel
$senderId = ""

if ($sendMethod -eq "sender_id") {
    $senderId = Read-Host -AsSecureString "Please enter the senderId for syniverse"
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
$mssqlConnectionString = "Data Source=localhost;Initial Catalog=RS_Handel;User Id=faststats_service;Password=abc123;"


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
    
    # Detail settings
    countryMap = $countryMap
    channels = $channelIds
    responseDB = $mssqlConnectionString
    sendMethod = $sendMethod
    senderId = $senderId

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

