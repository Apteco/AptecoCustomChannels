################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $false

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\Users\NLethaus\Documents\2021\InxmailFlorian\Inxmail"
        MessageName= "16 / VorlageVonNikolas240321"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://apidocs.inxmail.com/xpro/rest/v1/

Create a test profile

https://apidocs.inxmail.com/xpro/rest/v1/#create-test-profile

Existing Mailing

https://apidocs.inxmail.com/xpro/rest/v1/#_retrieve_single_mailing_rendered_content
GET /mailings/{id}/renderedContent{?testProfileId,includeAttachments}

Non-existing mailing -> only input html

https://apidocs.inxmail.com/xpro/rest/v1/#temporary-preview
POST /temporary-preview

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
if ( $debug ) {
    # Load scriptpath
    if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
        $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
    } else {
        $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
    }
} else {
    $scriptPath = "$( $params.scriptPath )" 
}
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "INXPREVIEW"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
    "... $( $_.FullName )"
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ) = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}

#-----------------------------------------------
# GET MAILING
#-----------------------------------------------

$mailingId = $params.MessageName -split " / ",2


#-----------------------------------------------
# GET MAILING DETAILS
#-----------------------------------------------

$mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )mailings/$( $mailingId[0] )" -Header $header -ContentType "application/hal+json" -Verbose


#-----------------------------------------------
# GET LIST DETAILS
#-----------------------------------------------

$listDetails = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )lists/$( $mailingDetails.listId )" -Header $header -ContentType "application/hal+json" -Verbose


#-----------------------------------------------
# RENDER MAILING
#-----------------------------------------------
# https://apidocs.inxmail.com/xpro/rest/v1/#_retrieve_single_mailing_rendered_content
# /mailings/{id}/renderedContent{?testProfileId,includeAttachments}

$renderedRes = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )mailings/$( $mailingDetails.id )/renderedContent" -Header $header -ContentType "application/hal+json" -Verbose


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# return object
$return = [Hashtable]@{
    "Type" = "Email" #Email|Sms
    "FromAddress"=$listDetails.senderAddress
    "FromName"=$listDetails.senderName
    "Html"=$renderedRes.html
    "ReplyTo"=$listDetails.replyToAddress
    "Subject"=$renderedRes.subject
    "Text"=$renderedRes.text
}

# return the results
$return



