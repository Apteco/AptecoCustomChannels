################################################
#
# NOTES
#
################################################

<#
Replace the following tokens
<companyId>

Execute this script and enter your syniverse wallet api token (request at your account manager, if needed)

#>


################################################
#
# TODO
#
################################################


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
# SETTINGS
#
################################################

#-----------------------------------------------
# API LOGIN DATA
#-----------------------------------------------

# Entering the username and password
$companyId = Read-Host "Please enter company ID"
$username = Read-Host "Please enter the username for syniverse wallet api"
$password = Read-Host -AsSecureString "Please enter the password for syniverse wallet api"

# Combining username and password; making it ready for BasicAuth
$credentials = "$( $username ):$( ( New-Object PSCredential "dummy",$password).GetNetworkCredential().Password )"

# Encoding to Base64
$BytesCredentials = [System.Text.Encoding]::ASCII.GetBytes($credentials)
$EncodedCredentials = [Convert]::ToBase64String($BytesCredentials)

# Encrypting Authorization header
$credentialsEncrypted = Get-PlaintextToSecure $EncodedCredentials

# Asking for connection string to response database
$connectionstring = Read-Host -AsSecureString "Please enter the connection string for sqlserver" # "Data Source=localhost;Initial Catalog=RS_Handel;User Id=faststats_service;Password=fa5t5tat5!;"
$connectionstringEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$connectionstring).GetNetworkCredential().Password)

$login = @{
    "accesstoken" = $credentialsEncrypted
    "sqlserver" = $connectionstringEncrypted
}


#-----------------------------------------------
# EVERYTHING TOGETHER
#-----------------------------------------------

$settings = @{

    # General settings
    "base"="https://public-api.cm.syniverse.eu"
    "companyId" = $companyId
    "nameConcatChar" = " | "
    "logfile" = "$( $scriptPath )\walletnotifications.log"
    "delimiter" = "`t" # "`t"|","|";" usw.
    "encoding" = "UTF8" # "UTF8"|"ASCII" usw. encoding for importing text file https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-6
    "contentType" = "application/json; charset=utf-8" #"application/json"
    "uploadsFolder" = "$( $scriptPath )\uploads"
    "changeTLS" = $true

    # Authentication
    "login" = $login

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
# CREATE FOLDERS IF NEEDED
#
################################################

if ( !(Test-Path -Path $settings.uploadsFolder) ) {
    New-Item -Path "$( $settings.uploadsFolder )" -ItemType Directory
}