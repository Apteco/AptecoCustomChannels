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

        # From Upload Script
        #TargetGroupId = "12345"

        ProcessId = '05679889-78ad-4d02-aa81-badedc44cdc6'
        MessageName = '773320 | Skate'
        Username = 'ko'
        RecipientsQueued = '5'
        TransactionId = '54464'
        CustomProvider = 'AGNITAS-UPLOAD-MAILING'
        Password = 'ko'
        ListName = '773320 | Skate'
        TargetGroupId = '54464'
        scriptPath = 'D:\Scripts\AgnitasEMM'
                

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

$script:moduleName = "AGNITAS-BROADCAST"

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

    try {

        #-----------------------------------------------
        # STEP 1: Creating upload+broadcast slot
        #-----------------------------------------------


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

        # Write lock file for now
        $processId.Guid | Set-Content -Path $settings.broadcast.lockfile -Verbose -Force -Encoding UTF8
        Write-Log -message "Creating own lockfile now at '$( $settings.broadcast.lockfile )'"


        #-----------------------------------------------
        # STEP 2: Check if Mailing is valid
        #-----------------------------------------------
        
        $mailingParsed = [Mailing]::new($params.MessageName)
        $invokeParams = [Hashtable]@{
            Method = "Get"
            Uri = "$( $apiRoot )/mailing/$( [int]$mailingParsed.mailingId )"
            Headers = $header
            Verbose = $true
            ContentType = $contentType
        }
        $mailing = Invoke-RestMethod @invokeParams


        #-----------------------------------------------
        # STEP 3: Copy Mailing - SOAP
        #-----------------------------------------------

        $invokeParams = [Hashtable]@{
            method = "CopyMailing"
            verboseCall = $false
            namespace = "http://agnitas.com/ws/schemas"
            param = [Hashtable]@{
                mailingId = [Hashtable]@{
                    type = "int"
                    value = [int]$mailing.id
                }
                nameOfCopy = [Hashtable]@{
                    type = "string"
                    value = "$( $mailing.shortname ) $( $settings.messages.copyString ) $( $timestamp.toString($settings.timestampFormat) )"
                }
                descriptionOfCopy = [Hashtable]@{
                    type = "string"
                    value = "Beschreibung der Kopie"
                }
            }
        }

        # ! CopyMailing returns the mailingId of the copied mailing
        $copyMailing = Invoke-Agnitas @invokeParams #-method "CopyMailing" -param $param -verboseCall -namespace $namespace #-wsse $wsse -noresponse 


        #---------------------------------------------------------------------
        # STEP 4: Get copied Mailing Details - SOAP
        #---------------------------------------------------------------------

        $mailingId = [int]$copyMailing.copyId.value

        $invokeParams = [Hashtable]@{
            method = "GetMailing"
            verboseCall = $false
            namespace = "http://agnitas.org/ws/schemas"
            param = [Hashtable]@{
                mailingID = [Hashtable]@{
                    type = "int"
                    value = $mailingId
                }
            }
        }

        $getMailing = Invoke-Agnitas @invokeParams #-method "GetMailing" -param $param -verboseCall -namespace $namespace #-wsse $wsse -noresponse 


        #--------------------------------------------------------------------------
        # STEP 5: Update Mailing - Connect TargetList with copied mailing - SOAP
        #--------------------------------------------------------------------------

        $invokeParams = [hashtable]@{
            method = "UpdateMailing"
            verboseCall = $true
            namespace = "http://agnitas.org/ws/schemas"
            noresponse = $true
            param = [ordered]@{
                mailingID = [Hashtable]@{
                    type = "int"
                    value = [int]$getMailing.mailingID
                }
                shortname = [Hashtable]@{
                    type = "string"
                    value = $getMailing.shortname
                }
                description = [Hashtable]@{
                    type = "string"
                    value = $getMailing.description
                }
                mailinglistID = [Hashtable]@{
                    type = "int"
                    value = $settings.upload.standardMailingList # use the standard import list, connected to auto import job
                }
                targetIDList = [Hashtable]@{
                    type = "element"
                    value = @( [int]$params.TargetGroupId )
                    subtype = "targetID"
                }
                matchTargetGroups = [Hashtable]@{
                    type = "string"
                    value = "all"
                }
                mailingType = [Hashtable]@{
                    type = "string"
                    value = $getMailing.mailingType
                }
                subject = [Hashtable]@{
                    type = "string"
                    value = $getMailing.subject
                }
                senderName = [Hashtable]@{
                    type = "string"
                    value = $getMailing.senderName
                }
                senderAddress = [Hashtable]@{
                    type = "string"
                    value = $getMailing.senderAddress
                }
                replyToName = [Hashtable]@{
                    type = "string"
                    value = $getMailing.replyToName
                }
                replyToAddress = [Hashtable]@{
                    type = "string"
                    value = $getMailing.replyToAddress
                }
                charset = [Hashtable]@{
                    type = "string"
                    value = $getMailing.charset
                }
                linefeed = [Hashtable]@{
                    type = "int"
                    value = [int]$getMailing.linefeed
                }
                format = [Hashtable]@{
                    type = "string"
                    value = "offline-html"
                }
                onePixel = [Hashtable]@{
                    type = "string"
                    value = $getMailing.onePixel
                }
            }
        }

        Invoke-Agnitas @invokeParams #-method "UpdateMailing" -param $param -namespace "http://agnitas.org/ws/schemas" -noresponse  #-wsse $wsse 


        #-----------------------------------------------
        # STEP 6: Send Mailing - REST
        #-----------------------------------------------

        $mailingId = $getMailing.mailingID
        #$send_date = (Get-Date).AddSeconds(10).ToString("yyyy-MM-ddTHH:mm:ssZ")  #example Format = 2017-07-21T17:32:28Z

        $invokeParams = [Hashtable]@{
            Method = "Post"
            Uri = "$( $apiRoot )/send/$( $mailingId )"
            Headers = $header
            ContentType = $contentType
            Verbose = $true
            Body = @{
                send_type = "W"
                #send_date = $send_date
            } | ConvertTo-Json -Depth 99
        }

        # Do the sending only if the mode is not prepare
        If ( $params.mode ) {

            If ( $params.mode -eq "send" ) {
        
                # $body = @{
                #     send_type = "W"
                #     #send_date = $send_date
                # }
                
                # $bodyJson = $body | ConvertTo-Json
        
                <#
                    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Send-sendMailingIdPost
                #>
                $sendMailing = Invoke-RestMethod @invokeParams #-Method Post -Uri $endpoint -Headers $header -ContentType $contentType -Body $bodyjson -Verbose
                Write-Log -message "Broadcast done"
        
            }
        }

    } catch {

        #$e = ParseErrorForResponseBody($_)
        #Write-Log -message $_.Exception.Message -severity ([LogSeverity]::ERROR)

        # $errFile = "$( $exportPath )\errors.json"
        # Set-content -Value ( $e | ConvertTo-Json -Depth 20 ) -Encoding UTF8 -Path $errFile 
        # Write-Log -message "Written error messages into '$( $errFile )'" -severity ([LogSeverity]::ERROR)

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

    # Remove lockfile, whatever happened
    Write-log -message "Removing the lock file now"
    Remove-Item -Path $settings.broadcast.lockfile -Force -Verbose


    ################################################
    #
    # RETURN
    #
    ################################################

    #-----------------------------------------------
    # RETURN VALUES TO PEOPLESTAGE
    #-----------------------------------------------

    # put in the source id as the listname
    $transactionId = $mailingId

    # return object
    $return = [Hashtable]@{

        # # Mandatory return values
        "Recipients"=$params.RecipientsQueued
        "TransactionId"=$transactionId

        # # General return value to identify this custom channel in the broadcasts detail tables
        "CustomProvider"=$moduleName
        "ProcessId" = $processId

    }

    # return the results
    $return

}



