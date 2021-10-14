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

    try {

        <#
        https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings
        #>
        $mailings = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailing" -Headers $header -Verbose -ContentType $contentType

    } catch {

        Write-Log -message "StatusCode: $( $_.Exception.Response.StatusCode.value__ )" -severity ( [LogSeverity]::ERROR )
        Write-Log -message "StatusDescription: $( $_.Exception.Response.StatusDescription )" -severity ( [LogSeverity]::ERROR )

        throw $_.Exception

    }

    #-----------------------------------------------
    # LOOK AT SFTP ARCHIVE AND DELETE OLDER ONES AFTER X DAYS
    #-----------------------------------------------

    

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
    
                # Put the file using PutFiles Method accross to SFTP Server with the $transferOptions: binary
                $transferResult = $session.PutFiles($newPath, "/import/", $false, $transferOptions)
                $transferResult.Check()
                If ( $transferResult.IsSuccess ) {
                    Write-Log -message "File for import uploaded successfully to SFTP"
                }

                # Put the same file also in the archive
                If ( $settings.upload.archiveImportFile ) {
                    $transferResult = $session.PutFiles($newPath, "/archive/", $false, $transferOptions)
                    $transferResult.Check()
                    If ( $transferResult.IsSuccess ) {
                        Write-Log -message "File for archive uploaded successfully to SFTP"
                    }
                }
    
                # Write to the console and the log whether the file transfer was successful    
                Write-Log -message "Upload of $( $transferResult.Transfers.FileName ) to $( $transferResult.Transfers.Destination ) succeeded"

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






