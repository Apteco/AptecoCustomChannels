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
        "TransactionType" = "Replace"
        "Password" = "b"
        "scriptPath" = "D:\Scripts\ELAINE\Transactional"
        "MessageName" = "1875 / Apteco PeopleStage Training Automation"
        "EmailFieldName" = "c_email"
        "SmsFieldName" = ""
        "Path" = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_1875  Apteco PeopleStage Training Automation_f29a31c9-7935-4bf6-b55c-e2794ea36dba.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "1875 / Apteco PeopleStage Training Automation"
        "CommunicationKeyFieldName" = "Communication Key"
    }
}


################################################
#
# NOTES
#
################################################

<#

# TODO [ ] Test required fields object in settings
# TODO [ ] Test with and without variant field defined in settings
# TODO [ ] SQLServer: hold connection open to test better performance
# TODO [ ] Add BULK and Single send mode to the the settings creation or make id dependent on the version
# TODO [ ] Check the usage of the notification url with webhooks


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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "ELNUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
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
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}
<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>

################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.upload.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# PREPARE CALLING ELAINE
#-----------------------------------------------

Create-ELAINE-Parameters


#-----------------------------------------------
# ELAINE VERSION
#-----------------------------------------------
<#
This call should be made at the beginning of every script to be sure the version is filled (and the connection could be made)
#>

if ( $settings.checkVersion ) { 

    $elaineVersion = Invoke-ELAINE -function "api_getElaineVersion"
    # or like this to get it back as number
    #$elaineVersion = Invoke-ELAINE -function "api_getElaineVersion" -method "Post" -parameters @($true)

    Write-Log -message "Using ELAINE version '$( $elaineVersion )'"

    # Use this function to check if a mininum version is needed to call the function
    #Check-ELAINE-Version -minVersion "6.2.2"

}


#-----------------------------------------------
# PARSE MAILING AND LOAD DETAILS
#-----------------------------------------------

<#

mailingId mailingName
--------- -----------
1875      Apteco PeopleStage Training Automation

#>
$mailing = [Mailing]::New($params.MessageName)

# Load details from ELAINE to check if it still exists
$mailingDetails = Invoke-ELAINE -function "api_getDetails" -parameters @("Mailing",[int]$mailing.mailingId)
if ( $mailingDetails.status_data.is_transactionmail ) {
    Write-Log -message "Mailing is confirmed as a transactional mailing"
} else {
    Write-Log -message "Mailing is no transactional mailing"
    throw [System.IO.InvalidDataException] "Mailing is no transactional mailing"
}


#-----------------------------------------------
# IMPORT DATA
#-----------------------------------------------

$dataCsv = Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 -Verbose
Write-Log -message "Loaded '$( $dataCsv.count )' records"


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

# TODO [ ] Loading only C fields or think of group dependent fields, too?
$fields = Invoke-ELAINE -function "api_getDatafields"

<#
# Load group fields
# TODO [ ] Activate group dependent features
$fields += Invoke-ELAINE -function "api_getDatafields" -parameters @([int]$group.groupId)
#>

Write-Log -message "Loaded fields $( $fields.f_name -join ", " )"


#-----------------------------------------------
# FIELD MAPPING
#-----------------------------------------------

# Check csv fields
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
Write-Log -message "Loaded csv attributes '$( $csvAttributesNames.Name -join ", " )'"

# Create mapping for source and target
$colMap = [System.Collections.ArrayList]@()

# Add URN column
[void]$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.UrnFieldName
        "target" = $settings.upload.urnColumn
    }
)

# Add email column
[void]$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.EmailFieldName
        "target" = $settings.upload.emailColumn
    }
)

# Save which fields are required
$requiredFields = $colMap.source
if ( $settings.upload.requiredFields -ne $null ) {
    $settings.upload.requiredFields | ForEach {
        $requiredFields += $_
    }
}

