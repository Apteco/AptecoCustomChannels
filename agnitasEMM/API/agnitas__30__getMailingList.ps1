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

try {

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

} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

    exit 1

}


################################################
#
# PROGRAM
#
################################################

$lists = [System.Collections.ArrayList]@()
try {

    ################################################
    #
    # TRY
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

        Write-Log -message "StatusCode: $( $_.Exception.Response.StatusCode.value__ )" -severity ( [LogSeverity]::ERROR )
        Write-Log -message "StatusDescription: $( $_.Exception.Response.StatusDescription )" -severity ( [LogSeverity]::ERROR )

        throw $_.Exception

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
            name="name"
            expression={ "$( $_.mailinglist_id )$( $settings.nameConcatChar )$( $_.name )" }
        }
    )
    [void]$lists.AddRange(( $mailingLists | Select $columns ))


} catch {

    ################################################
    #
    # ERROR HANDLING
    #
    ################################################

    Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception

} finally {

    ################################################
    #
    # RETURN
    #
    ################################################

    $lists

}
