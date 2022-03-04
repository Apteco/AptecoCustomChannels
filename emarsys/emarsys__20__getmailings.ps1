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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\emarsys"
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

$script:moduleName = "EMARSYS-GET-MAILINGS"

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

$messages = [System.Collections.ArrayList]@()
try {


    ################################################
    #
    # TRY
    #
    ################################################


    #-----------------------------------------------
    # CREATE EMARSYS OBJECT
    #-----------------------------------------------

    $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.secret ) -AsPlainText -Force
    $cred = [pscredential]::new( $settings.login.username, $stringSecure )

    # Create emarsys object
    $emarsys = [Emarsys]::new($cred,$settings.base)


    #-----------------------------------------------
    # GET EVENTS
    #-----------------------------------------------

    $events = $emarsys.getExternalEvents()

    Write-Log "Loaded '$( $events.Count )' external events from emarsys"


    $eventsList = [System.Collections.ArrayList]@()
    $events | ForEach {
        $event = $_
        [void]$eventsList.add([DCSPMailing]@{
            id=$event.id
            name=$event.name
            created =$event.created
        })
    }

    # Transform the mailings array into the needed output format
    $columns = @(
        @{
            name="id"
            expression={ $_.id }
        }
        @{
            name="name"
            expression={ $_.toString() }
        }
    )
    [void]$messages.AddRange(@( $eventsList | Select $columns ))
    


    #-----------------------------------------------
    # FIELDS
    #-----------------------------------------------

    #$fields = $emarsys.getFields($false) #| Out-GridView -PassThru | Select -first 20
    #$fields | Out-GridView
    #$fields | Export-Csv -Path ".\fields.csv" -Encoding Default -NoTypeInformation -Delimiter "`t"
    #$fields | Select @{name="field_id";expression={ $_.id }}, @{name="fieldname";expression={$_.name}} -ExpandProperty choices | Export-Csv -Path ".\fields_choices.csv" -Encoding Default -NoTypeInformation -Delimiter "`t"



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

    $messages

}

exit 0

################################################
#
# DEBUG
#
################################################


#-----------------------------------------------
# LOAD SETTINGS
#-----------------------------------------------

# Read settings
$emarsys.getSettings()



exit 0

# Other calls

<#
$emarsys.getEmailTemplates() 
$emarsys.getAutomationCenterPrograms()
$emarsys.getExternalEvents()
$emarsys.getLinkCategories()
$emarsys.getSources()
$emarsys.getAutoImportProfiles()
$emarsys.getConditionalTextRules()
#>
