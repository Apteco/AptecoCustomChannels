
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

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

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
$modulename = "EMMCREATESETTINGS"

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
# LOGIN DATA AGNITAS
#-----------------------------------------------

# Entering the username and password
# $base = Read-Host "Please enter account sessionId"
$username = Read-Host "Please enter the username for Agnitas REST API"
$password = Read-Host -AsSecureString "Please enter the password for Agnitas REST API"

# Combining username and password; making it ready for BasicAuth
$credentials = "$($username):$(( New-Object PSCredential "dummy",$password).GetNetworkCredential().Password)"

# Encoding to Base64
$BytesCredentials = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$EncodedCredentials = [Convert]::ToBase64String($BytesCredentials)

# Authorization header value 
$auth = "Basic $( $EncodedCredentials )"

# Encrypting Authorization header
$credentialsEncrypted = Get-PlaintextToSecure $auth

$login = @{
    "authenticationHeader" = $credentialsEncrypted
}


# Soap Password
$soapUsername = Read-Host "Please enter the username for Agnitas SOAP API"
$soapPassword = Read-Host -AsSecureString "Please enter the password for Agnitas SOAP API"
$soapPasswordEncrypted = Get-PlaintextToSecure "$(( New-Object PSCredential "dummy",$soapPassword).GetNetworkCredential().Password)"

$soapAuth =@{
    username = $soapUsername
    password = $soapPasswordEncrypted
}

#-----------------------------------------------
# LOGIN DATA SFTP
#-----------------------------------------------

# SFTP Password
$sftpHostname = Read-Host "Please enter the hostname for sftp"
$sftpUsername = Read-Host "Please enter the username for sftp"
$sftpPassword = Read-Host -AsSecureString "Please enter the password for sftp"
#$sftpKeyfingerprint = Read-Host "Please enter the Ssh Host Key Fingerprint"
$sftpPasswordEncrypted = Get-PlaintextToSecure "$(( New-Object PSCredential "dummy",$sftpPassword).GetNetworkCredential().Password)"

# TODO [ ] Calculate the Fingerprint by the script


#-----------------------------------------------
# SETTINGS OBJECT
#-----------------------------------------------

# TODO [ ] check if some settings could be brought together

$settings = @{

    # General settings
    "base" = "https://emm.agnitas.de/restful"
    "encoding" = "utf8"
    "nameConcatChar" =   " | "
    "providername" = "agnitasEMM"                        # identifier for this custom integration, this is used for the response allocation
    "logfile" = $logfile

    # Detail settings
    "login" = $login

    # SOAP settings
    "soap" = @{
        "base" = "https://ws.agnitas.de/2.0/"
        "Username" = $soapUsername
        "Password" = $soapPasswordEncrypted
        "contentType" = "application/json;charset=utf-8"
        "authentication" = $soapAuth
    }
    "baseSOAP" = "https://ws.agnitas.de/2.0/"

    # SFTP settings
    "sftpSession" = @{
        "HostName" = $sftpHostname
        "Username" = $sftpUsername
        "Password" = $sftpPasswordEncrypted
        "SshHostKeyFingerprint" = $sftpKeyfingerprint
    }

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

# Creating the lib folder for the sqlite stuff
$libFolder = ".\$( $libSubfolder )"
if ( !(Test-Path -Path "$( $libFolder )") ) {
    Write-Log -message "lib folder '$( $libFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $libFolder )" -ItemType Directory
}


################################################
#
# DOWNLOAD AND INSTALL THE WINSCP PACKAGE
#
################################################

$sqliteDll = "WinSCPnet.dll"

if ( $libExecutables.Name -notcontains $sqliteDll ) {

    Write-Log -message "A browser page is opening now. Please download the .NET assembly / COM library zip file"
    Write-Log -message "Please unzip the file and put it into the lib folder"
        
    Start-Process "https://winscp.net/download/WinSCP-5.19.2-Automation.zip"
    
    # Wait for key
    Write-Host -NoNewLine 'Press any key if you have put the files there';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}


################################################
#
# DO SOME MORE SETTINGS DIRECTLY
#
################################################

#-----------------------------------------------
# RELOAD SETTINGS
#-----------------------------------------------

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

#-----------------------------------------------
# CALCULATE FINGERPRINT FOR SFTP
#-----------------------------------------------

# TODO [ ] Fill this with code


#-----------------------------------------------
# CHECK LOGIN FOR AGNITAS REST
#-----------------------------------------------

# TODO [ ] Fill this with code

#-----------------------------------------------
# CHECK LOGIN FOR AGNITAS SOAP
#-----------------------------------------------

# TODO [ ] Fill this with code



################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');