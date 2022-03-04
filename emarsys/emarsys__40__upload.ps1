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

        # Integration parameters
	    scriptPath= 'C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\emarsys'
        createNewFields = 'false'

        MessageName = '19140 | New Registration'
        TransactionType = 'Replace'
        #Password = 'ko'
        EmailFieldName = 'email'
        #SmsFieldName = ''
        Path = 'C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\emarsys\data.csv'
        #ReplyToEmail = ''
        #Username = 'ko'
        #ReplyToSMS = ''
        #mode = 'send'
        UrnFieldName = 'Kunden ID'
        ListName = '19140 | New Registration'
        CommunicationKeyFieldName = 'Communication Key'
    }
}


################################################
#
# NOTES
#
################################################

<#

https://dev.emarsys.com/docs/emarsys-api/b3A6MjQ4OTk5MDU-trigger-an-external-event


    The maximum payload size is 10 MB, therefore the maximum number of new contacts per call depends on the amount of data per contact.
    The maximum batch size is 1000 contacts per call.


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

$script:moduleName = "EMARSYS-UPLOAD"

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


    #-----------------------------------------------
    # CREATE EMARSYS OBJECT
    #-----------------------------------------------

    $stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.secret ) -AsPlainText -Force
    $cred = [pscredential]::new( $settings.login.username, $stringSecure )

    # Create emarsys object
    $emarsys = [Emarsys]::new($cred,$settings.base)


    #-----------------------------------------------
    # PARSE EVENT
    #-----------------------------------------------

    $parsedEvent = [DCSPMailing]::new( $params.MessageName )
    Write-Log "Parsed event with id '$( $event.id )' and name ' $( $event.name ) '"
    

    #-----------------------------------------------
    # GET ALL EVENTS
    #-----------------------------------------------

    $events = $emarsys.getExternalEvents()

    Write-Log "Loaded '$( $events.Count )' external events from emarsys"

   
    #-----------------------------------------------
    # CHECK AND LOAD EVENT
    #-----------------------------------------------

    $event = $events | where { $_.id -eq $parsedEvent.id }

    If ( $event -eq $null ) {
        throw [System.IO.InvalidDataException] "No valid external event"
    }

    #-----------------------------------------------
    # LOAD EMARSYS FIELDS
    #-----------------------------------------------

    $fields = $emarsys.getFields($false) #| Out-GridView -PassThru | Select -first 20
    #$fields | Out-GridView
    #$fields | Export-Csv -Path ".\fields.csv" -Encoding Default -NoTypeInformation -Delimiter "`t"
    #$fields | Select @{name="field_id";expression={ $_.id }}, @{name="fieldname";expression={$_.name}} -ExpandProperty choices | Export-Csv -Path ".\fields_choices.csv" -Encoding Default -NoTypeInformation -Delimiter "`t"

    #-----------------------------------------------
    # LOAD FILE
    #-----------------------------------------------

    $dataCsv = @( Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 )
    Write-Log -message "Got a file with $( $dataCsv.count ) records"


    #-----------------------------------------------
    # LOAD FILE COLUMNS
    #-----------------------------------------------

    #-----------------------------------------------
    # COMPARE FIELDS/COLUMNS
    #-----------------------------------------------

    if ( $params.createNewFields ) {
        # xyz
    }

<#
    {
        "key_id": 3,
        "contacts": [
            {
                "external_id": "test@example.com",
                "trigger_id": "trigger-id-1",
                "data": {
                  "global": {
                    "global_variable1": "global_value",
                    "global_variable2": "another_global_value"
                },
                "twig_variable1": "first_value",
                "twig_variable2": "another_value"
                },
                "attachment": [
            {
                "filename": "example.pdf",
                "data": "ZXhhbXBsZQo=" 
            }
        ]
            }
        ]
    }
