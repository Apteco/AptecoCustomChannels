
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

Get-ChildItem ".\$( $functionsSubfolder )" -Filter "*.ps1" -Recurse | ForEach {
    . $_.FullName
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$token = Read-Host -AsSecureString "Please enter the token for cleverreach"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password)

$login = @{
    "accesstoken" = $tokenEncrypted
}


#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email" #Email|Sms
    #"FromAddress"="info@apteco.de"
    #"FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    #"Subject"="Test-Subject"
}

#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    "rowsPerUpload" = 800
    "uploadsFolder" = "$( $scriptPath )\uploads\"
    #"excludedAttributes" = @()
}

#-----------------------------------------------
# BROADCAST SETTINGS
#-----------------------------------------------

$broadcastSettings = @{
    "defaultContentType" = "html/text" # html|text|html/text
    "defaultEditor" = "wizard" # wizard|freeform|advanced|plaintext
    "defaultOpenTracking" = $true # $true|$false
    "defaultClickTracking" = $true # $true|$false
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?

$settings = @{
    
    # general
    "base" = "https://rest.cleverreach.com/v3/"
    "nameConcatChar" = " / "
    "logfile" = "$( $scriptPath )\cr.log"
    "delimiter" = "`t" # "`t"|","|";" usw.
    "encoding" = "UTF8" # "UTF8"|"ASCII" usw. encoding for importing text file https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-6
    "contentType" = "application/json; charset=utf-8"

    # authentication
    "login" = $login
    
    # network
    "changeTLS" = $true
    
    # sub settings categories
    "preview" = $previewSettings
    "upload" = $uploadSettings
    "broadcast" = $broadcastSettings

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





