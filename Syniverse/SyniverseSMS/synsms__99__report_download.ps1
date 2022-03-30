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
    }
}

################################################
#
# NOTES
#
################################################

<#

https://github.com/Syniverse/QuickStart-BatchNumberLookup-Python/blob/master/ABA-example-external.py

FILEUPLOAD UP TO 2 GB allowed

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

$script:moduleName = "SYNSMS-REPORT"

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

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

# types: SMS, MMS, PSH, FB
$results = [System.Collections.ArrayList]@()
$limit = 100
$offset = 0

# The result includes 50 entries per call
Do {
    
    $url = "$( $settings.base )scg-external-api/api/v1/messaging/messages?offset=$( $offset )&type=SMS&limit=$( $limit )&sort=created_date"# &created_date=[2020-05-31T22:00:00.000Z,2021-06-11T14:31:59.000Z]"

    try {

        $paramsPost = [Hashtable]@{
            Uri = $url
            Method = "Get"
            Headers = $headers
            Verbose = $true
            ContentType = $contentType
        }

        "$( $paramsPost.uri )"

        $res = Invoke-RestMethod @paramsPost
        $results.AddRange($res.list)

    } catch {

        $e = ParseErrorForResponseBody -err $_
        Write-Log -message $e

    }

    $offset += $res.limit


} until ( $offset -ge $res.total )




#Write-Log -message "Just forwarding parameters to broadcast"

$results | select *, @{name="fragments_count";expression={ $_.fragments_info.count }} | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`n",' ' } | Out-File ".\$( $timestamp )_$( $processId.Guid )_messages.csv" -Encoding utf8
$results | select id -ExpandProperty fragments_info | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`n",' ' } | Out-File ".\$( $timestamp )_$( $processId.Guid )_fragments.csv" -Encoding utf8