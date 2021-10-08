
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
# MyInvocation is used because it returns the current path of the script
# It is necessary because the path on other computers can differ
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

# Current Location will be set as default
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

Get-ChildItem ".\$( $functionsSubfolder )" -Filter "*.ps1" -Recurse | ForEach-Object {
    . $_.FullName
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA INXMAIL
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

# Authorizatioin header value 
$auth = "Basic $( $EncodedCredentials )"

# Encrypting Authorization header
$credentialsEncrypted = Get-PlaintextToSecure $auth

$login = @{
    "authenticationHeader" = $credentialsEncrypted
}

# SFTP Password
$sftpHostname = Read-Host "Please enter the hostname for sftp"
$sftpUsername = Read-Host "Please entter the username for sftp"
$sftpPassword = Read-Host -AsSecureString "Please enter the password for sftp"
$sftpKeyfingerprint = Read-Host "Please enter the Ssh Host Key Fingerprint"
$sftpPasswordEncrypted = Get-PlaintextToSecure "$(( New-Object PSCredential "dummy",$sftpPassword).GetNetworkCredential().Password)"

# Soap Password
$soapUsername = Read-Host "Please enter the username for Agnitas SOAP API"
$soapPassword = Read-Host -AsSecureString "Please enter the password for Agnitas SOAP API"
$soapPasswordEncrypted = Get-PlaintextToSecure "$(( New-Object PSCredential "dummy",$soapPassword).GetNetworkCredential().Password)"

$soapAuth =@{
    username = $soapUsername
    password = $soapPasswordEncrypted
}

#-----------------------------------------------
# SETTINGS INXMAIL
#-----------------------------------------------
$settings = @{
    "base" = "https://emm.agnitas.de/restful"
    "encoding" = "utf8"
    "login" = $login
    "logfile" = "$( $scriptPath )\agnitas.log"

    "soap" = @{
        "base" = "https://ws.agnitas.de/2.0/"
        "Username" = $soapUsername
        "Password" = $soapPasswordEncrypted
        "contentType" = "application/json;charset=utf-8"
        "authentication" = $soapAuth
    }
    "nameConcatChar" = " / "
    "baseSOAP" = "https://ws.agnitas.de/2.0/"

    "providername" = "winscp"
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

# create json object
# weil json-Dateien sind sehr einfach portabel
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8




