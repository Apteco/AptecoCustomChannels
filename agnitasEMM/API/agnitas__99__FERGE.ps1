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
<#
    If ( $settings.response.cleanupMailings ) {

        Write-Log -message "Starting with mailings cleanup older than $( $settings.response.maxAgeMailings ) days"

        try {

            $mailings = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailing" -Headers $header -Verbose -ContentType $contentType
    
        } catch {
    
            Write-Log -message "StatusCode: $( $_.Exception.Response.StatusCode.value__ )" -severity ( [LogSeverity]::ERROR )
            Write-Log -message "StatusDescription: $( $_.Exception.Response.StatusDescription )" -severity ( [LogSeverity]::ERROR )
    
            throw $_.Exception
    
        }
    
        # Filtering the mailings by a string
        $copyString = $settings.messages.copyString
        $mailings | where { $_.name -like "*$( $copyString )*" } | ForEach {
    
            $mailing = $_
    
            # Extracting the date of the name
            $mailingNameParts = $mailing.name -split $copyString,2,"simplematch"
            $mailingCreationDate = [Datetime]::ParseExact($mailingNameParts[1],$settings.timestampFormat,$null)
            $age = New-TimeSpan -Start $timestamp -End $mailingCreationDate
    
            # Delete if older than
            If ( $age.TotalDays -lt $settings.response.maxAgeMailings ) {
                Write-Log -message "Deleting mailing '$( $mailing.mailing_id )' - '$( $mailing.name )'"
                $mailings = Invoke-RestMethod -Method Delete -Uri "$( $apiRoot )/mailing/$( $mailing.mailing_id )" -Headers $header -Verbose -ContentType $contentType
            }
    
        }

    }
#>

    #-----------------------------------------------
    # CLEANUP AND DOWNLOAD ON SFTP
    #-----------------------------------------------

    #LOOK AT SFTP ARCHIVE AND DELETE OLDER ONES AFTER X DAYS

    # Load the Assembly and setup the session properties
    try {

        # Load WinSCP .NET assembly
        # Setup session options
        $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
            Protocol = [winSCP.Protocol]::Sftp
            HostName = $settings.sftpSession.HostName
            Username = $settings.sftpSession.Username
            Password = Get-SecureToPlaintext -String $settings.sftpSession.Password
            SshHostKeyFingerprint = $settings.sftpSession.SshHostKeyFingerprint
        }

        # This Object will connect to the SFTP Server
        $session = [WinSCP.Session]::new()
        $session.ExecutablePath = ( $libExecutables | where { $_.Name -eq "WinSCP.exe" } | select -first 1 ).fullname

        # Connect and send files, then close session
        try {

            # Connect
            $session.DebugLogPath = "$( $settings.winscplogfile )"
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
                foreach ($download in $synchronizationResult.Downloads) {

                    # Success or error?
                    if ($download.Error -eq $Null) {
                        Write-Host "Download of $($download.FileName) succeeded, removing from source"
                        # Download succeeded, remove file from source
                        $filename = [WinSCP.RemotePath]::EscapeFileMask($download.FileName)
                        $removalResult = $session.RemoveFiles($filename)
         
                        if ($removalResult.IsSuccess) {
                            Write-Log "Removing of file $($download.FileName) succeeded"
                        } else {
                            Write-Log -message "Removing of file $($download.FileName) failed" -severity ( [Logseverity]::WARNING )
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
    # NEXT STEP - TRIGGER FERGE TO IMPORT RESPONSES
    #-----------------------------------------------

    #Start-Process -FilePath "C:\Program Files\Apteco\FastStats Email Response Gatherer x64\EmailResponseGatherer64.exe"

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






