
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

$debug = $true


#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\FastStats\scripts\cleverreach"
        MessageName = "275324762694 / Test: Smart Campaign Mailing"
        abc = "def"
        ListName = "275324762694 / Test: Smart Campaign Mailing"
        Password = "def"
        Username = "abc"
        # Send from upload
        GroupId = "13245"
    }
}


################################################
#
# NOTES
#
################################################

<#

TODO [ ] implement more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "CLVRUPLOAD"
$processId = [guid]::NewGuid()

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
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
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
        Write-Log -message "    $( $param ): $( $params[$param] )"
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
$auth = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
$header = @{
    "Authorization" = $auth
}


#-----------------------------------------------
# MAILING ID
#-----------------------------------------------

# cut out the smart campaign id or mailing id
$messageName = $params.MessageName
$templateId = $messageName -split $settings.nameConcatChar | select -First 1


#-----------------------------------------------
# GET MAILING TO COPY
#-----------------------------------------------

# get details
$templateSource = Invoke-RestMethod -Method GET -Uri "$( $mailingsUrl )/$( $templateId )" -Headers $header -Verbose

#-----------------------------------------------
# GET GROUP DETAILS 
#-----------------------------------------------

$object = "groups"    
$endpoint = "$( $apiRoot )$( $object ).json/1093437/stats"
$groupDetails = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType "application/json; charset=utf-8"


#-----------------------------------------------
# COPY MAILING
#-----------------------------------------------

$mailingSettings = @{
    name = "$( $templateSource.name ) - $( $timestamp )"
    subject = $templateSource.subject
    sender_name = $templateSource.sender_name
    sender_email = $templateSource.sender_email 
    content = @{
        type = $settings.broadcast.defaultContentType
        html = $templateSource.body_html
        text = $templateSource.body_text
    }
    receivers = @{
        groups = @($params.GroupId) # TODO [ ] get group from upload
        # filter = "66"
    }
    settings = @{
        editor = $settings.broadcast.defaultEditor
        open_tracking = $settings.broadcast.defaultOpenTracking
        click_tracking = $settings.broadcast.defaultClickTracking
        category_id = $templateSource.category_id
        <#
        link_tracking_url = "27.wayne.cleverreach.com"
        link_tracking_type = "google" # google|intelliad|crconnect
        unsubscribe_form_id = "23"
        campaign_id = "52"
        #>
    }
}

$rootJson = $mailingSettings | ConvertTo-Json -Depth 8 -Compress

# put it all together
$object = "mailings"
$endpoint = "$( $apiRoot )$( $object ).json"
$copiedMailing = Invoke-RestMethod -Method POST -Uri "$( $endpoint )" -Headers $header -Verbose -Body $rootJson -ContentType $contentType


#-----------------------------------------------
# GET NEW CREATED MAILING
#-----------------------------------------------

<#
# get links
$mailingLinks = Invoke-RestMethod -Method GET -Uri "$( $mailingsUrl )/$( $te.id )/links" -Headers $header -Verbose #-ContentType $contentType
$mailingLinks | Out-GridView
#>

# get details
$mailingDetails = Invoke-RestMethod -Method GET -Uri "$( $mailingsUrl )/$( $copiedMailing.id )" -Headers $header -Verbose

<#
# write html to file
$templateSource.body_html | Set-Content -Path "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") ).html" -Encoding UTF8
#>


#-----------------------------------------------
# TRIGGER BROADCAST
#-----------------------------------------------

# release mailing
[int]$unixTimestamp = Get-Unixtime #Get-Date -uformat %s -Millisecond 0
[int]$releaseTimestamp = $unixTimestamp + 60 -7200 # TODO [ ] check what this was about and create settings parameter for sending offset (or put in channel editor)
$release = [PSCustomObject]@{
    "time" = $releaseTimestamp
}
$releaseJson = $release | ConvertTo-Json -Depth 8 -Compress

# TODO [ ] use the id delivered by the upload
$releaseMailing = Invoke-RestMethod -Method POST -Uri "$( $mailingsUrl )/$( $copiedMailing.id )/release" -Headers $header -Verbose -Body $releaseJson -ContentType $contentType


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [x] this is only a workaround until the handover from the return upload hashtable to the broadcast is fixed
$recipients = $groupDetails.active_count

# put in the source id as the listname
$transactionId = $mailingId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

