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
        TransactionType = "Replace"
        Password = "b"
        scriptPath = "D:\Scripts\TriggerDialog\v2"
        MessageName = "34362 / 30449 / Kampagne A / Aktiv / UPLOAD"
        EmailFieldName = "email"
        SmsFieldName = ""
        Path = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_34362  30449  Kampagne A  Aktiv  UPLOAD_52af38bc-9af1-428e-8f1d-6988f3460f38.txt"
        ReplyToEmail = "" 
        Username = "a"
        ReplyToSMS = ""
        UrnFieldName = "Kunden ID"
        ListName = "34362 / 30449 / Kampagne A / Aktiv / UPLOAD"
        CommunicationKeyFieldName = "Communication Key"
    }
}


################################################
#
# NOTES
#
################################################

<#


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
$modulename = "TRUPLOAD"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


################################################
#
# PROCESS
#
################################################


#-----------------------------------------------
# PARSE MESSAGE NAME
#-----------------------------------------------

$message = [TriggerDialogMailing]::new($params.MessageName)


#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$contentType = $settings.contentType
$headers = @{
    "accept" = $settings.contentType
}


#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

Get-TriggerDialogSession
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret $settings.authentication.authenticationSecret
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )

$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# LOAD AND CHECK STATUS OF CAMPAIGN
#-----------------------------------------------

$campaignDetails = Invoke-TriggerDialog -customerId $customerId -headers $headers -path "longtermcampaigns"
if ( ( $campaignDetails | where { $_.id -eq $message.campaignId } ).campaignState.id -ne 120 ) {
    Write-Log -message "Campaign is not active yet" -severity ( [LogSeverity]::ERROR )
    throw [System.IO.InvalidDataException] "Campaign is not active yet"
}


#-----------------------------------------------
# LOAD EXISTING FIELDS
#-----------------------------------------------

$variableDefinitions = Invoke-TriggerDialog -customerId $customerId -path "mailings/$( $message.mailingId )/variabledefinitions" -headers $headers


#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

# TODO [ ] implement loading bigger files later

# Get file item
$file = Get-Item -Path $params.Path
$filename = $file.Name -replace $file.Extension

# Load data from file
$dataCsv = [System.Collections.ArrayList]@( import-csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 )
Write-Log -message "Loaded $( $dataCsv.Count ) records"


#-----------------------------------------------
# FIELD MAPPING
#-----------------------------------------------

# Check csv fields
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
Write-Log -message "Loaded csv attributes '$( $csvAttributesNames.Name -join ", " )'"

# Create mapping for source and target
$colMap = [System.Collections.ArrayList]@()

# Add URN column
<#
$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.UrnFieldName
        "target" = $settings.upload.urnColumn
    }
)
#>

# Check corresponding field NAMES
$compareNames = Compare-Object -ReferenceObject $variableDefinitions.label -DifferenceObject $csvAttributesNames.Name -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
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

# Log
Write-Log -message "Current field mapping is:"
$colMap | ForEach {
    Write-Log -message "    $( $_.source ) -> '$( $_.target )'"
}

# TODO [ ] should this 
If ( $remainingColumns.count -gt 0 ) {
    Write-Log -message "Following columns are missing: $( $remainingColumns.Name -join ", " )" -severity ( [LogSeverity]::WARNING )
}


#-----------------------------------------------
# TRANSFORM UPLOAD DATA
#-----------------------------------------------

$urnFieldName = $params.UrnFieldName
$recipients = [System.Collections.ArrayList]@()
$dataCsv | ForEach {

    # Use current row
    $row = $_

    # Special Fields
    #$row.$commkeyFieldName

    # Generate the receiver meta data
    
    $entry = [PSCustomObject]@{
        "recipientIdExt" = $row.$urnFieldName
        "recipientData" = [System.Collections.ArrayList]@()  #[PSCustomObject]@{}
    }
    
    # Generate the custom receiver columns data
    $colMap | ForEach {
        $source = $_.source.ToString()
        $target = $_.target.ToString()
        [void]$entry.recipientData.Add([PSCustomObject]@{
            label = $target
            value = $row.$source
        })
    }

    # Changing the urn colum to the correct value
    #If ( $settings.upload.urnContainsEmail ) {
    #    $entry.data.($settings.upload.urnColumn) = $urn
    #}

    # Add recipient to array
    [void]$recipients.Add($entry)

}

