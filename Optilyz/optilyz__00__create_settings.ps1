
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

$keyFile = "$( $scriptPath )\aes.key"
$token = Read-Host -AsSecureString "Please enter the token for optilyz"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password) -keyFile $keyFile

$loginSettings = @{
    token = $tokenEncrypted 
}


#-----------------------------------------------
# AWS SETTINGS
#-----------------------------------------------

$accessKey = Read-Host -AsSecureString "Please enter the access key for AWS S3"
$accessKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessKey).GetNetworkCredential().Password) -keyFile $keyFile

$secretKey = Read-Host -AsSecureString "Please enter the secret key for AWS S3"
$secretKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$secretKey).GetNetworkCredential().Password) -keyFile $keyFile


$awsSettings = @{

    accessKey = $accessKeyEncrypted # enter your access key
    secretKey = $secretKeyEncrypted # enter the secret key
    region = "eu-central-1"
    service = "s3"
    endpoint = "https://s3-eu-central-1.amazonaws.com"

}



#-----------------------------------------------
# MAILINGS SETTINGS
#-----------------------------------------------

$mailingsSettings = @{
    states = @("paused","live") # paused|live
    #recipientListFile = "$( $scriptPath )\recipientlists.json"
    #status = "NEW" # NEW|SENDING|DONE|CANCELED -> default should be "SENDING" for productive use, for testing purposes and fill the lists without an email send, use "NEW"
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    #rowsPerUpload = 800 # TODO [ ] is this used?
    #uploadsFolder = "$( $scriptPath )\uploads\"
    #excludedAttributes = @()							# Will be defined later in the process
    #recipientListUrnFieldname = 'ID-Feld'				# Normally no need to change
    #recipientListUrnField = ""							# Will be defined later in the process
    #recipientListEmailField = "email"					# Normally no need to change
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?
# TODO [ ] Documentation of all these parameters and the ones above

$settings = @{

    # General
    base="https://www.campaign-automation.de/api/v2/automations"   # Default url
    changeTLS = $true                                   # should tls be changed on the system?
    nameConcatChar = " / "                              # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\optilyz.log"               # path and name of log file
    providername = "optilyz"                              # identifier for this custom integration, this is used for the response allocation

    # Session 
    aesFile = $keyFile
    #sessionFile = "$( $scriptPath )\session.json"                        # name of the session file
    #ttl = 15                                            # Time to live in minutes for the current session, normally 20 minutes for EpiServer Campaign
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    aws = $awsSettings
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

#Get-EpiSession

#-----------------------------------------------
# MASTERLIST
#-----------------------------------------------

<#

normally something like:
ClosedLoopWebserviceTemplate: master

#>
<#
$recipientLists = Get-EpiRecipientLists 
$masterList = $recipientLists | Out-GridView -PassThru | Select -First 1
$recipientListUrnFieldname = $settings.upload.recipientListUrnFieldname
$urnFieldName = ( $recipientLists | where { $_.id -eq $masterList.id } ).$recipientListUrnFieldname
$settings.upload.recipientListUrnField = $urnFieldName 
#>

#-----------------------------------------------
# ATTRIBUTES TO EXCLUDE
#-----------------------------------------------

<#
Normally some of these
"Opt-in Source","Opt-in Date","Created","Modified","Erstellt am","Geändert am","Opt-in-Quelle","Opt-in-Datum","BROADMAIL_ID","WELLE_ID"
Please exclude "Urn", too as this is loaded dynamically through the channel
#>
<#
$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$masterList.id;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | Out-GridView -PassThru
$settings.upload.excludedAttributes = $listAttributes
#>

#-----------------------------------------------
# SAVE
#-----------------------------------------------
<#
# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8

#>