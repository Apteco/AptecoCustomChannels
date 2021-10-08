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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM\API"
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

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "AGNITAS-GET-TARGETGROUPS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"

# Do the preparation
. ".\bin\preparation.ps1"


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# BUILD TARGETGROUPS OBJECTS
#-----------------------------------------------

# Load data from Agnitas EMM
$targetgroupsEmm = Invoke-Agnitas -method "ListTargetgroups" #-wsse $wsse #-verboseCall

# Transform the target groups into an array of targetgroup objects
$targetGroups = [System.Collections.ArrayList]@()
$targetgroupsEmm.item | ForEach {
    [void]$targetGroups.Add([TargetGroup]@{
        targetGroupId=$_.id
        targetGroupName=$_.name
    })
}

# Transform the objects into the PeopleStage format
$columns = @(
    @{
        name="id"
        expression={ $_.targetGroupId }
    }
    @{
        name="description"
        expression={ $_.toString() }
    }
)
$messages = $targetGroups | Select $columns #@{name="id";expression={ $_.targetGroupId }}, @{name="name";expression={ $_.toString() }}


################################################
#
# RETURN
#
################################################

# real messages
$messages

