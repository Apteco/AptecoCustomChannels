################################################
#
# INPUT
#
################################################

#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true


################################################
#
# NOTES
#
################################################

<#

TODO [ ] implement more logging

#>

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
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

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# more settings
$logfile = $settings.logfile

# queries
$selectBroadcastsSQLFile = ".\sql\epi__81__broadcasts_to_update.sql"
$updateBroadcastsSQLFile = ".\sql\epi__82__update_broadcasts.sql"
$updateBroadcasts2SQLFile = ".\sql\epi__83__update_broadcasts_part2.sql"

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}

# custom settings
# TODO [ ] find another way for this connection string
$mssqlConnectionString = "<rsdbconnectionstring>"



################################################
#
# FUNCTIONS
#
################################################

# Add assemblies
Add-Type -AssemblyName System.Data

# Add external assemblies -> only an example!
#$assemblyWinSCP = [System.Reflection.Assembly]::LoadFile( (Get-ChildItem -Path $scriptPath -Recurse -Filter "WinSCPnet.dll" | Select -First 1).FullName )

# Load all functions in subfolder
Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}

# TODO [ ] put this function in an extra powershell source


################################################
#
# LOG INPUT PARAMETERS
#
################################################

Write-Log -message "----------------------------------------------------"
Write-Log -message "FERGE"


################################################
#
# PROGRAM
#
################################################

# Decrypt response config files first, if needed

if ( $settings.response.decryptConfig ) {

}

# Asynchronous process to update all broadcasts without a valid mailingid
if ( $settings.syncType -eq "async" ) {

    #-----------------------------------------------
    # LOAD RESPONSE DB METADATA
    #----------------------------------------------- 

    # load connection string
    #$configXml = [xml] (Get-Content $settings.response.responseConfig -Encoding UTF8)
    #$mssqlConnectionString = $configXml.configuration.appSettings.add.Where({ $_.key -eq "db_connection_digitalresponse" }).value

    # TODO [ ] implement the rest to load the data first from sqlserver and put into a datatable
    # TODO [ ] implement decryption of connection string, if needed
    

    #-----------------------------------------------
    # LOAD BROADCAST DETAILS
    #----------------------------------------------- 

    # prepare query
    $selectBroadcastsSQL = Get-Content -Path "$( $selectBroadcastsSQLFile )" -Encoding UTF8
    $selectBroadcastsSQL = $selectBroadcastsSQL -replace "#PROVIDER#", $settings.providername

    # load data
    $broadcastsDetailDataTable = Query-SQLServer -connectionString "$( $mssqlConnectionString )" -query "$( $selectBroadcastsSQL )"

    #-----------------------------------------------
    # GET CURRENT SESSION OR CREATE A NEW ONE
    #-----------------------------------------------

    Get-EpiSession


    #-----------------------------------------------
    # LOAD MAILING ID FROM EPI AND UPDATE BROADCAST
    #----------------------------------------------- 

    # loop over result from previous query with column BroadcasterTransactionId
    $result = 0
    $broadcastsDetailDataTable | ForEach {
        
        $waveId = $_.BroadcasterTransactionId
        $broadcastId = $_.BroadcastId

        #-----------------------------------------------
        # LOAD MAILING ID FROM EPI
        #----------------------------------------------- 
        
        # this returns us the id of the classic mailing or smart campaign
        $mailingId = Invoke-Epi -webservice "ClosedLoop" -method "getMailingIdByWaveId" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true
        #$mailingId = '292100521182'

        #-----------------------------------------------
        # LOAD STATUS AND AMOUNT OF RECEIVERS
        #----------------------------------------------- 

        if ( $mailingId -ne 0 ) {
            $mailingStatus = Invoke-Epi -webservice "Mailing" -method "getStatus" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true

            # TODO [ ] do something with the status CANCELLED?

            if ( $mailingStatus -eq 'DONE' ) {

                # Load more metadata about mailing
                $overallRecipientCount = Invoke-Epi -webservice "Mailing" -method "getOverallRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
                $failedRecipientCount = Invoke-Epi -webservice "Mailing" -method "getFailedRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
                $sentRecipientCount = Invoke-Epi -webservice "Mailing" -method "getSentRecipientCount" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
                $mailingStartedDate = Invoke-Epi -webservice "Mailing" -method "getSendingStartedDate" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true
                $mailingFinishedDate = Invoke-Epi -webservice "Mailing" -method "getSendingFinishedDate" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true

                # TODO [ ] put this information into a separate object and export it as a file

                #-----------------------------------------------
                # UPDATE BROADCAST DETAILS
                #----------------------------------------------- 

                # prepare query
                $updateBroadcastsSQL = Get-Content -Path "$( $updateBroadcastsSQLFile )" -Encoding UTF8
                $updateBroadcastsSQL = $updateBroadcastsSQL -replace "#MAILINGID#", $mailingId
                $updateBroadcastsSQL = $updateBroadcastsSQL -replace "#BROADCASTID#", $broadcastId
                $updateBroadcastsSQL = $updateBroadcastsSQL -replace "#UPLOADED#", $overallRecipientCount
                $updateBroadcastsSQL = $updateBroadcastsSQL -replace "#REJECTED#", $failedRecipientCount
                $updateBroadcastsSQL = $updateBroadcastsSQL -replace "#BROADCAST#", $sentRecipientCount

                # execute query
                $result += NonQuery-SQLServer -connectionString "$( $mssqlConnectionString )" -command "$( $updateBroadcastsSQL )"

                #-----------------------------------------------
                # UPDATE BROADCAST - this allows FERGE to load the response data automatically
                #----------------------------------------------- 

                # prepare query
                $updateBroadcasts2SQL = Get-Content -Path "$( $updateBroadcasts2SQLFile )" -Encoding UTF8
                $updateBroadcasts2SQL = $updateBroadcasts2SQL -replace "#BROADCASTID#", $broadcastId

                # execute query
                NonQuery-SQLServer -connectionString "$( $mssqlConnectionString )" -command "$( $updateBroadcasts2SQL )"

            }

        }

    }   

    # log after loop
    Write-Log -message "Updatet $( $result ) rows in Broadcasts for Mailings $( $mailingsToTransform -join ',' )"


}


################################################
#
# TRIGGER FERGE 
#
################################################

if ( $settings.response.triggerFerge ) {

    # TODO [ ] check this part
    Write-Log -message "Trigger FERGE"
    $timeForDownload = Measure-Command {
        "Return Responses"
        [datetime]::Now.ToString("yyyyMMdd HHmmss") #>> $logfile
        EmailResponseGatherer64 "$( $settings.response.responseConfig )" #
    }
    Write-Log -message "FERGE done in $( $timeForDownload.Seconds ) seconds"

}


