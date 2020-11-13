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

#-----------------------------------------------
# SEND SMS
#-----------------------------------------------

$countryMap = @{
    "+44"="uk"
    #"+33"="fr"
    "+49"="de"
    #"+34"="es"
    #"+45"="dk"
    #"+46"="se"
}

# public shared channel ids
# require no provisioning and no monthly or set up fees to use.
# limitations are shared with other SDC users, only support 1-way mobile terminated messages
# sender number is not fixed.
# we have public shared codes available for 58 countries listed here
$channelIds = @{
    "uk"="JXxaP5zAitsUnd66Ynavc"
    #"fr"="RUHDTglIodfuVx2vBg7qg3"
    "de"="JXxaP5zAitsUnd66Ynavc"
    #"es"="zm8lO9Y9QKGKTeS-BoHCKA"
    #"dk"="o4u6_YvUSLas0SjuFYCtDw"
    #"se"="qAQwTeyCQsi5UturUnJApQ"
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

$nisscrub = @{
    "inputLayoutName" = "MDN-input-v1"
    "outputLayoutName" = "NIS-Scrub-Output-v1"
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
    base="https://api.syniverse.com/"
    general=@{
    }
    authentication = $authentication
    countryMap = $countryMap
    channels = $channelIds
    mediacenter = $mediacenter
    nisscrub = $nisscrub
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

