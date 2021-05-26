
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
# MyInvocation wird verwendet, um den aktuellen Path des Skriptes zurückzugeben
# Da er bei anderen Usern wahrscheinlich woanders gespeichert ist, ist das notwendig
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

# Aktuelle Location wird nun als default festgelegt
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
$username = Read-Host "Please enter the username for Inxmail"
$password = Read-Host -AsSecureString "Please enter the password for Inxmail"

# Combining username and password; making it ready for BasicAuth
$credentials = "$($username):$($password)"

# Encoding to Base64
$BytesCredentials = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$EncodedCredentials = [Convert]::ToBase64String($BytesCredentials)

# Creating Authorization header value
$basic = @{
    intro = "Basic "
    encodedCredentials = $EncodedCredentials
}

# Authorizatioin header value 
$auth = "$($basic.intro)$($basic.encodedCredentials)"

# Encrypting Authorization header
$auth = ConvertTo-SecureString $auth -AsPlainText -Force
$credentialsEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$auth).GetNetworkCredential().Password)

$login = @{
    "authenticationHeader" = $credentialsEncrypted
}


#-----------------------------------------------
# SETTINGS INXMAIL
#-----------------------------------------------
$settings = @{
    "base" = "https://api.inxmail.com/apteco-apitest/rest/v1/"
    "encoding" = "UTF8"
    "login" = $login
    "logfile" = "$( $scriptPath )\cr.log"
    "nameConcatChar" = " / "
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




