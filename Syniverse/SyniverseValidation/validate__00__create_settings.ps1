################################################
#
# TODO
#
################################################

<#

[ ] possibly a user token could make sense

To access these APIs , customers need to authenticate and authorize their access within the API call.
This requires passing the access token, and potentially the user token, in the API call headers.
User token requirement is dependent on how the company environment has been setup by the customer. 


#>

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
# AUTHENTICATION
#-----------------------------------------------

$consumerSecret = Read-Host -AsSecureString "Please enter the consumerSecret for syniverse"
$consumerSecretEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$consumerSecret).GetNetworkCredential().Password)

$accessToken = Read-Host -AsSecureString "Please enter the accessToken for syniverse"
$accessTokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessToken).GetNetworkCredential().Password)

$authentication = @{
    consumerKey = "<consumerkey>"
    consumerSecret = $consumerSecretEncrypted 
    accessToken = $accessTokenEncrypted
}


#-----------------------------------------------
# NISScrub - Discover valid numbers
#-----------------------------------------------

# see the layouts
<#
$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
    "Content-Type"= "application/json"
}
$url = "$( $settings.base )aba/v1/layouts"
$layouts = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -Verbose 
#>

$validationOptions = @()

$validationOptions += [pscustomobject]@{
    id = "123"
    name = "Validate globally"
}

$validationOptions += [pscustomobject]@{
    id = "456"
    name = "Validate UK"
}

$validationOptions += [pscustomobject]@{
    id = "789"
    name = "Validate DE"
}

$nisscrub = @{
    "inputLayoutName" = "MDN-input-v1"
    "outputLayoutName" = "NIS-Scrub-Output-v1"
    "validationOptions" = $validationOptions
}



#-----------------------------------------------
# MEDIACENTER
#-----------------------------------------------

$emptyFileContent = @{
    "fileName" = ""
    "fileTag" = ""
    "fileFolder" = ""
    "appName" = ""
    "expireTimestamp" = ""
    "checksum" = ""
    "file_fullsize" = "2000000"
    <#"compressionType" = ""#>
}

$mediacenter = @{
    emptyFileContent = $emptyFileContent
    maxTries = 100 # number of tries while checking status of batch automation
    waitBetweenTries = 1000 # milliseconds
    timeoutSecForDeletion = 2
}


#-----------------------------------------------
# EVERYTHING TOGETHER
#-----------------------------------------------

$settings = @{

    # General
    base="https://api.syniverse.com/"    				# Default url
    changeTLS = $true                                   # should tls be changed on the system?
    nameConcatChar = " / "                              # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\syn_validate.log"         # path and name of log file
    providername = "synvd"                              # identifier for this custom integration, this is used for the response allocation

    # Authentication
    authentication = $authentication
    
    # Detail settings
    nisscrub = $nisscrub
    mediacenter = $mediacenter

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

