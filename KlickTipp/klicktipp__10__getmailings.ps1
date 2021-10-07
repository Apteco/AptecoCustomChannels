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

        # Integration parameters
        scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM"
        mode= "tags"


        # PeopleStage
	    Password= "def"
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


/list/' . urlencode($listid)
'/tag/' . urlencode($tagid)
'/tag', 'POST', name

https://support.klicktipp.com/article/388-rest-application-programming-interface-api


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
Set-Location -Path "$( $scriptPath )"


################################################
#
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "KTGETMESSAGE"

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


switch ( $params.mode ) {

    "tags" {
        
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/tag.json"
        }
        $tags = Invoke-RestMethod @restParams

        $tagList = [System.Collections.ArrayList]@()
        $tags.psobject.members | where { $_.MemberType -eq "NoteProperty" } | ForEach {
            $tag = $_
            [void]$tagList.add([PSCustomObject]@{
                "id" = $tag.Name
                "name" = $tag.Value
            })
        }

        # Add taglist twice for add and removal of tags
        $messages = $tagList | Select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )+$( $_.name )" }}
        $messages += $tagList | Select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )-$( $_.name )" }}

    }

    # TODO [ ] check! This lists DOI processes
    <#
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
    #>
    
    # Setup if setting is not present or not tags
    default {

        $messages = $modeList | Select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )$( $_.name )" }}

    }

}


# Do the end stuff
. ".\bin\end.ps1"


################################################
#
# RETURN
#
################################################

# real messages
$messages #| ft

