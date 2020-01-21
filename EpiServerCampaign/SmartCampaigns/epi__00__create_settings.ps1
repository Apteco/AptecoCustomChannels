
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
# LOGIN DATA
#-----------------------------------------------

$pass = Read-Host -AsSecureString "Please enter the password for epi"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password)

$login = @{
    mandant = <mandantid> 
    user = "<username>" 
    pass = $passEncrypted 
}

#-----------------------------------------------
# CAMPAIGN TYPES
#-----------------------------------------------

<#

campaign types, default should be the newer one:
Smart Campaigns

#>
$campaignTypes = @{
    "classic"="Classic Mailings"
    "smart"="Smart Campaigns"
}

$campaignType = $campaignTypes | Out-GridView -PassThru


#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email" #Email|Sms
    "FromAddress"="info@apteco.de"
    "FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    "Subject"="Test-Subject"
}

#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?

$settings = @{
    base="https://api.campaign.episerver.net/soap11/" #Rpc
    sessionFile = "session.json"
    ttl = 15
    encryptToken = $true
    login = $login
    masterListId = 0
    rowsPerUpload = 800
    changeTLS = $true
    recipientListFile = "recipientlists.json"
    nameConcatChar = " / "
    campaignType = $campaignType.Name
    logfile="$( $scriptPath )\epi_sc.log"
    waitSecondsForMailingCreation = 20
    excludedAttributes = @()
    previewSettings = $previewSettings
    uploadsFolder = "$( $scriptPath )\uploads\"
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



################################################
#
# LAST SETTINGS USING THE NEW LOGIN DATA
#
################################################

#-----------------------------------------------
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# MASTERLIST
#-----------------------------------------------

<#

normally something like:
ClosedLoopWebserviceTemplate: master

#>

$recipientLists = Get-EpiRecipientLists 
$masterList = $recipientLists | Out-GridView -PassThru | Select -First 1
$settings.masterListId = $masterList.id


#-----------------------------------------------
# ATTRIBUTES TO EXCLUDE
#-----------------------------------------------

<#

Normally some of these
"Opt-in Source","Opt-in Date","Created","Modified","BROADMAIL_ID","WELLE_ID"

#>

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$settings.masterListId;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | Out-GridView -PassThru
$settings.excludedAttributes = $listAttributes


#-----------------------------------------------
# SAVE
#-----------------------------------------------

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8



