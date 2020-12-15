
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

        # Send from PeopleStage
        MessageName = "7586236 / Newsletter September 2020"
        ListName = "7586236 / Newsletter September 2020"
        Username = "a"
        Password = "b"

        # Integration parameters
        scriptPath = "D:\Scripts\CleverReach\Mailing"
        deactivate = "true"

        # Send from upload
        GroupId = "1128550"
        TransactionId = "ff62edd3-add6-4638-9e63-26c6b622a316"

    }
}


################################################
#
# NOTES
#
################################################

<#

TODO [x] implement more logging

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
$moduleName = "CLVRBRCST"
$processId = $params.TransactionId #[guid]::NewGuid()

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
<#
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
#>

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
#$messageName = $params.MessageName
#$templateId = $messageName -split $settings.nameConcatChar | select -First 1
$template = [Mailing]::new($params.MessageName)
$templateId = $template.mailingId
Write-Log -message "Using mailing $( $templateId ) - $( $template.mailingName )"

# get details
$object = "mailings"    
$endpoint = "$( $apiRoot )$( $object )"
$templateSource = Invoke-RestMethod -Method GET -Uri "$( $apiRoot )$( $object ).json/$( $templateId )" -Headers $header -Verbose
Write-Log -message "Looked up the mailing"


#-----------------------------------------------
# GET GROUP DETAILS 
#-----------------------------------------------

$object = "groups"    
$endpoint = "$( $apiRoot )$( $object ).json/$( $params.GroupId )/stats"
$groupDetails = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType
Write-Log -message "Using group $( $groupDetails.id ) - $( $groupDetails.name )"


#-----------------------------------------------
# COPY MAILING
#-----------------------------------------------

Write-Log -message "Creating a copy of the mailing"

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

Write-Log -message "Created a copy of the mailing with the new id $( $copiedMailing.id )"


#-----------------------------------------------
# GET NEW CREATED MAILING
#-----------------------------------------------

<#
# get links
$mailingLinks = Invoke-RestMethod -Method GET -Uri "$( $mailingsUrl )/$( $te.id )/links" -Headers $header -Verbose #-ContentType $contentType
$mailingLinks | Out-GridView
#>

# get details
$object = "mailings"
$endpoint = "$( $apiRoot )$( $object ).json/$( $copiedMailing.id )"
$copiedMailingDetails = Invoke-RestMethod -Method GET -Uri $endpoint -Headers $header -Verbose -ContentType $contentType

<#
# write html to file
$templateSource.body_html | Set-Content -Path "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") ).html" -Encoding UTF8
#>


#-----------------------------------------------
# TRIGGER BROADCAST
#-----------------------------------------------

Write-Log -message "Release the mailing"

# release mailing
[int]$unixTimestamp = Get-Unixtime #Get-Date -uformat %s -Millisecond 0
[int]$releaseTimestamp = $unixTimestamp + 60 #-7200 # TODO [ ] check what this was about and create settings parameter for sending offset (or put in channel editor)
$release = [PSCustomObject]@{
    "time" = $releaseTimestamp
}
$releaseJson = $release | ConvertTo-Json -Depth 8 -Compress

# TODO [x] use the id delivered by the upload
$object = "mailings"
$endpoint = "$( $apiRoot )$( $object ).json/$( $copiedMailing.id )/release"
$releaseMailing = Invoke-RestMethod -Method POST -Uri $endpoint -Headers $header -Verbose -Body $releaseJson -ContentType $contentType

Write-Log -message "Released the mailing"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [x] this is only a workaround until the handover from the return upload hashtable to the broadcast is fixed
$recipients = $groupDetails.active_count

# put in the source id as the listname
$transactionId = $releaseMailing.id #$copiedMailing.id

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$moduleName
    "ProcessId" = $processId
}

# return the results
$return

