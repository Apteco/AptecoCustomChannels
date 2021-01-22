
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

$keyFile = "$( $scriptPath )\aes.key"
$pass = Read-Host -AsSecureString "Please enter the password for epi"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password) -keyfile $keyFile

$loginSettings = @{
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

$campaignType = $campaignTypes | Out-GridView -PassThru | Select -First 1


#-----------------------------------------------
# PROCESS SYNCHRONISATION
#-----------------------------------------------

<#

campaign types, default should be the newer one:
Smart Campaigns

#>
$syncTypes = @{
    "sync"="PeopleStage waits for the list to be fully imported"
    "async"="PeopleStage just uploads the data and won't wait for completion. The mailing id will be gathered when FERGE starts."
}

$syncType = $syncTypes | Out-GridView -PassThru | Select -First 1

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
# RESPONSE SETTINGS
#-----------------------------------------------

$responseSettings = @{
    responseConfig = "$( $scriptPath )\epi__ferge.xml"  # response config file, leave it like this if ferge is not triggered from this script
    triggerFerge = $false                               # $true|$false should ferge be triggered in the epi__80__trigger_ferge part?
    decryptConfig = $false                               # $true|$false
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
    campaignType = $campaignType.Name                   # choice of smart campaigns or classic mailings
    logfile="$( $scriptPath )\epi_sc.log"               # path and name of log file
    providername = "episc"                              # identifier for this custom integration, this is used for the response allocation
    
    # Session 
    aesFile = $keyFile 
    sessionFile = "$( $scriptPath )\session.json"                        # name of the session file
    ttl = 15                                            # Time to live in minutes for the current session, normally 20 minutes for EpiServer Campaign
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Upload
    # TODO [ ] put these settings into the separate upload object
    masterListId = 0                                    # the master list id for ClosedLoop upload
    rowsPerUpload = 500                                 # no of rows to upload in a batch
    excludedAttributes = @()                            # attributes to exclude for upload -> you make the choice later in the code
    uploadsFolder = "$( $scriptPath )\uploads\"         # folder for the upload conversion
    syncType = $syncType.Name                           # choice if the process should be synchronised or async
    urnFieldName = ""                                   # Urn field name

    # Detail settings
    login = $loginSettings                              # login object from code above
    upload = $uploadSettings                            # 
    broadcast = $broadcastSettings                      # settings for the broadcast
    previewSettings = $previewSettings                  # settings for the email html preview
    response = $responseSettings                        # settings for the response download

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
# Choose URN field from recipients list automatically
#-----------------------------------------------

# Get Urn field of this list
$settings.urnFieldName = ( $recipientLists | where { $_.id -eq $masterList.id } ).$recipientListUrnFieldname


#-----------------------------------------------
# ATTRIBUTES TO EXCLUDE
#-----------------------------------------------

<#
Normally some of these
"Opt-in Source","Opt-in Date","Created","Modified","Erstellt am","Geändert am","Opt-in-Quelle","Opt-in-Datum","BROADMAIL_ID","WELLE_ID"
Please exclude "Urn", too as this is loaded dynamically through the channel
#>

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$settings.masterListId;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | Out-GridView -PassThru
$settings.excludedAttributes = $listAttributes


#-----------------------------------------------
# URN FIELD
#-----------------------------------------------

<#
Is one of these fields the urn field? If there is no urn field, just cancel
#>

$urnField = [array]( $listAttributes | Out-GridView -PassThru )

if ($urnField.count -gt 0 ) {
    $settings.urnFieldName = $urnField[0]
}


#-----------------------------------------------
# SAVE
#-----------------------------------------------

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8



