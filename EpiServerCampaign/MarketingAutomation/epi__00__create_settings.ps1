
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


$pass = Read-Host -AsSecureString "Please enter the password for epi"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password)

# TODO [ ] put login credentials in Channel Editor as well as mandant as "IntegrationParameter"

$login = @{
    mandant = <mandantid> 
    user = "<apiuser>" 
    pass = $passEncrypted 
}

$settings = @{
    base="https://api.campaign.episerver.net/soap11/" #Rpc
    sessionFile = "session.json"
    ttl = 15
    encryptToken = $true
    login = $login
    masterListId = "<masterlistid>" # TODO [ ] is this used?
    rowsPerUpload = 800 # TODO [ ] is this used?
    changeTLS = $true
    recipientListFile = "recipientlists.json"
    nameConcatChar = " / "
    logfile="$( $scriptPath )\epi_ma.log"
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
