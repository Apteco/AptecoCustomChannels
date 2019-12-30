
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
# SETUP SETTINGS
#
################################################

#-----------------------------------------------
# SECURITY / LOGIN
#-----------------------------------------------

$secret = Read-Host -AsSecureString "Please enter the secret for TriggerDialog"
$secretEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$secret).GetNetworkCredential().Password)

$password = Read-Host -AsSecureString "Please enter the password for TriggerDialog"
$passwordEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$password).GetNetworkCredential().Password)

$login = @{
    user = "<accountname>"
    secret = $secretEncrypted
    password = $passwordEncrypted
}

$masId = <masId/> 
$masClientId = <clientid/> # ID of the advertising customer within the partner system



#-----------------------------------------------
# DEFAULT HEADERS
#-----------------------------------------------

$headers = [ordered]@{
    "alg"="HS512"
    "typ"="JWT"
}


#-----------------------------------------------
# DEFAULT PAYLOAD
#-----------------------------------------------

$payload = [ordered]@{
  "iss" = <issuer/> # issuer (name of the partner system)
  "iat" = 0 # issuedAt (creation date as NumericDate, i.e. seconds since 01.01.1970 at 00:00:00 UTC
  "exp" = 0 # expiration (expiration date as NumericDate)
  "masId" = $masId # ID of the Marketing Automation System within TRIGGERDIALOG
  "masClientId" = $masClientId # ID of the advertising customer within the partner system
  "username" = "<username/>" # username of the user within TRIGGERDIALOG
  "email" = "<email/>" # e-mail address of the user, is also used for the one2edit user
  "firstname" = "<firstname/>" # firstname of the user within TRIGGERDIALOG
  "lastname" = "<lastname/>" # lastname of the user within TRIGGERDIALOG
}


#-----------------------------------------------
# ALL SETTINGS TOGETHER
#-----------------------------------------------

$settings = @{
    "base"="https://triggerdialog-uat.dhl.com" # At the moment only UAT
    "login" = $login
    "headers" = $headers
    "defaultPayload" = $payload
    "changeTLS" = $true
    "logfile" = "$( $scriptPath )\triggerdialog.log"
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8

