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
	    Password= "def"
        scriptPath = "C:\FastStats\scripts\optilyz_v2"
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
$settingsFilename = "settings.json"
$moduleName = "GETMAILINGS"

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
$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


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

# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( Get-SecureToPlaintext $settings.login.token ):"))
 
# Step 3. Form the header and add the Authorization attribute to it
$headers = @{ Authorization = "Basic $encodedCredentials" }


#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS DETAILS
#-----------------------------------------------

$url = "$( $settings.base )/v2/automations" 

$result = Invoke-RestMethod -uri $url -Headers $headers -Method Get -Verbose



#-----------------------------------------------
# GET MAILINGS DETAILS
#-----------------------------------------------

$messages = $result | where { $_.state -in $settings.mailings.states } | Select-Object @{name="id";expression={ $_.'_id' }},
                                            @{name="name";expression={ "$( $_.'_id' )$( $settings.nameConcatChar )$( $_.name )"}} #$( if ($_.Description -ne '') { $settings.nameConcatChar } )$( $_.Description )" }}



################################################
#
# RETURN
#
################################################

# real messages
return $messages


