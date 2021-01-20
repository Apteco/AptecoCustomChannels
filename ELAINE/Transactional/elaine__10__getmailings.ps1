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
	    Password= "def"
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\ELAINE\Transactional"
	    abc= "def"
	    Username= "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#


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
$moduleName = "ELNMAILINGS"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS
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
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# AUTH
#-----------------------------------------------

# https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $settings.login.username ):$( Get-SecureToPlaintext $settings.login.token )"))
 
# Step 3. Form the header and add the Authorization attribute to it
$headers = @{ Authorization = "Basic $encodedCredentials" }


#-----------------------------------------------
# HEADER + CONTENTTYPE + BASICS
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"

$headers += @{

}

$defaultRestParams = @{
    Headers = $headers
    Verbose = $true
    ContentType = $contentType
}

$defaultRestParamsPost = @{
    Headers = $headers
    Verbose = $true
    Method = "Post"
    ContentType = "application/x-www-form-urlencoded"
}


#-----------------------------------------------
# ELAINE VERSION
#-----------------------------------------------
<#
This call should be made at the beginning of every script to be sure the version is filled (and the connection could be made)
#>

if ( $settings.checkVersion ) { 

    $function = "api_getElaineVersion"
    $restParams = $defaultRestParams + @{
        Uri = "$( $apiRoot )$( $function )?p1=false&response=$( $settings.defaultResponseFormat )"
        Method = "Get"
    }

    #$res = Invoke-RestMethod -Uri $url -Method get -Verbose -Headers $headers -ContentType $contentType
    $elaineVersion = Invoke-RestMethod @restParams

}
# Use this function to check if a mininum version is needed to call the function
#Check-ELAINE-Version -minVersion "6.2.2"


#-----------------------------------------------
# MAILINGS BY STATUS - METHOD 2
#-----------------------------------------------
<#
This one returns the nl_id, nl_name and nl_status
Transactional Mailings and Automation Mails (subscribe, unsubscribe, etc.) have the status "actionmail", the normal mailings have "ready"
#>

$function = "api_getMessageInfo"
$jsonInput = @(
    ""      # message_name : string
    "actionmail" # message_status : on_hold|actionmail|ready|clearing|not_started|finished|processing|paused|aborted|failed|queued|scheduled|pending|sampling|deleted -> an empty string means all status
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$templates = Invoke-RestMethod @restParams
#$mailings | Out-GridView


#-----------------------------------------------
# BUILD MAILING OBJECTS
#-----------------------------------------------

$mailings = @()
$templates | foreach {

    # Load data
    $template = $_
    #$id = Get-StringHash -inputString $template.url -hashName "MD5" #-uppercase

    # Create mailing objects
    $mailings += [Mailing]@{
        mailingId=$template.nl_id
        mailingName=$template.nl_name
    }

}

$messages = $mailings | Select @{name="id";expression={ $_.mailingId }}, @{name="name";expression={ $_.toString() }}


################################################
#
# RETURN
#
################################################

# real messages
return $messages


