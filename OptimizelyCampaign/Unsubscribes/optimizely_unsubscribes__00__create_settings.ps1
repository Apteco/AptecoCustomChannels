
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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "CREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
#. ".\bin\load_networksettings.ps1"

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
$logfileDefault = "$( $scriptPath )\opti_unsubs.log"

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
# LOGIN DATA
#-----------------------------------------------

$mandant = Read-Host "Please enter mandant id"
$username = Read-Host "Please enter user name"

$pass = Read-Host -AsSecureString "Please enter the password for Optimizely Campaign"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password)

$loginSettings = @{
    mandant = $mandant
    user = $username 
    pass = $passEncrypted 
}

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
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email"                # Email|Sms
    "FromAddress"="info@apteco.de"  # 
    "FromName"="Apteco"             # 
    "ReplyTo"="info@apteco.de"      # 
    "Subject"="Test-Subject"        # 
}

#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    
}


#-----------------------------------------------
# BROADCAST SETTINGS
#-----------------------------------------------

$broadcastSettings = @{
    waitSecondsForMailingCreation = 20                  # number of seconds to wait for every loop part for the mailing id to be generated
    maxSecondsForMailingToFinish = 1200                 # maximum number of seconds to wait for the mailing id to be generated 
}




#-----------------------------------------------
# SETTINGS OBJECT
#-----------------------------------------------

# TODO [ ] check if some settings could be brought together

$settings = @{
    
    # General
    "base"="https://api.campaign.episerver.net/soap11/"   # Default url
    "changeTLS" = $true                                   # should tls be changed on the system?
    "nameConcatChar" =   " | "    # character to concat mailing/campaign id with mailing/campaign name
    #"campaignType" = $campaignType.Name                   # choice of smart campaigns or classic mailings
    "logfile" = $logfile
    "providername" = "opti_unsubs"                              # identifier for this custom integration, this is used for the response allocation
    
    # Session 
    "sessionFile" = "session.json"                        # name of the session file
    "ttl" = 15                                            # Time to live in minutes for the current session, normally 20 minutes for EpiServer Campaign
    "encryptToken" = $true                                # $true|$false if the session token should be encrypted
    
    # Upload
    # TODO [ ] put these settings into the separate upload object
    #masterListId = 0                                    # the master list id for ClosedLoop upload
    "rowsPerUpload" = 500                                 # no of rows to upload in a batch
    "exportDir" = "$( $scriptPath )\export"
    #excludedAttributes = @()                            # attributes to exclude for upload -> you make the choice later in the code
    #uploadsFolder = "$( $scriptPath )\uploads\"         # folder for the upload conversion
    #syncType = $syncType.Name                           # choice if the process should be synchronised or async
    #urnFieldName = ""                                   # Urn field name

    # Detail settings
    "login" = $loginSettings                              # login object from code above
    "upload" = $uploadSettings                            # 
    "broadcast" = $broadcastSettings                      # settings for the broadcast
    "previewSettings" = $previewSettings                  # settings for the email html preview
    #response = $responseSettings                        # settings for the response download

}


<#
$settings = @{

    # General settings
    "base" = "https://emm.agnitas.de/restful"
    "encoding" = "utf8"
    "nameConcatChar" =   " | "
    "providername" = "agnitasEMM"                        # identifier for this custom integration, this is used for the response allocation
    "logfile" = $logfile
    "winscplogfile" = "$( $scriptPath )\winscp.log"
    "timestampFormat" = "yyyy-MM-dd--HH-mm-ss"
    "powershellExePath" = "powershell.exe"    # Define other powershell path, e.g if you want to use pwsh for powershell7

    # Network settings
    "changeTLS" = $true
    "proxy" = $proxy # Proxy settings, if needed - will be automatically used
    
    # SOAP settings
    # "soap" = @{
    #     "base" = "https://ws.agnitas.de/2.0/"
    #     "Username" = $soapUsername
    #     "Password" = $soapPasswordEncrypted
    #     "contentType" = "application/json;charset=utf-8"
    #     "authentication" = $soapAuth
    # }
    #"baseSOAP" = "https://ws.agnitas.de/2.0/"   # TODO [x] check which url is used

    # Detail settings
    "login" = $login
    "sftpSession" = $sftpSettings
    "messages" = $messages
    "upload" = $upload
    "broadcast" = $broadcast
    "response" = $response

}
#>


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

# Creating the lib folder for the sqlite stuff
<#
$libFolder = ".\$( $libSubfolder )"
if ( !(Test-Path -Path "$( $libFolder )") ) {
    Write-Log -message "lib folder '$( $libFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $libFolder )" -ItemType Directory
}
#>

# Export folder to put exported files from Agnitas
$exportDir = $settings.exportDir
if ( !(Test-Path -Path "$( $exportDir )") ) {
    Write-Log -message "export folder '$( $exportDir )' does not exist. Creating the folder now!"
    New-Item -Path "$( $exportDir )" -ItemType Directory
}
<#
# Bulk folder for FERGE - needs to be reachable from SQLServer
$bulkDir = $settings.response.bulkDirectory
if ( !(Test-Path -Path "$( $bulkDir )") ) {
    Write-Log -message "bulk folder '$( $bulkDir )' does not exist. Creating the folder now! Make sure the path is reachable from SQLServer"
    New-Item -Path "$( $bulkDir )" -ItemType Directory
}
#>

################################################
#
# RELOAD EVERYTHING
#
################################################

#-----------------------------------------------
# RELOAD SETTINGS
#-----------------------------------------------

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the preparation file to prepare the connections
. ".\bin\preparation.ps1"




################################################
#
# LAST SETTINGS USING THE NEW LOGIN DATA
#
################################################

#-----------------------------------------------
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

Get-EpiSession



################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $settingsFile -Encoding UTF8


################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');