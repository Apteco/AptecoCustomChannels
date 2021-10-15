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
        TransactionType = 'Replace'
        Password = 'ko'
        scriptPath = 'D:\Scripts\AgnitasEMM'
        MessageName = ''
        EmailFieldName = 'email'
        SmsFieldName = ''
        Path = 'd:\faststats\Publish\Handel\system\Deliveries\PowerShell_772923  Sushi_134e9c15-724b-439b-8a53-b71af92b4fe2.txt'
        ReplyToEmail = ''
        Username = 'ko'
        ReplyToSMS = ''
        UrnFieldName = 'Kunden ID'
        ListName = '772923 | Sushi'
        CommunicationKeyFieldName = 'Communication Key'
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

$script:moduleName = "AGNITAS-UPLOAD-MAILING"

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


    #-------------------------------------------------------------------
    # STEP 1: Add Process Id Column to $params.Path
    #-------------------------------------------------------------------

    $dataCsv = @( Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 )

    # Add send_id column to recipient csv file
    $send_id = $processId
    $dataCsv | Add-Member -MemberType NoteProperty -Name "send_id" -Value $send_id

    # Add timestamp to uploaded csv-file
    $importFile = Get-Item -Path "$( $params.Path )"
    $timestampFormatted = $timestamp.toString( $settings.timestampFormat ) #get-date -f yyyy-MM-dd--HH-mm-ss

    $newPath  = "$( $importFile.DirectoryName )\$( $importFile.BaseName )$( $timestampFormatted )$( $importFile.Extension )"

    $dataCsv | Export-Csv -Path $newPath -Delimiter "`t" -NoTypeInformation


    #-------------------------------------------------------------------
    # STEP 2: WinSCP - Upload PeopleStage Recipients into SFTP Server
    #-------------------------------------------------------------------

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
                $transferResult = $session.PutFiles($newPath, "$( $settings.upload.uploadFolder )", $false, $transferOptions)
                $transferResult.Check()
                If ( $transferResult.IsSuccess ) {
                    Write-Log -message "File for import uploaded successfully to SFTP"
                }

                # Put the same file also in the archive
                If ( $settings.upload.archiveImportFile ) {
                    $transferResult = $session.PutFiles($newPath, "$( $settings.upload.archiveFolder )", $false, $transferOptions)
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


    #--------------------------------------------------------
    # STEP 3: Compare Fields as a log entry
    #-------------------------------------------------------- 
    <#
        https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailinglist-mailinglistMailinglistIdRecipientsGet
    #>

    # Get fields from EMM
    $mailinglistRecipients = Invoke-RestMethod -Method Get -Uri "$( $apiRoot )/mailinglist/$( $settings.upload.standardMailingList )/recipients" -Headers $header -ContentType $contentType -Verbose
    
    # Reading the columns of Agnitas EMM only works if you have one receiver as minimum
    if ( $mailinglistRecipients.recipients.count -gt 0 ) {

        # Get properties/fields from agnitas
        $agnitasFields = ( $mailinglistRecipients.recipients | Get-Member -MemberType NoteProperty ).Name

        # Get fields from PeopleStage
        $csvColumns = ( $dataCsv | Get-Member -MemberType NoteProperty ).Name
    
        $fieldComparation = Compare-Object -ReferenceObject $agnitasFields -DifferenceObject $csvColumns -IncludeEqual
        $equalColumns = ( $fieldComparation | where { $_.SideIndicator -eq "==" } ).InputObject
        $columnsOnlyCsv = ( $fieldComparation | where { $_.SideIndicator -eq "=>" } ).InputObject
        $columnsOnlyEMM = ( $fieldComparation | where { $_.SideIndicator -eq "<=" } ).InputObject
    
        Write-Log -message "Equal columns: $( $equalColumns -join ", " )"
        Write-Log -message "Columns only CSV: $( $columnsOnlyCsv -join ", " )"
        Write-Log -message "Columns only EMM: $( $columnsOnlyEMM -join ", " )"

    } else {

        Write-Log -message "No receiver in Agnitas EMM avaible yet to read the available columns" -severity ( [LogSeverity]::WARNING )

    }



    #---------------------------------------------------------
    # STEP 4: Check if slot for auto import is free
    #---------------------------------------------------------


    If ( Test-Path -Path $settings.broadcast.lockfile ) {

        $lockfile = Get-Item -Path "$( $settings.broadcast.lockfile )"
        $lockfileAge = New-TimeSpan -Start $lockfile.CreationTime -End Get-Date
        If ( $lockfileAge.TotalSeconds -gt $settings.broadcast.maxLockfileAge ) {
            Remove-Item -Path $settings.broadcast.lockfile -Force
        }

        # Wait for the next slot
        Write-Log -message "Polling for lockfile, if present"
        $outArgs = @{
            Path = $settings.broadcast.lockfile
            fireExceptionIfUsed = $true
        }
        Retry-Command -Command 'Is-PathFree' -Args $outArgs -retries $settings.broadcast.lockfileRetries -MillisecondsDelay $settings.broadcast.lockfileDelayWhileWaiting
        Write-Log -message "Upload slot is free now, no lockfile present anymore"

    }


    #---------------------------------------------------------
    # STEP 5: Trigger Autoimport - REST
    #---------------------------------------------------------

    $autoimport_id = $settings.upload.autoImportId # API-Auto-Import Id in Agnitas EMM
    $c = 0 # time counter

    $endpoint = "$( $apiRoot )/autoimport/$( $autoimport_id )"
    $invokePost = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $header -ContentType $contentType -Verbose

    # Checking whether the Autoimport has finished uploading the recipients into Agnitas
    # TODO [ ] Implement timeout mechanism
    $sleepTime = $settings.upload.sleepTime
    $maxWaitTimeTotal = $settings.upload.maxSecondsWaiting
    $startTime = Get-Date
    Do {
        Start-Sleep -Seconds $sleepTime
        Write-Log -message "Looking for the status of auto import $( $autoimport_id ) - last status: '$( $status.status )' - waiting already for '$( $timespan.TotalSeconds + $sleepTime )' seconds"
        $status = Invoke-RestMethod -Uri $endpoint -Method Get -Headers $header -Verbose -ContentType $contentType
        $timespan = New-TimeSpan -Start $startTime
    } while ( $status.status -in @("running") -and $timespan.TotalSeconds -lt $maxWaitTimeTotal)

    <#
    do{
        $invokeGet = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -ContentType $contentType -Verbose
        Write-Log -message $invokeGet.status
        
        if($invokeGet.status -ne "running"){
            break
        }
        
        Start-Sleep -Seconds 2
        $c += 2
        Write-Log -message "Loading Upload - waited for $( $c ) seconds"
        
    } while ( $invokeGet.status -eq "running" -and $c -lt 100 )
    #>
    Write-Log -message "Finished auto import with id '$( $status.auto_import_id )'"
    Write-Log -message "  Status: $( $status.status )"
    Write-Log -message "  Started: $( $status.started )"
    Write-Log -message "  Last Result: $( $status.last_result )"

    If ( $status.last_result -eq "OK" ) {
        Write-Log -message "Upload successfully finished"
    } else {
        $msg = "Auto Import in EMM failed"
        Write-Log -message $msg -severity ( [Logseverity]::ERROR )
        throw [System.IO.InvalidDataException] $msg
    }


    #-----------------------------------------------
    # STEP 6: BUILD TARGETGROUPS OBJECTS - SOAP
    #-----------------------------------------------
    # This is targetGroup where the recipients will be in

    # Load existing targetgroups
    . ".\bin\load_targetGroups.ps1"
    # Use $targetGroups now

    # No targetgroup chosen? Choose the oldest one
    #if (( $params.ListName -eq "" ) -or ( $null -eq $params.ListName ) -or ( $params.MessageName -eq $params.ListName )) {
        
    if ( ( $params.MessageName -eq $params.ListName ) -or (( $params.MessageName -ne $params.ListName ) -and ( $params.MessageName -eq "" )) ) {

        # Choose the oldest one by name and then ID
        $targetGroup = $aptecoTargetgroups | sort { $_.targetGroupName, $_.targetGroupId } | Select -first 1

    # else use the chosen one
    } else {

        # Parse targetgroup
        $targetGroup = [TargetGroup]::new( $params.ListName )
        
        # Check if the targetgroup exists
        If ( $targetGroups.targetGroupId -notcontains $targetGroup.targetGroupId ) {

            throw [System.IO.InvalidDataException] "The targetgroup does not exist"

        }

    }

    Write-Log -message "Using targetgroup '$( $targetGroup.targetGroupId )'"

    # Update target groups name and definition
    $targetGroupname = "$( $settings.upload.targetGroupPrefix )$( $timestamp.toString( $settings.timestampFormat ) )"
    Write-Log -message "Updating targetgroup to name '$( $targetGroupname )' and change definition to use the send id '$( $send_id.guid )'"
    $params = [Hashtable]@{
        method = "UpdateTargetGroup"
        param = [Hashtable]@{
            targetID = [Hashtable]@{
                type = "int"
                value = $targetGroup.targetGroupId
            }
            targetName = [Hashtable]@{
                type = "string"
                value = $targetGroupname
            }
            eql = [Hashtable]@{
                type = "string"
                value = "send_id = '$( $send_id.guid )'"
            }
        }
        noresponse = $true
        namespace = "http://agnitas.com/ws/schemas"
        #verboseCall = $true
    }
    Invoke-Agnitas @params
    
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

    #-----------------------------------------------
    # RETURN VALUES TO PEOPLESTAGE
    #-----------------------------------------------
    
    # count the number of successful upload rows
    $recipients = $dataCsv.Count
    
    # put in the source id as the listname
    $transactionId = $targetGroup.targetGroupId
    
    # return object
    $return = [Hashtable]@{
    
         # Mandatory return values
         "Recipients"=$recipients
         "TransactionId"=$transactionId
    
         # General return value to identify this custom channel in the broadcasts detail tables
         "CustomProvider"=$moduleName
         "ProcessId" = $processId
    
         # Some more information for the broadcasts script
         #"EmailFieldName"= $params.EmailFieldName
         #"Path"= $params.Path
         #"UrnFieldName"= $params.UrnFieldName
         "TargetGroupId" = $targetGroup.targetGroupId
    
         # More information about the different status of the import
         #"RecipientsIgnored" = $status.report.total_ignored
         "RecipientsQueued" = $recipients
         #"RecipientsSent" = $status.report.total_added + $status.report.total_updated
    
    }
    
    # return the results
    $return

}