# Which columns are remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field NAMES
$compareNames = Compare-Object -ReferenceObject $fields.f_name -DifferenceObject $remainingColumns.Name -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
$compareNames | ForEach {
    $fieldname = $_
    [void]$colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldname
            "target" = $fieldname
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field LABELS
$compareLabels = Compare-Object -ReferenceObject $fields.f_label -DifferenceObject $remainingColumns.Name  -IncludeEqual -PassThru  | where { $_.SideIndicator -eq "==" }
$compareLabels | ForEach {
    $fieldlabel = $_
    [void]$colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldlabel
            "target" = $fields.where({ $_.f_label -eq $fieldlabel }).f_name
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Add remaining columns as t_ columns
$remainingColumns | ForEach {
    $columnName = $_
    [void]$colMap.Add(
        [PSCustomObject]@{
            "source" = $columnName.Name
            "target" = "t_$( $columnName.Name.ToLower().replace(" ","_") )" # TODO [ ] check if maybe more is needed
        }
    )
}

Write-Log -message "Current field mapping is:"
$colMap | ForEach {
    Write-Log -message "    $( $_.source ) -> '$( $_.target )'"
}

# Add variant name if present
if ( $settings.upload.variantColumn -ne $null ) {
    $requiredFields += $settings.upload.variantColumn
}
Write-Log -message "Required fields '$( $requiredFields -join ", " )'"

# Check if required fields are present
$compareRequirements = Compare-Object -ReferenceObject $csvAttributesNames.Name -DifferenceObject $requiredFields -IncludeEqual -PassThru
$equalWithRequirements = $compareRequirements | where { $_.SideIndicator -eq "==" }
if ( $equalWithRequirements.count -eq $requiredFields.Count ) {
    # Required fields are all included
    Write-Log -message "All required fields are present"
} else {
    # Required fields not equal -> error!
    Write-Log -message "Not all required fields are present, missing $( ( $compareRequirements | where { $_.SideIndicator -eq "=>" } ) -join ", " )!"  
    throw [System.IO.InvalidDataException] "Not all required fields are present, missing $( ( $compareRequirements | where { $_.SideIndicator -eq "=>" } ) -join ", " )!"  
}


#-----------------------------------------------
# CREATE UPLOAD OBJECT
#-----------------------------------------------

$urnFieldName = $params.UrnFieldName
$commkeyFieldName = $params.CommunicationKeyFieldName
$variantColumnName = $settings.upload.variantColumn
$emailFieldName = $params.EmailFieldName

$recipients = [System.Collections.ArrayList]@()
$dataCsv | ForEach {

    # Use current row
    $row = $_

    # Use variant column
    if ( $variantColumnName -ne $null ) {
        $variant = $row.$variantColumnName
    } else {
        $variant = ""
    }

    # Generate the correct URN, which could contain email and URN
    If ( $settings.upload.urnContainsEmail ) {
        $urn = "$( $row.$urnFieldName )|$( $row.$emailFieldName )"
    } else {
        $urn = $row.$urnFieldName
    }

    # Generate the receiver meta data
    $entry = [PSCustomObject]@{
        "variant" = $variant
        "communicationKey" = $row.$commkeyFieldName
        "urn" = $urn
        "email" = $row.$emailFieldName
        "data" = [PSCustomObject]@{}
    }

    # Generate the custom receiver columns data
    $colMap | ForEach {
        $source = $_.source
        $target = $_.target
        $entry.data | Add-Member -MemberType NoteProperty -Name $target -Value $row.$source
    }

    # Changing the urn colum to the correct value
    If ( $settings.upload.urnContainsEmail ) {
        $entry.data.($settings.upload.urnColumn) = $urn
    }

    # Add recipient to array
    [void]$recipients.Add($entry)

}

Write-Log -message "Added '$( $recipients.Count )' receivers to the queue"



#-----------------------------------------------
# SEND SINGLE TRANSACTIONAL
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
Recipients on black and bounce lists are NOT automatically excluded, but this can be controlled via the blacklist parameter
BULK: Additionally to the non-bulk mode, the bulk mechanism uses the bounce list; Only possible for one mailing id and abortOnError will be ignored -> Either the whole call will be send out or not
#>
# TODO [ ] Check BULK and Version
# TODO [ ] Check usage of group

<#
This is how the content could look like:

[ordered]@{
    "c_urn"             = "414596"
    "c_email"          = "test@example.tld"
    #"t_subject"        = "Test-Betreff"
    #"t_sendername"     = "Apteco GmbH"
    #"t_sender"         = "info@apteco.de"
    #"t_replyto" $       = "antwort@example.tld"
    #"t_cc"             = "cc_empfaenger@example.tld"
    #"t_bcc"            = "bcc_empfaenger@example.tld"
    #"t_attachment"     = @()
    #"t_textcontent"    = "Text-Inhalt"
    #"t_htmlcontent"    = "HTML-Inhalt"
    #"t_xxx"            = "Hello World"
}

#>

# Measure the seconds in total
$t1 = Measure-Command {
    $sends = [System.Collections.ArrayList]@()
    $recipients | ForEach {

        # Use current row
        $recipient = $_

        # variant, if needed
        if ( $recipient.variant -eq $null -or $recipient.variant -eq "" ) {
            $variant = ""
        } else {
            $variant = $recipient.variant
        }

        # Create the upload data object
        $dataArr = [ordered]@{
            "content" = $recipient.data
            "priority" = $settings.upload.priority        
            "override" = $settings.upload.override
            "update_profile" = $settings.upload.updateProfile
            "msgid" = $recipient.communicationKey
            "notify_url" = $settings.upload.notifyUrl
        }

        # Create payload and upload json object
        $jsonInput = @(
            $dataArr                        # array $data = null                    Recipient data
            [int]$mailing.mailingId         # int $nl_id                            Mailing
            "" #$selectedGroup[0].ev_id     # int $ev_id                            Group is optional
            $variant                        # int $variant_position : null
            $settings.upload.blacklist      # boolean|integer $blacklist : true     
        )
        $send = Invoke-ELAINE -function "api_sendSingleTransaction" -method Post -parameters $jsonInput
        
        # Add the results
        [void]$sends.Add(
            [PSCustomObject]@{
                "urn" = $recipient.urn
                "email" = $recipient.email
                "sendId" = $send
                "communicationKey" = $recipient.communicationKey
                "broadcastTransactionId" = $processId.Guid
                "mailingId" = $mailing.mailingId
            }
        )

    }
}
Write-Log -message "Send out '$( $sends.Count )' messages in '$( $t1.TotalSeconds )' seconds"


#-----------------------------------------------
# GET TRANSACTIONAL MAILING STATUS
#-----------------------------------------------

# TODO [ ] put this into bulk in future, too

# Wait until all mails have been send out successfully or timeout expired
$sendsStatus = [System.Collections.ArrayList]@()
if ( $settings.upload.waitForSuccess ) {

    # Initial wait of 5 seconds, so there is a good chance the messages are already send
    Start-Sleep -Seconds 5

    $stopWatch = [System.Diagnostics.Stopwatch]::new()
    $timeSpan = New-TimeSpan -Seconds $settings.upload.timeout
    $stopWatch.Start()
    do
    {
        $sends | where { $_.sendId -notin $sendsStatus.sendId } | ForEach {
            $sendOut = $_
            $jsonInput = @(
                [int]$sendOut.sendId    # int $id
                $false                  # bool $is_msgid -> true if the id is an external message id
            ) 
            $status = Invoke-ELAINE -function "api_getTransactionMailStatus" -method Post -parameters $jsonInput
            if ( $status.status -eq "sent" ) {
                $sendOut | Add-Member -MemberType NoteProperty -Name "lastStatus" -Value $status.status                    
                [void]$sendsStatus.Add($sendOut)
            }
        }
        # wait another n seconds
        Start-Sleep -Seconds $settings.upload.checkEveryNSeconds
    }
    until (( $sends.Count -eq $sendsStatus.count ) -or ( $stopWatch.Elapsed -ge $timeSpan ))
    
    Write-Log -message "Got back $( $sendsStatus.count ) successful sents"

}

# Put queued, but not sent uploads into object, too
$queue = @( $sends | where { $_.sendId -notin $sendsStatus.sendId } | select *, @{name="lastStatus";expression={ "queued" }} )
if ( $queue ) {
    [void]$sendsStatus.AddRange( $queue )
}


#-----------------------------------------------
# OUTPUT RESULTS TO FILE
#-----------------------------------------------

# Write results into uploads folder
$exportTimestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
$resultsFile = "$( $uploadsFolder )$( $exportTimestamp )_$( $processId ).csv"
$sendsStatus | select * | Export-Csv -Path $resultsFile -Encoding UTF8 -NoTypeInformation -Delimiter "`t"
Write-Log -message "Written results into $( $resultsFile )"


#-----------------------------------------------
# OUTPUT RESULTS TO DATABASE
#-----------------------------------------------

<#
outputs the records to a table like this one, if wished
[dbo].[ELAINETransactional](
	[Urn] [nvarchar](255) NULL,
	[Email] [nvarchar](255) NULL,
	[SendId] [int] NULL,
	[CommunicationKey] [uniqueidentifier] NULL,
	[BroadcastTransactionId] [uniqueidentifier] NULL,
	[MailingId] [int] NULL,
	[LastStatus] [nvarchar](50) NULL,
    [Timestamp] [datetime] NULL
#>

if ( $settings.upload.writeToDatabase ) {

    $writtenRecords = 0
    switch ( $settings.upload.writeMethod ) {

        "SqlClient" {

            $insertStatementTemplate = Get-Content -Path ".\sql\insert_elaine_transactional.sql" -Encoding UTF8

            $sendsStatus | ForEach {

                $row = $_

                $insertStatement = $insertStatementTemplate

                # Replace fields/tokens
                $row.psobject.properties.name | foreach {
                    $prop = $_
                    $token = "#$( $prop.ToUpper() )#"
                    $insertStatement = $insertStatement -replace $token,$row.$prop
                }

                # Replace database and schema
                $insertStatement = $insertStatement -replace "#TABLE#",$settings.upload.databaseTable
                $insertStatement = $insertStatement -replace "#SCHEMA#",$settings.upload.databaseSchema

                # Prepare statement
                $statementParams = @{
                    "query" = $insertStatement
                    "instance" = $settings.upload.databaseInstance
                    "database" = $settings.upload.databaseName
                    "executeNonQuery" = $true
                }

                # Prepare authentication
                if ( $settings.upload.trustedConnection ) {

                    $statementParams += @{
                        "trustedConnection" = $true
                    }

                } else {

                    $securePass = ConvertTo-SecureString ( Get-SecureToPlaintext $settings.upload.databasePass ) -AsPlainText -Force
                    $securePass.MakeReadOnly()
                    $sqlcred = New-Object -TypeName System.Data.SqlClient.SqlCredential -ArgumentList $settings.upload.databaseUser, $securePass
                    $statementParams += @{
                        "sqlCredential" = $sqlCred
                    }

                }

                $writtenRecords += Invoke-SqlServer @statementParams
        
            }

        }
        <#
        # TODO [ ] Implement this one if wished -> alternate way for inserting data instead of single inserts, but needs additional ssms installation on the machine
        "SqlServer" {
            if ( $settings.upload.trustedConnection ) {
                $sendsStatus | Write-SqlTableData -ServerInstance $settings.upload.databaseInstance -DatabaseName $settings.upload.databaseName -SchemaName $settings.upload.databaseSchema -TableName $settings.upload.databaseTable -Force
            } else {
                $sqlcred = New-Object PSCredential $settings.upload.databaseUser,(ConvertTo-SecureString ( Get-SecureToPlaintext $settings.upload.databasePass ) -AsPlainText -Force)
                $sendsStatus | Write-SqlTableData -ServerInstance $settings.upload.databaseInstance -DatabaseName $settings.upload.databaseName -SchemaName $settings.upload.databaseSchema -TableName $settings.upload.databaseTable -Force -Credential $sqlcred
            }
        
        }
        #>

    }

    Write-Log -message "INSERT $( $writtenRecords ) records into database"

}


#-----------------------------------------------
# FINAL RESULTS
#-----------------------------------------------

# Calculate results in total
$queued = $dataCsv.count
$sent = ( $sendsStatus | where { $_.lastStatus -eq "sent" } ).Count
$ignored = $sent - $queued

# Log the results
Write-Log -message "Imported '$( $dataCsv.Count  )' -> Queued '$( $sends.Count )' -> Already sent '$( $sent )' records in $( $t1.TotalSeconds   ) seconds "


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

If ( $sent -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"=$queued 
    "TransactionId"=$processId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$moduleName
    "ProcessId" = $processId

    # Some more information for the broadcasts script
    "EmailFieldName"= $params.EmailFieldName
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName

    # More information about the different status of the import
    "RecipientsIgnored" = $ignored
    "RecipientsQueued" = $queued
    "RecipientsSent" = $sent

}

# return the results
$return