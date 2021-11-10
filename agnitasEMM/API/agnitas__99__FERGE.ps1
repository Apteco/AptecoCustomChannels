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
	    scriptPath= "D:\Scripts\AgnitasEMM"
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
$script:modulename = "LOADRESPONSE"

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
# PROCESS
#
################################################

try {

    ################################################
    #
    # TRY
    #
    ################################################

    #-----------------------------------------------
    # GET MAILINGS AND DELETE OLDER ONES AFTER X DAYS
    #-----------------------------------------------

    If ( $settings.response.cleanupMailings ) {

        Write-Log -message "Starting with mailings cleanup older than $( $settings.response.maxAgeMailings ) days"

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
    
        # Filtering the mailings by a string
        $copyString = $settings.messages.copyString
        $mailings | where { $_.name -like "*$( $copyString )*" } | ForEach {
    
            $mailing = $_
            
            Write-Log -message "Checking mailing '$( $mailing.mailing_id )' - '$( $mailing.name )'"

            # Extracting the date of the name
            $mailingNameParts = $mailing.name -split $copyString,2,"simplematch"
            $mailingCreationDate = [Datetime]::ParseExact($mailingNameParts[1].Trim(),$settings.timestampFormat,$null)
            $age = New-TimeSpan -Start $timestamp -End $mailingCreationDate
    
            # Delete if older than
            If ( $age.TotalDays -lt $settings.response.maxAgeMailings ) {
                
                Write-Log -message "Deleting mailing '$( $mailing.mailing_id )' - '$( $mailing.name )'"
                $restParams = @{
                    Method = "Delete"
                    Uri = "$( $apiRoot )/mailing/$( $mailing.mailing_id )"
                    Headers = $header
                    Verbose = $true
                    ContentType = $contentType
                }
                Check-Proxy -invokeParams $restParams
                $mailing = Invoke-RestMethod @restParams

            }
    
        }

    }


    #-----------------------------------------------
    # PREPARE SFTP SESSION
    #-----------------------------------------------

    #LOOK AT SFTP ARCHIVE AND DELETE OLDER ONES AFTER X DAYS

    # Load WinSCP .NET assembly
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [winSCP.Protocol]::Sftp
        HostName = $settings.sftpSession.HostName
        Username = $settings.sftpSession.Username
        Password = Get-SecureToPlaintext -String $settings.sftpSession.Password
        SshHostKeyFingerprint = $settings.sftpSession.SshHostKeyFingerprint
    }

    # Add raw settings, e.g. for proxy
    $settings.sftpSession.raw.Keys | ForEach {
        $key = $_
        $value = $settings.sftpSession.raw.$key
        $sessionOptions.AddRawSettings($key, $value)
    }

    $winscpExe = ( $libExecutables | where { $_.Name -eq "WinSCP.exe" } | select -first 1 ).fullname


    #-----------------------------------------------
    # CLEANUP AND DOWNLOAD ON SFTP
    #-----------------------------------------------

    # Load the Assembly and setup the session properties
    try {

        # This Object will connect to the SFTP Server
        $session = [WinSCP.Session]::new()
        $session.ExecutablePath = $winscpExe
        $session.DebugLogPath = "$( $settings.winscplogfile )"

        # Connect and send files, then close session
        try {

            # Connect
            $session.Open($sessionOptions)

            If ( $session.Opened ) {

                Write-Log -message "Session to SFTP openend successfully"

                # TransferOptions set to Binary
                $transferOptions = [WinSCP.TransferOptions]::new()
                $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
                
                If ( $settings.response.cleanupSFTPArchive ) {

                    Write-Log -message "Cleaning up archive folder $( $settings.upload.archiveFolder )"

                    # Check if archive folder exists
                    $rootDir = $session.ListDirectory("/")
                    $archiveFolder = $rootDir.Files | where { $_.IsDirectory -eq $true -and $_.FullName -eq $settings.upload.archiveFolder }
                    
                    If ( $archiveFolder.count -eq 1 ) {

                        # Load content of archive folder
                        $archiveFiles = $session.ListDirectory( $archiveFolder.FullName )

                        # Check date and delete it if older than n days
                        $archiveFiles.Files | where { $_.IsDirectory -eq $false } | ForEach {

                            $file = $_
                            $age = New-TimeSpan -Start $timestamp -End $file.LastWriteTime

                            # Delete if older than
                            If ( $age.TotalDays -lt -7 ) {
                                Write-Log -message "Deleting archived file '$( $file.FullName )'"
                                $filename = [WinSCP.RemotePath]::EscapeFileMask($file.FullName)
                                $removalResult = $session.RemoveFile($filename)
                                #$session.RemoveFile($file.FullName)
                            }

                        }
                            
                    }

                }

                Write-Log -message "Synching of reponse files"

                # TODO [ ] put the path and foldername to settings
                $synchronizationResult = $session.SynchronizeDirectories([WinSCP.SynchronizationMode]::Local, "$( $settings.response.exportDirectory )", $settings.response.exportFolder, $False)

                # Example part of https://winscp.net/eng/docs/library_example_delete_after_successful_download
                $archiveFolder = "$( $settings.upload.archiveFolder )/"
                foreach ($download in $synchronizationResult.Downloads) {

                    # Success or error?
                    if ($download.Error -eq $Null) {
                        Write-Host "Download of $($download.FileName) succeeded, removing from source"
                        # Download succeeded, remove file from source
                        $filename = [WinSCP.RemotePath]::EscapeFileMask($download.FileName)
                        $moveResult = $session.MoveFile($filename, $archiveFolder)
                        #$removalResult = $session.RemoveFiles($filename)
         
                        if ($moveResult.IsSuccess) {
                            Write-Log "Moving of file '$($download.FileName)'' to '$( $archiveFolder )'' succeeded"
                        } else {
                            Write-Log -message "Moving of file '$($download.FileName)'' failed" -severity ( [Logseverity]::WARNING )
                        }
                    } else {
                        Write-Log -message ("Download of $($download.FileName) failed: $($download.Error.Message)") -severity ( [Logseverity]::WARNING )
                    }

                }

            } else {

                $msg = "Connection to SFTP failed"
                Write-Log -message $msg -severity ( [Logseverity]::ERROR )
                throw [System.IO.InvalidDataException] $msg
                
            }
        
        } catch {

            Write-Log -message "There was a problem during the upload to SFTP" -severity ([LogSeverity]::ERROR)
            throw $_.exception
          
        } finally {
            # Disconnect, clean up
            $session.Dispose()
        }
        
    # Catch em errors
    } catch {

        #Write-Host "Error: $( $_ )" #.Exception.Message )"
        throw $_.exception

    }


    #-----------------------------------------------
    # TRANSFORM FILES
    #-----------------------------------------------

    $csvFiles = @( Get-Childitem -path "$( $settings.response.exportDirectory )" -Filter "*.csv" )
    Write-Log "$( $csvFiles.count ) csv files to process"

    $sentsFile = "$( $settings.response.exportDirectory )\$( $timestamp.toString("yyyyMMddHHmmss") )_FERGE_sents.csv"
    $opensFile = "$( $settings.response.exportDirectory )\$( $timestamp.toString("yyyyMMddHHmmss") )_FERGE_opens.csv"
    $clicksFile = "$( $settings.response.exportDirectory )\$( $timestamp.toString("yyyyMMddHHmmss") )_FERGE_clicks.csv"
    $bouncesFile = "$( $settings.response.exportDirectory )\$( $timestamp.toString("yyyyMMddHHmmss") )_FERGE_bounces.csv"
    $unsubsFile = "$( $settings.response.exportDirectory )\$( $timestamp.toString("yyyyMMddHHmmss") )_FERGE_unsubscribes.csv" 

    $csvFiles | ForEach {

        $csvFile = $_
        Write-Log "Parsing '$( $csvFile.Name )'"

        $csv = @( Import-Csv -path $csvFile.FullName -delimiter ";" -Encoding UTF8 )

        Write-Log "  $( $csv.count ) records"

        If ( $csv.count -eq 0 ) {
            
            Write-Log "  Removing file directly" # TODO [ ] maybe put this to the end
            Remove-Item -path $csvFile.FullName -force

        } else {

            # 4 = SENT
            $sents = @( $csv | where { $_.EVENT -eq 4 } )
            $sents | select *, @{name="MessageType"; expression={ "Send" }} | Export-Csv -Path $sentsFile -delimiter "`t" -encoding UTF8 -NoTypeInformation -append #-Verbose
            Write-Log "  $( $sents.count ) sents"

            # 2 = OPEN
            $opens = @( $csv | where { $_.EVENT -eq 2 } )
            $opens | select *, @{name="MessageType"; expression={ "Open" }} | Export-Csv -Path $opensFile -delimiter "`t" -encoding UTF8 -NoTypeInformation -append #-Verbose
            Write-Log "  $( $opens.count ) opens"
<#
            # X = CLICK
            $clicks = @( $csv | where { $_.EVENT -eq 0 } )
            $clicks | select *, @{name="MessageType"; expression={ "Click" }} | Export-Csv -Path $clicksFile -delimiter "`t" -encoding UTF8 -NoTypeInformation -append #-Verbose
            Write-Log "  $( $clicks.count ) clicks"

            # X = BOUNCE
            $bounces = @( $csv | where { $_.EVENT -eq 0 } )
            $bounces | select *, @{name="MessageType"; expression={ "Bounce" }} | Export-Csv -Path $bouncesFile -delimiter "`t" -encoding UTF8 -NoTypeInformation -append #-Verbose
            Write-Log "  $( $bounces.count ) bounces"

            # X = UNSUBSCRIPTION
            $unsubs = @( $csv | where { $_.EVENT -eq 0 } )
            $unsubs | select *, @{name="MessageType"; expression={ "Unsubscription" }} | Export-Csv -Path $unsubsFile -delimiter "`t" -encoding UTF8 -NoTypeInformation -append #-Verbose
            Write-Log "  $( $unsubs.count ) unsubscribes"
            #>

            Write-Log "  Removing file after parsing" # TODO [ ] maybe put this to the end
            Remove-Item -path $csvFile.FullName -force

        }

    }

    #exit 0
    
    #-----------------------------------------------
    # UPDATE BROADCASTS IN RESPONSE DATABASE
    #-----------------------------------------------

    #CustomProvider=AGNITAS-BROADCAST
    
    #-----------------------------------------------
    # LOAD BROADCAST DETAILS
    #----------------------------------------------- 