Write-Log -message "Added '$( $recipients.Count )' receivers to the queue"


#-----------------------------------------------
# UPLOAD DATA
#-----------------------------------------------

# Should be max 100 recipients per batch
# TODO [x] change this back to variable 
$batchsize = $settings.upload.rowsPerUpload

$results = [System.Collections.ArrayList]@()
if ( $recipients.Count -gt 0 ) {
    
    $chunks = [Math]::Ceiling( $recipients.count / $batchsize )

    $t = Measure-Command {
        for ( $i = 0 ; $i -lt $chunks ; $i++  ) {
            
            $start = $i*$batchsize
            $end = ($i + 1)*$batchsize - 1

            # Create body for API call
            $body = @{
                "campaignId" = $message.campaignId #$campaign.id
                "customerId" = $customerId
                "recipients" = $recipients[$start..$end]
            }

            # Check size of recipients object
            Write-Host "start $($start) - end $($end) - $( $body.recipients.Count ) objects"

            # Write body to jsonfile
            $body | ConvertTo-Json -Depth 20 | Set-Content -path "$( $settings.upload.uploadsFolder )\$( $timestamp.ToString("yyyyMMdd_HHmmss") )_$( $processId.guid ).json" -Encoding UTF8

            # Do API call
            $result = Invoke-TriggerDialog -customerId $customerId -path "recipients" -method Post -headers $headers -body $body -returnRawObject
            
            # Log results of this chunk
            Write-Host "Got back correlation id '$( $result.correlationId )'"

            # Add correlation id
            [void]$results.add($result) #$result.correlationId

        }
    }
}

# Log the results
Write-Log -message "Queued $( $recipients.Count ) records in $( $chunks ) chunks and $( $t.TotalSeconds ) seconds"

# Exporting the correlation IDs for later
$results | Export-Csv -Path "$( $settings.upload.uploadsFolder )\$( $timestamp.ToString("yyyyMMdd_HHmmss") )_$( $processId.guid ).csv" -Delimiter "`t" -NoTypeInformation -Encoding UTF8


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

$queued = $dataCsv.Count

If ( $queued -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"        = $queued 
    "TransactionId"     = $result.correlationId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"    = $moduleName
    "ProcessId"         = $processId

    # Some more information for the broadcasts script
    "Path"              = $params.Path
    "UrnFieldName"      = $params.UrnFieldName
    "CorrelationId"     = $result.correlationId

    # More information about the different status of the import
    #"RecipientsIgnored" = $ignored
    #"RecipientsQueued" = $queued

}

# return the results
$return

exit 0


#$body = $dataCsv | select $colMap.source | ConvertTo-Csv -Delimiter ";" -NoTypeInformation
#$body | Set-Content -Encoding UTF8 -Path ".\exp.csv"
# get file, load and encode it
#$fileBytes = [System.IO.File]::ReadAllBytes("D:\Scripts\TriggerDialog\v2\swagger\Unbenannt 1.xlsx")
#$fileEncoded = [System.Text.Encoding]::GetEncoding($uploadEncoding).GetString($fileBytes)

<#
$b = @{
    file = $fileEncoded
}
#>

#try {

#} catch {
#    $errorMessage = ParseErrorForResponseBody -err $_
#    $errorMessage.errors | ForEach {
#        Write-Log -severity ( [LogSeverity]::ERROR ) -message "$( $_.errorCode ) : $( $_.errorMessage )"
#    }
    #Throw [System.IO.InvalidDataException]
#}


