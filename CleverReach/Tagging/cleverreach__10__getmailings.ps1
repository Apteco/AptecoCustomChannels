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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\CleverReach\Tagging"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://rest.cleverreach.com/explorer/v3

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
$moduleName = "CLVRGETMAILINGS"
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
#$contentType = $settings.contentType


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
# GET TAGS
#-----------------------------------------------

$object = "tags"

Write-Log -message "Downloading all tags"

# get all draft mailings
# TODO [ ] implement paging
$endpoint = "$( $apiRoot )$( $object ).json?group_id=0&origin=*&order_by=tag&limit=999&page=0"
$tags = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType "application/json; charset=utf-8"

Write-Log -message "Found $( $mailings.draft.count  ) mailings"

# TODO [ ] implement mailing class


#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS
#-----------------------------------------------
<#
$object = "mailings"

Write-Log -message "Downloading all mailings"

# get all draft mailings
$endpoint = "$( $apiRoot )$( $object )?state=draft&limit=999"
$mailings = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType "application/json; charset=utf-8"

Write-Log -message "Found $( $mailings.draft.count  ) mailings"


#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS DETAILS
#-----------------------------------------------

$messages = $mailings.draft | Select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )$( $_.name )" }}
#>

$messages = $tags | sort origin,tag -Descending | select @{name="id";expression={ "$( $_.origin ).$( $_.tag )" }}, @{name="name";expression={ "$( $_.origin ).$( $_.tag )" }}

################################################
#
# RETURN
#
################################################

# real messages
return $messages

