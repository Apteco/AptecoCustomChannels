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

$script:moduleName = "AGNITAS-GET-MAILINGS"

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

# Load preparation ($cred)
. ".\bin\preparation.ps1"


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# GET MAILINGS
#-----------------------------------------------

# Beginning the log
Write-Log -message "Downloading all mailings"

# Load the data from Agnitas EMM
try {

    <#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings
    #>
    $mailings = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailing" -Headers $header -Verbose -ContentType $contentType

} catch {

    Write-Host "ERROR - StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "ERROR - StatusDescription:" $_.Exception.Response.StatusDescription

}

Write-Log "Loaded '$( $mailings.Count )' mailings"

# Load and filter list into array of mailings
$mailingsList = [System.Collections.ArrayList]@()
$mailings | where { $_.type -eq "NORMAL" } | ForEach {
    $mailing = $_
    [void]$mailingsList.add(
        [Mailing]@{
            mailingId=$mailing.mailing_id
            mailingName=$mailing.name
        }
    )
}

# Transform the mailings array into the needed output format
$columns = @(
    @{
        name="id"
        expression={ $_.mailingId }
    }
    @{
        name="description"
        expression={ $_.toString() }
    }
)
$messages = $mailingsList | Select $columns


################################################
#
# RETURN
#
################################################

$messages

