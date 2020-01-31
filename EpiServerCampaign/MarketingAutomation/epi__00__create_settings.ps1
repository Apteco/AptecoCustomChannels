
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
# LOGIN DATA
#-----------------------------------------------

$pass = Read-Host -AsSecureString "Please enter the password for epi"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password)

$loginSettings = @{
    mandant = <mandantid> 
    user = "<apiuser>" 
    pass = $passEncrypted 
}


#-----------------------------------------------
# MAILINGS SETTINGS
#-----------------------------------------------

$mailingsSettings = @{
    recipientListFile = "$( $scriptPath )\recipientlists.json"
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    rowsPerUpload = 800 # TODO [ ] is this used?
    uploadsFolder = "$( $scriptPath )\uploads\"
    excludedAttributes = @()
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?
# TODO [ ] Documentation of all these parameters and the ones above

$settings = @{

    # General
    base="https://api.campaign.episerver.net/soap11/"   # Default url
    changeTLS = $true                                   # should tls be changed on the system?
    nameConcatChar = " / "                              # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\epi_ma.log"               # path and name of log file
    providername = "epima"                              # identifier for this custom integration, this is used for the response allocation

    # Session 
    sessionFile = "session.json"                        # name of the session file
    ttl = 15                                            # Time to live in minutes for the current session, normally 20 minutes for EpiServer Campaign
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    login = $loginSettings
    mailings = $mailingsSettings
    upload = $uploadSettings

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

#-----------------------------------------------
# ATTRIBUTES TO EXCLUDE
#-----------------------------------------------

<#

Normally some of these
"Opt-in Source","Opt-in Date","Created","Modified","BROADMAIL_ID","WELLE_ID"

#>

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$masterList;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | Out-GridView -PassThru
$settings.upload.excludedAttributes = $listAttributes


#-----------------------------------------------
# SAVE
#-----------------------------------------------

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8