#>




    #-----------------------------------------------
    # CREATE UPLOAD OBJECT
    #-----------------------------------------------

    # Set identifiers
    $urnFieldName = $params.UrnFieldName
    $commkeyFieldName = $params.CommunicationKeyFieldName

    # Setting the keyfield - default is 3 = email
    # TODO [ ] possibly put this default somewhere else
    if ( $settings.upload.keyId ) {
        $keyField = $fields | where { $_.id -eq $settings.upload.keyId }
    } else {
        $keyField = $fields | where { $_.id -eq 3 }
    }

    $recipientBatches = [System.Collections.ArrayList]@()
    $recipients = [System.Collections.ArrayList]@()
    $i = 0
    $dataCsv | ForEach {

        # Use current row
        $row = $_

        # Use variant column
        # if ( $variantColumnName -ne $null ) {
        #     $variant = $row.$variantColumnName
        # } else {
        #     $variant = $null
        # }

        # Generate the correct URN, which could contain email and URN
        # If ( $settings.upload.urnContainsEmail ) {
        #     $urn = "$( $row.$urnFieldName )|$( $row.$emailFieldName )"
        # } else {
        #     $urn = $row.$urnFieldName
        # }

        # Generate the receiver meta data
        $entry = [PSCustomObject]@{
            "external_id" = $row."$( $keyField.name )"
            "trigger_id" = $row.$commkeyFieldName
            "data" = [PSCustomObject]@{
                "global" = [PSCustomObject]@{
                    "first_name" = $row.first_name
                    "last_name" = $row.last_name
                }
                # "twig_variable1" = "first_value"
                # "twig_variable2" = "another_value"
            }
            # "attachment" = @(
            #     [PSCustomObject]@{
            #         "filename" = "example.pdf"
            #         "data" = "ZXhhbXBsZQo=" 
            #     }
            # )
        }

        # Generate the custom receiver columns data
        # $colMap | ForEach {
        #     $source = $_.source
        #     $target = $_.target
        #     $entry.data | Add-Member -MemberType NoteProperty -Name $target -Value $row.$source
        # }

        # Changing the urn colum to the correct value
        # If ( $settings.upload.urnContainsEmail ) {
        #     $entry.data.($settings.upload.urnColumn) = $urn
        # }

        # Add recipient to array
        # TODO [ ] put this 100 into an variable
        If ( $i % 100 ) {
            [void]$recipientBatches.Add($recipients)
            $recipients = [System.Collections.ArrayList]@()
            $i = 0
        } else {
            [void]$recipients.add($entry)
            $i += 1
        }

    }

    # Add the last batch to the array
    [void]$recipientBatches.Add($recipients)


    Write-Log -message "Added '$( $recipients.Count )' receivers batches to the queue"

    
    #-----------------------------------------------
    # SEND OUT BATCHES OF MAX 1000
    #-----------------------------------------------

    # Measure the seconds in total
    $t1 = Measure-Command {
        $sends = [System.Collections.ArrayList]@()
        $recipientBatches | ForEach {

            # Use current batch
            $recipientBatch = $_

            # variant, if needed
            # if ( $recipient.variant -eq $null -or $recipient.variant -eq "" ) {
            #     $variant = $null
            # } else {
            #     $variant = $recipient.variant
            # }

            # Create the upload data object
            $dataArr = [PSCustomObject]@{
                "key_id" = $keyField.id
                "contacts" = @( $recipientBatch )
            }

            $dataJson = ConvertTo-Json -InputObject $dataArr -Depth 99
            # $dataArr = [ordered]@{
            #     "content" = $recipient.data
            #     "priority" = $settings.upload.priority        
            #     "override" = $settings.upload.override
            #     "update_profile" = $settings.upload.updateProfile
            #     "msgid" = $recipient.communicationKey
            #     "notify_url" = $settings.upload.notifyUrl
            # }

            $batchSend = Invoke-emarsys -cred $cred -uri "$( $settings.base )/$( $event.id )/trigger" -method Post -body $dataJson 

            # Create payload and upload json object
            # $jsonInput = @(
            #     $dataArr                        # array $data = null                    Recipient data
            #     [int]$mailing.mailingId         # int $nl_id                            Mailing
            #     "" #$selectedGroup[0].ev_id     # int $ev_id                            Group is optional
            #     $variant                        # int $variant_position : null
            #     $settings.upload.blacklist      # boolean|integer $blacklist : true     
            # )
            # $send = Invoke-ELAINE -function "api_sendSingleTransaction" -method Post -parameters $jsonInput
            
            # Add the results
            # [void]$sends.Add(
            #     [PSCustomObject]@{
            #         "urn" = $recipient.urn
            #         "email" = $recipient.email
            #         "sendId" = $send
            #         "communicationKey" = $recipient.communicationKey
            #         "broadcastTransactionId" = $processId.Guid
            #         "mailingId" = $mailing.mailingId
            #     }
            # )

        }
    }
    Write-Log -message "Send out '$( $sends.Count )' messages in '$( $t1.TotalSeconds )' seconds"

    exit 0


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
    $transactionId = $event.id
    
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

    # log the return object
    Write-Log -message "RETURN:"
    $return.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ) = '$( $return[$param] )'" -writeToHostToo $false
    }
    
    
    # return the results
    $return

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
