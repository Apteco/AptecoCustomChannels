################################################
#
# INPUT
#
################################################

#Param(
#    [hashtable] $params
#)

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


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
$modulename = "authToUI"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


################################################
#
# MORE SETTINGS AFTER LOADING FUNCTIONS
#
################################################

# ...
[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# CREATE JWT AND AUTH URI
#-----------------------------------------------

Write-Log -message "Creating a login url"

$jwt = Create-JwtToken -headers $settings.headers -payload $settings.defaultPayload -secret ( Get-SecureToPlaintext -String $settings.authentication.ssoTokenKey )

$uri = [uri]$settings.base 
$hostUri = $uri.AbsoluteUri -replace $uri.AbsolutePath


$authUri = "https://print-mailing.deutschepost.de/planen?partnersystem=$( $jwt )" #"$( $hostUri )?partnersystem=$( $jwt )"
$authUri


#-----------------------------------------------
# OPEN IN DEFAULT BROWSER
#-----------------------------------------------

Start-Process "$( $authUri )"

[void](Read-Host 'Press Enter to continue…')
