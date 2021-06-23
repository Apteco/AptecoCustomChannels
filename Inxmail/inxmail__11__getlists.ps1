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
	    scriptPath= "C:\Users\NLethaus\Documents\GitHub\CustomChannels\Inxmail"
    }
}

################################################
#
# NOTES
#
################################################

<#

https://apidocs.inxmail.com/xpro/rest/v1

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
$settingsFilename = "settings.json"
$moduleName = "INXGETLISTS"
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
        Write-Log -message "$( $param ): $( $params[$param] )"
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
# GET LISTS
#-----------------------------------------------
# Beginning the log
Write-Log -message "Downloading all lists"

# Precooked variables for the loop
$pageSize = 3
$messageLists = [System.Collections.ArrayList]@()
$object = "lists"

$totalNumOfLists = 0
$numOfLists = 0

$endpoint = "$( $apiRoot )$( $object )?pageSize=$( $pageSize )"
# Beginning of do-until loop
do{
    <#
        This contains now all the lists Information till $p
    
        https://apidocs.inxmail.com/xpro/rest/v1/#_retrieve_mailing_lists_collection
    #>
    $lists = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType
    
    # Counting the number of lists found for the log
    $numOfLists = $lists._embedded."inx:lists".count
    $totalNumOfLists += $numOfLists
    Write-Log -message "Found $( $numOfLists ) lists"

    #-----------------------------------------------
    # GET LISTS
    #-----------------------------------------------

    # Adding the ListId + the list Name into the array of Lists
    $messageLists += $lists._embedded."inx:lists" | Select-Object @{
        name="id";expression={ $_.id }
    }, @{
        name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )$( $_.name )" }
    }

    $endpoint = $lists._links.next.href

# If number of lists are less than $p2 = 5, then that it is the last loop cycle
}until($null -eq $lists._links.next)

Write-Log -message "Found $( $totalNumOfLists ) lists"

################################################
#
# RETURN
#
################################################

# real messages
return $messageLists

