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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM"
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
$modulename = "EMMUPDATETARGETGROUP"

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

$str = "54368 | Zielgruppe_mit_sendID"
$targetGroup = [TargetGroup]::new($str)

$eql = @"
`send_id` = '$( $processId )'
"@


# Load data from Agnitas EMM

$param = @{
    targetID = [Hashtable]@{
        type = "int"
        value = $targetGroup.targetGroupId
    }

    description = [Hashtable]@{
        type = "string"
        value = "Hello World Da draussen"
    }

    eql = [Hashtable]@{
        type = "string"
        value = $eql
    }
}

$targetgroupsEmm = Invoke-Agnitas -method "UpdateTargetGroup" -param $param -verboseCall -noresponse -namespace "http://agnitas.com/ws/schemas" #-wsse $wsse #-verboseCall
