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

        scriptPath = "C:\FastStats\scripts\episerver\smart campaigns"
        MessageName = "275324762694 / Test: Smart Campaign Mailing"
        abc = "def"
        ListName = "275324762694 / Test: Smart Campaign Mailing"
        Password = "def"
        Username = "abc"

        # From script before
        ProcessId = "e45f330c-7193-47e7-92e6-e8c6ce2c7751"
        NewLines = 10

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

$script:moduleName = "RABATT-BROADCAST"


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

try {

    
    ################################################
    #
    # TRY
    #
    ################################################



    ################################################
    #
    # FINISH
    #
    ################################################

    $end = New-TimeSpan -Start $timestamp -End ([Datetime]::Now)

    # log 
    Write-Log -message "'$( $script:moduleName )' done in $( $end.totalSeconds ) seconds!"


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

    # TODO [ ] Check the return values

    # count the number of successful upload rows
    $recipients = $params.NewLines

    # put in the source id as the listname
    $transactionId = $processId

    # return object
    $return = [Hashtable]@{
        "Recipients"=$recipients
        "TransactionId"=$transactionId
        "CustomProvider"=$settings.providername
    }

    # return the results
    $return

}

