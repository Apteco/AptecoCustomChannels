
################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true
$configMode = $true


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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "SYNSMSCREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"



################################################
#
# START
#
################################################


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\emm.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# LOAD LOGGING MODULE NOW
#-----------------------------------------------

$settings = @{
    "logfile" = $logfile
}

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


#-----------------------------------------------
# LOG THE NEW SETTINGS CREATION
#-----------------------------------------------

Write-Log -message "Creating a new settings file" -severity ( [Logseverity]::WARNING )



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

$sendMethod = "channel" # sender_id|channel
$senderId = ""

if ($sendMethod -eq "sender_id") {
    $senderId = Read-Host "Please enter the senderId for syniverse"
}


$countryMap = @{
    #"+44"="uk"
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
    #"uk"="JXxaP5zAitsUnd66Ynavc" #"DJm-vHcnSBKbeK4b2FAOLQ"
    #"fr"="RUHDTglIodfuVx2vBg7qg3"
    "de"="qSOdzTqaSfO0bmwLEQGNdw" #"JXxaP5zAitsUnd66Ynavc" #"qSOdzTqaSfO0bmwLEQGNdw"
    #"es"="zm8lO9Y9QKGKTeS-BoHCKA"
    #"dk"="o4u6_YvUSLas0SjuFYCtDw"
    #"se"="qAQwTeyCQsi5UturUnJApQ"
}


#-----------------------------------------------
# APTECO SETTINGS
#-----------------------------------------------

# connection string of response database
#$mssqlConnectionString = "Data Source=777D0B7;Initial Catalog=RS_LumaYoga;User Id=faststats_service;Password=fa5t5tat5!;"

# TODO [ ] load as securestring?
$mssqlConnectionString = Read-Host "Please enter the connectionstring to the MSSQL response database like 'Data Source=777D0B7;Initial Catalog=RS_LumaYoga;User Id=faststats_service;Password=fa5t5tat5!;'"


#-----------------------------------------------
# ASK IF THERE IS A PROXY USED
#-----------------------------------------------

# ask for credentials if e.g. a proxy is used (normally without the prefixed domain)
#$cred = Get-Credential
#$proxyUrl = "http://proxy:8080"

# TODO [ ] sometimes the proxy wants an additional content type or header -> do if this comes up

# More useful links
# https://stackoverflow.com/questions/13552227/using-proxy-automatic-configuration-from-ie-settings-in-net
# https://stackoverflow.com/questions/20471486/how-can-i-make-invoke-restmethod-use-the-default-web-proxy/20472024  

$proxyDecision = $Host.UI.PromptForChoice("Proxy usage", "Do you use a proxy for network authentication?", @('&Yes'; '&No'), 1)

If ( $proxyDecision -eq "0" ) {

    # Means yes and proceed

    # Try a figure out the uri
    $proxyUriSuggest = [System.Net.WebRequest]::GetSystemWebProxy().GetProxy("http://www.apteco.de")

    # Ask for the uri
    $proxyUriDecision = $Host.UI.PromptForChoice("Proxy uri", "I have figured out the url '$( $proxyUriSuggest.ToString() )'. Is that correct?", @('&Yes'; '&No'), 1)
    If ( $proxyUriDecision -eq "0" ) {

        # yes, correct
        $proxyUri = $proxyUriSuggest.toString()

    } else {

        # no, not correct
        $proxyUri = Read-Host "Please enter the proxy url like 'http://proxyurl:8080'"

    }

    # Next step, figure out credentials
    $proxyCredentialsDecision = $Host.UI.PromptForChoice("Proxy credentials", "Remember the FastStats Service is normally running with another windows user. So do you want to use the current account user login?", @('&Yes'; '&No'), 1)
    If ( $proxyCredentialsDecision -eq "0" ) {
        
        # yes, use default credentials
        $proxyUseDefaultCredentials = $true
        $proxyCredentials = @{}

    } else {

        # no, use other credentials
        $proxyUseDefaultCredentials = $false

        # Soap Password
        $proxyUsername = Read-Host "Please enter the username for proxy authentication"
        $proxyPassword = Read-Host -AsSecureString "Please enter the password for proxy authentication"
        $proxyPasswordEncrypted = Get-PlaintextToSecure "$(( New-Object PSCredential "dummy",$proxyPassword).GetNetworkCredential().Password)"

        $proxyCredentials = @{
            "username" = $proxyUsername
            "password" = $proxyPasswordEncrypted
        }

    }

    $proxy = @{
        "proxyUrl" = $proxyUri # ""|"http://proxyurl:8080"
        #"useDefaultCredentials" = $false   # Do this by default if a proxy is used
        "proxyUseDefaultCredentials" = $proxyUseDefaultCredentials
        "credentials" = $proxyCredentials
    }

} else {
    
    # Leave the process here
    
    $proxy = @{}

}


#-----------------------------------------------
# EVERYTHING TOGETHER
#-----------------------------------------------

$settings = @{

    # General
    "base"="https://api.syniverse.com/"					# Default url
    #"changeTLS" = $true                      	        # should tls be changed on the system?
    "nameConcatChar" = " | "               	            # character to concat mailing/campaign id with mailing/campaign name
    "logfile"="$( $scriptPath )\syn_sms.log"		    # path and name of log file
    "providername" = "synsms"                           # identifier for this custom integration, this is used for the response allocation

    # Proxy settings, if needed - will be automatically used
    #"useDefaultCredentials" = $false
    #"ProxyUseDefaultCredentials" = $false
    #"proxyUrl" = "" # ""|"http://proxyurl:8080"

    # Network settings
    "changeTLS" = $true
    "proxy" = $proxy # Proxy settings, if needed - will be automatically used


    # Authentication
    "authentication" = $authentication
    
    # Upload settings
    "uploadsFolder" = "$( $scriptPath )\uploads"
    "rowsPerUpload" = 100
    "sendMethod" = $sendMethod
    "senderId" = $senderId
    "firstResultWaitTime" = 15                          # First wait time after sending out SMS for the first results
                                                        # and also wait time after each loop
    "maxResultWaitTime" = 100                           # Maximum time to request SMS sending status

    # Detail settings
    "countryMap" = $countryMap
    "channels" = $channelIds
    "responseDB" = $mssqlConnectionString

}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# rename settings file if it already exists
If ( Test-Path -Path $settingsFile ) {
    $backupPath = "$( $settingsFile ).$( $timestamp.ToString("yyyyMMddHHmmss") )"
    Write-Log -message "Moving previous settings file to $( $backupPath )" -severity ( [Logseverity]::WARNING )
    Move-Item -Path $settingsFile -Destination $backupPath
} else {
    Write-Log -message "There was no settings file existing yet"
}

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $settingsFile -Encoding UTF8

################################################
#
# CREATE FOLDERS IF NEEDED
#
################################################

$uploadsFolder = $settings.uploadsFolder
if ( !(Test-Path -Path "$( $uploadsFolder )") ) {
    Write-Log -message "Upload '$( $uploadsFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');