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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM\API"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings

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
$script:moduleName = "AGNITAS-GET-MAILING-LISTS"

# Load general settings
. ".\bin\general_settings.ps1"

# Load settings
. ".\bin\load_settings.ps1"

# Load network settings
. ".\bin\load_networksettings.ps1"

# Load functions
. ".\bin\load_functions.ps1"

# Start logging
. ".\bin\startup_logging.ps1"

# Load prepartation
. ".\bin\preparation.ps1"


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# GET MAILING LISTS
#-----------------------------------------------

# Load the data from Agnitas EMM
try {


<#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailinglist-getMailinglist
#>
$mailinglists = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailinglist" -Headers $header -ContentType $contentType -Verbose
#$invoke = $invoke.mailinglist_id

} catch {

    Write-Host "ERROR - StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "ERROR - StatusDescription:" $_.Exception.Response.StatusDescription

}

Write-Log "Loaded '$( $mailinglists.Count )' mailing lists"


#$NumberOfMailingLists = $invoke.count

# TODO [ ] Transform this into an object rather than a string
$columns = @(
    @{
        name="id"
        expression={ $_.mailinglist_id }
    }
    @{
        name="description"
        expression={ "$( $_.mailinglist_id )$( $settings.nameConcatChar )$( $_.name )" }
    }
)
$lists = $mailingLists | Select $columns


################################################
#
# RETURN
#
################################################

return $lists

