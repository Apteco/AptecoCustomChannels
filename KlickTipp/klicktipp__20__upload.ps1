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
        mode= "process"
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
$modulename = "KTUPLOAD"

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

#https://support.klicktipp.com/article/388-rest-application-programming-interface-api

switch ( $params.mode ) {

    "tags" {
        $restParams = @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/tag.json"
            "ContentType" = $settings.contentType
            "Headers" = $headers
            "Verbose" = $true
        }
        $tags = Invoke-RestMethod @restParams

        #'/subscriber/tag', 'POST', email+tagids
        #'/subscriber/untag', 'POST', email+tagid

    }

    "lists" {
        $restParams = @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/list.json"
            "ContentType" = $settings.contentType
            "Headers" = $headers
            "Verbose" = $true
        }
        $lists = Invoke-RestMethod @restParams
    }
    
    # Setup if setting is not present or not tags
    default {
        $list = $modeList

        #'/subscriber', 'POST', $data
        #'/subscriber/unsubscribe', 'POST', email
        <#
        $subscriberdata @{
            email = ""
            smsnumber = ""
            listid = 0
            tagid = 0
            fields = @{
        
            }
        }
        #>
    }

}

$restParams = @{
    "Method" = "Get"
    "Uri" = "$( $settings.base )/field.json"
    "ContentType" = $settings.contentType
    "Headers" = $headers
    "Verbose" = $true
}

$fields = Invoke-RestMethod @restParams


# Do the end stuff
. ".\bin\end.ps1"


################################################
#
# RETURN
#
################################################

# real messages
#return $messages

