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
        ProcessId = "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://world.optimizely.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/basic-usage/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

TODO [ ] implement more logging

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
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"
$moduleName = "BROADCAST"
$processId = $params.ProcessId #[guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}



################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# TRIGGER WAVE
#-----------------------------------------------

# Schedule the mailing
# TODO [ ] use this after tests with 2019-Q4
# Invoke-Epi -webservice "ClosedLoop" -method "importFinishedAndScheduleMailing" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true

# TODO [ ] is this defined correct?
$waveId = $params.TransactionId
Write-Log -message "Loading the wave id $( $waveId ) from the previous upload process"



# Wait for the import to be completed
if ( $settings.syncType -eq "sync" ) {

    # Log
    Write-Log -message "Using sync process and will ask for a mailing id "
    Write-Log -message "Waiting for $( $settings.broadcast.waitSecondsForMailingCreation ) seconds between loops"

    # Creating a new session
    Write-Log -message "Opening a new session in EpiServer valid for $( $settings.ttl ) minutes"
    Get-EpiSession

    # Looping until mailing id created
    # TODO [ ] implement a counter or max wait time to trigger exceptions
    #Write-Host "Throwing Exception because xxx"
    #throw [System.IO.InvalidDataException] "Max waittime or tries reached!"  
    
    Do {
        Start-Sleep -Seconds $settings.broadcast.waitSecondsForMailingCreation
        Write-Log -message "Asking for a mailing id"
        $mailingId = Invoke-Epi -webservice "ClosedLoop" -method "getMailingIdByWaveId" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true
    } until ( $mailingId-ne 0 ) # TODO [ ] implement the timer -or $seconds -gt $settings.broadcast.maxSecondsForMailingToFinish)
    
    # Results
    Write-Log -message "Got back mailing id $( $mailingId )"

    # Load stats
    $overallRecipientCount = Invoke-Epi -webservice "Mailing" -method "getOverallRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
    $failedRecipientCount = Invoke-Epi -webservice "Mailing" -method "getFailedRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
    $sentRecipientCount = Invoke-Epi -webservice "Mailing" -method "getSentRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
    $mailingStartedDate = Invoke-Epi -webservice "Mailing" -method "getSendingStartedDate" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
    $mailingFinishedDate = Invoke-Epi -webservice "Mailing" -method "getSendingFinishedDate" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true

    # Log
    Write-Log -message "Overall recipients: $( $overallRecipientCount )"
    Write-Log -message "Failed: $( $failedRecipientCount )"
    Write-Log -message "Sent: $( $sentRecipientCount )"
    Write-Log -message "Started: $( $mailingStartedDate )"
    Write-Log -message "Finished: $( $mailingFinishedDate )"

    # return values
    $recipients = $sentRecipientCount
    $transactionId = $mailingId

} else {

    Write-Log -message "Using async process and will ask for a mailing id and stats later"

    # using async process and set this to null firsthand
    $transactionId = 0
    $recipients = 0

}



################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

Write-Host "Broadcast for $( $recipients ) records with mailing id $( $transactionId )"

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$settings.providername
}

# return the results
$return

