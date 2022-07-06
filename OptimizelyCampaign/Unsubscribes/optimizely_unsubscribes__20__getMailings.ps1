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
    # GET CURRENT SESSION OR CREATE A NEW ONE
    #-----------------------------------------------

    Write-Log -message "Opening a new session in EpiServer valid for $( $settings.ttl )"


    #Format-SoapParameter -var "Hello" -paramIndex 0
    #-----------------------------------------------
    # GET MAILINGS
    #-----------------------------------------------

    $campaigns = Get-EpiCampaigns -campaignType "smart"
    exit 0

    
    Write-Log -message "Got back $( $campaigns.count ) campaigns/mailings"
    


    <#
    # Beginning the log
    Write-Log -message "Downloading all mailings"

    # Load the data from Agnitas EMM
    try {

        $restParams = @{
            Method = "Get"
            Uri = "$( $apiRoot )/mailing"
            Headers = $header
            Verbose = $true
            ContentType = $contentType
        }
        Check-Proxy -invokeParams $restParams
        $mailings = Invoke-RestMethod @restParams

    } catch {

        Write-Log -message "StatusCode: $( $_.Exception.Response.StatusCode.value__ )" -severity ( [LogSeverity]::ERROR )
        Write-Log -message "StatusDescription: $( $_.Exception.Response.StatusDescription )" -severity ( [LogSeverity]::ERROR )

        throw $_.Exception

    }

    #>

    Write-Log "Loaded '$( $campaigns.Count )' mailings"

    
    
    # Load and filter list into array of mailings
    $mailingsList = [System.Collections.ArrayList]@()
    $mailings | where { $_.type -eq "NORMAL" -and $_.name -notlike "*$( $settings.messages.copyString )*"} | ForEach {
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
            name="name"
            expression={ $_.toString() }
        }
    )
    [void]$messages.AddRange(@( $mailingsList | Select $columns ))


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