<#
    # prepare query
    # TODO [ ] put this file maybe into settings
    $selectBroadcastsSQL = Get-Content -Path ".\sql\update_broadcast_details_provider.sql" -Encoding UTF8
    $selectBroadcastsSQL = $selectBroadcastsSQL -replace "#PROVIDER#", $settings.providername

    # load data
    $broadcastsDetailDataTable = Query-SQLServer -connectionString "$( $mssqlConnectionString )" -query "$( $selectBroadcastsSQL )"


    
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
#>
    #-----------------------------------------------
    # NEXT STEP - TRIGGER FERGE LOCALLY
    #-----------------------------------------------
    
    # Possibly change the broadcaster to GenericFTP
    #"C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseConfig.exe"
    #"C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"
    #Start-Process -FilePath "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"

    $fergeCsvFiles = @( Get-Childitem -path "$( $settings.response.exportDirectory )" -Filter "*_FERGE_*.csv" )

    Write-Log -message "Found '$( $fergeCsvFiles.count )' files to process with FERGE"

    if ( $settings.response.triggerFerge -and $fergeCsvFiles.count -gt 0 ) {

        # Find FERGE with PATH
        try {
            $ferge = Get-Command -Name "EmailResponseGatherer64"
    
        } catch {
            Write-Log -message "EmailResponseGatherer64.exe is not added to PATH yet. Please make sure it can be used" -severity ( [LogSeverity]::ERROR )
            throw $_.exception
        }
    
        # Trigger FERGE and wait for completion
        Write-Log -message "Trigger FERGE"
        $timeForImport = Measure-Command {
            # TODO [ ] put the xml path into settings
            Start-Process -FilePath $ferge.Source -ArgumentList @("D:\Scripts\AgnitasEMM\ferge.xml") -nonewwindow
        }
        Write-Log -message "FERGE done in $( $timeForImport.TotalSeconds ) seconds"
    
    }
    

    #-----------------------------------------------
    # ASK TO CREATE A SCHEDULED TASK
    #-----------------------------------------------

    If ( $debug ) {
        # TODO [ ] Check this one
        #. ".\bin\create_scheduled_task.ps1"
    }



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

    #$messages

}






