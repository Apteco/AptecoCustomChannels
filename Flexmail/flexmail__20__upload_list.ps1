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
	    EmailFieldName= "emailAddress"
	    TransactionType= "Replace"
	    Password= "def"
	    scriptPath= "C:\FastStats\scripts\flexmail"
	    MessageName= "123456 | 123456 | Regain"
	    abc= "def"
	    SmsFieldName= ""
	    Path= "c:\faststats\Publish\Handel\system\Deliveries\PowerShell_252060_e4ed1786-ce5d-4e51-af54-e97bb45d73a4.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Kunden ID"
	    ListName= "123456 | 123456 | Regain"
	    CommunicationKeyFieldName= "Communication Key"
    }
}





################################################
#
# NOTES
#
################################################

<#

- [ ] implement a lockfile to be sure there is only one import queued at a time

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
$moduleName = "FLXUPLOAD"
$processId = [guid]::NewGuid()

if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}

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

$uploadsFolder = $settings.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# PREPARE FLEXMAIL REST API
#-----------------------------------------------

Create-Flexmail-Parameters


#-----------------------------------------------
# CHECK SOURCES
#-----------------------------------------------

# TODO [ ] make sources available in lists dropdown in PeopleStage?

# Load sources from Flexmail
$url = "$( $apiRoot )/sources"
$sources = Invoke-RestMethod -Uri $url -Method Get -Headers $script:headers -Verbose -ContentType $contentType # load via REST
#$sources = Invoke-Flexmail -method "GetSources" -param @{} -responseNode "sources" # load via SOAP

# Extract the source id
$listId = [FlxWorkflow]::new($params.MessageName).workflowSource

# TODO [ ] Migrate using the messagename with the source id to use the source id from the listname
<#
$source = [Source]::new($params.ListName)
#>


# Check the source id against Flexmail
if ( $listId -notin $sources.id ) {
    $sourcesString = ( $sources | select @{name="concat";expression={ "$( $_.id ) ($( $_.name ))" }} ).concat -join "`n"
    $exceptionText = "List-ID $( $listId ) not found. Please use one of the following IDs without the description in the brackets:`n$( $sourcesString )" 
    Write-Log -message "Throwing Exception: $( $exceptionText )"
    throw [System.IO.InvalidDataException] $exceptionText    
}





#-----------------------------------------------
# IDENTIFY CUSTOM FIELDS
#-----------------------------------------------

#$customFieldsSOAP = Invoke-Flexmail -method "GetCustomFields" -param @{} -responseNode "customFields"
#$customFields = $customFieldsSOAP | Select @{name="placeholder";expression={ $_.id }}, *

$url = "$( $apiRoot )/custom-fields"
$customFieldsREST = Invoke-RestMethod -Uri $url -Method Get -Headers $script:headers -Verbose -ContentType $contentType # load via REST
$customFields = $customFieldsREST | Select * -ExpandProperty name | select @{name="label";expression={ $_.value }}, * -ExcludeProperty name



#-----------------------------------------------
# FIELD MAPPING
#-----------------------------------------------

# Load first rows
$dataCsv = Get-Content -path $params.Path -TotalCount 2 | convertfrom-csv -Delimiter "`t"

# Check csv fields
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
Write-Log -message "Loaded csv attributes '$( $csvAttributesNames.Name -join ", " )'"

# Create mapping for source and target
$colMap = [System.Collections.ArrayList]@()
<#
# Add URN column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.UrnFieldName
        "target" = $settings.uploadSettings.urnColumn
    }
)
#>

# Add email column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $params.EmailFieldName
        "target" = $params.EmailFieldName
    }
)

# Add first name column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $settings.uploadSettings.firstNameFieldname
        "target" = $settings.uploadSettings.firstNameFieldname
    }
)

# Add last name column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $settings.uploadSettings.lastNameFieldname
        "target" = $settings.uploadSettings.lastNameFieldname
    }
)

# Add language column
$colMap.Add(
    [PSCustomObject]@{
        "source" = $settings.uploadSettings.languageFieldname
        "target" = $settings.uploadSettings.languageFieldname
    }
)
<#
# Save which fields are required
$requiredFields = $colMap.source
if ( $settings.upload.requiredFields -ne $null ) {
    $settings.upload.requiredFields | ForEach {
        $requiredFields += $_
    }
}
#>

# Which columns are remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field NAMES
$compareNames = Compare-Object -ReferenceObject $customFields.placeholder -DifferenceObject $remainingColumns.Name -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }
$compareNames | ForEach {
    $fieldname = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldname
            "target" = $fieldname
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }

# Check corresponding field LABELS
$compareLabels = Compare-Object -ReferenceObject $customFields.label -DifferenceObject $remainingColumns.Name  -IncludeEqual -PassThru  | where { $_.SideIndicator -eq "==" }
$compareLabels | ForEach {
    $fieldlabel = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $fieldlabel
            "target" = $customFields.where({ $_.label -eq $fieldlabel }).placeholder
        }
    )
}

# Which columns are still remaining in csv?
$remainingColumns = $csvAttributesNames | where { $_.name -notin $colMap.source  }
<#
# Add remaining columns as t_ columns
$remainingColumns | ForEach {
    $columnName = $_
    $colMap.Add(
        [PSCustomObject]@{
            "source" = $columnName.Name
            "target" = "t_$( $columnName.Name.ToLower().replace(" ","_") )" # TODO [ ] check if maybe more is needed
        }
    )
}
#>

Write-Log -message "Current field mapping is:"
$colMap | ForEach {
    Write-Log -message "    '$( $_.source )' -> '$( $_.target )'"
}

Write-Log -message "Those fields are remaining in csv:"
$remainingColumns | ForEach {
    Write-Log -message "    '$( $_.name )'"
}

# Special field names
$urnFieldName = $params.UrnFieldName
$commkeyFieldName = $params.CommunicationKeyFieldName
$emailFieldName = $params.EmailFieldName
$firstNameFieldname = $settings.uploadSettings.firstNameFieldname
$lastNameFieldname = $settings.uploadSettings.lastNameFieldname 
$languageFieldname = $settings.uploadSettings.languageFieldname

$basicFields = [System.Collections.ArrayList]@(
    $urnFieldName
    $commkeyFieldName
    $emailFieldName
    $firstNameFieldname
    $lastNameFieldname
    $languageFieldname
)


<#
# TODO [ ] Test required fields object in settings
# TODO [ ] Test with and without variant field defined in settings

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
#>


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

Write-Log -message "Start to create a new file"

<#

custom fields

placeholder       label             type
--                -----             ----
custom_salutation Custom_Salutation Text
voucher_1         Voucher_1         Text
voucher_2         Voucher_2         Text
voucher_3         Voucher_3         Text

#>

# merge fixed/standard fields with existing custom fields
$fields = $colMap.source #$settings.uploadFields + $customFields.id

# Create temporary directory
$exportTimestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
$exportFolder = "$( $uploadsFolder )\$( $exportTimestamp )_$( $processId.Guid )\"
New-Item -Path $exportFolder -ItemType Directory

# Move file to temporary uploads folder
#$source = Get-Item -LiteralPath "$( $params.path )"
#Write-Log -message "$( $params.Path )"
#Write-Log -message "$( $source.FullName )"

#$destination = "$( $exportFolder )\$( $source.name )"
Copy-Item -path $params.Path -Destination $exportFolder

Write-Log -message "Copy file '$( $params.Path )' to $( $exportFolder )"

# Remember the current location and change to the export dir
$currentLocation = Get-Location
Set-Location $exportFolder

# Split file in parts
$t = Measure-Command {
    $fileItem = Get-ChildItem -Path $exportFolder | Select -First 1
    $splitParams = @{
        inputPath = $fileItem.FullName
        header = $true
        writeHeader = $true
        inputDelimiter = "`t"
        outputDelimiter = "`t"
        outputColumns = $fields
        writeCount = 2 #$settings.rowsPerUpload
        outputDoubleQuotes = $true
    }
    $exportId = Split-File @splitParams
    #$exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $fields -writeCount $settings.rowsPerUpload -outputDoubleQuotes $true
}

# Set the location back
Set-Location $exportFolder

Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"


#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------
<#
$campaignId = [FlxWorkflow]::new($params.ListName).workflowId
$recipientListID = $settings.masterListId

Write-Log -message "Using the recipient list $( $recipientListID )"
#>

#-----------------------------------------------
# DEBUG - CHOOSE MAILINGLISTS
#-----------------------------------------------
<#
$categories = Invoke-Flexmail -method "GetCategories"
$firstCategory = $categories | Out-GridView -PassThru
$mailingsParams = @{
    "categoryId"=@{
        "value"=$firstCategory.categoryId
        "type"="int"
     }
}

$mailingLists = Invoke-Flexmail -method "GetMailingLists" -param $mailingsParams
$mailingList = $mailingLists | Out-GridView -PassThru
#>
#-----------------------------------------------
# DEBUG - SHOW MAILINGLIST
#-----------------------------------------------
<#
if ( $debug ) {
    $emailsParams = @{
        "mailingListIds"=[array]@($recipientListID)  #$mailingList.mailingListId
    }
    $emails = Invoke-Flexmail -method "GetEmailAddresses" -param $emailsParams
    $emails | Out-GridView
}
#>

#-----------------------------------------------
# IMPORT RECIPIENTS VIA REST
#-----------------------------------------------

# Create an import id
$url = "$( $settings.baseREST )/contacts/imports"
$jobBody = @{
    "id" = $exportId
    "resubscribe_blacklisted_contacts" = $settings.uploadSettings.resubscribeBlacklistedContacts
}
$jobBodyJson = ConvertTo-Json -InputObject $jobBody -Verbose -Depth 8 -Compress
$jobUrl = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Verbose -ContentType $contentType -Body $jobBodyJson

# Checking the import creation
$url = "$( $settings.baseREST )/contacts/imports/$( $exportId )"
$job = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -Verbose -ContentType $contentType
Write-Log -message "Job is created with id  '$( $job.id )' and status '$( $job.status )'"

# Preparing the import
$url = "$( $settings.baseREST )/contacts/imports/$( $exportId )/records"
$exportPath = "$( $exportFolder )\$( $exportId )"
$partFiles = Get-ChildItem -Path "$( $exportPath )"
Write-Log -message "Uploading the data in $( $partFiles.count ) files"

# https://api.flexmail.eu/documentation/#post-/contacts/imports
# Import the data in parts
$importCalls = [System.Collections.ArrayList]@()
$partFiles | ForEach {

    $f = $_

    # Data
    $importRecipients = [System.Collections.ArrayList]@( import-csv -Path "$( $f.FullName )" -Delimiter "`t" -Encoding UTF8 )

    $recipients = [System.Collections.ArrayList]@()
    $importRecipients | ForEach {

        $row = $_

        <#
        $customFields | ForEach {
            $customField = $_.id
            if ( $row.$customField ) {
                $custom | Add-Member -MemberType NoteProperty -Name $customField -Value $row.$customField
            }
        }
        #>

        # Check if these fixed column names should be checked earlier
        $recipient = [PSCustomObject]@{
            email = $row.$emailFieldName
            first_name = $row.$firstNameFieldname
            name = $row.$lastNameFieldname
            language = "de" #$row.$languageFieldname # TODO [ ] change this back
            custom_fields = [PSCustomObject]@{}
            sources = @( $listId )
            interest_labels = @()
            preferences = @()
        }

        # Generate the custom receiver columns data
        $colMap | where { $_.target -notin $basicFields } | ForEach {
            $source = $_.source
            $target = $_.target
            $dataType = $customFields.where({ $_.placeholder -eq $target })[0].type
            $value = switch ( $dataType ) {
                "numeric" {
                    [int]$row.$source
                }
                "free_text" {
                    [String]$row.$source
                }
                Default {
                    [String]$row.$source
                }
            }
            $recipient.custom_fields | Add-Member -MemberType NoteProperty -Name $target -Value $value
        }
        
        # Add to array
        [void]$recipients.Add($recipient)

    }


    
<#
[
  {
    "email": "john@flexmail.be",
    "first_name": "John",
    "name": "Doe",
    "language": "nl",
    "custom_fields": {
      "organisation": "Flexmail",
      "myOtherCustomField": "42"
    },
    "sources": [
      42
    ],
    "interest_labels": [
      42
    ],
    "preferences": [
      42
    ]
  }
]
#>

    $uploadBodyJson = ConvertTo-Json -InputObject $recipients -Verbose -Depth 8 -Compress
    try {
        $importRecords = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Verbose -ContentType $contentType -Body $uploadBodyJson
        [void]$importCalls.Add( $importRecords )
    } catch {

        $e = ParseErrorForResponseBody($_)
        Write-Log -message ( $e | ConvertTo-Json -Depth 20 )
        throw $_.exception

        #Write-Host $_ -fore green
    }

} 

# Wait for the upload slot to be free
$outArgs = @{
    Path = $settings.lockfile
    fireExceptionIfUsed = $true
}
Retry-Command -Command 'Is-PathFree' -Args $outArgs -retries $settings.lockfileRetries -MillisecondsDelay $settings.lockfileDelayWhileWaiting

# Queue the import and set the lock file
$t = Measure-Command {
    try {

        # Write lock file
        $processId.Guid | Set-Content -Path $settings.lockfile -Verbose -Force -Encoding UTF8

        # Queue the import for processing
        $url = "$( $settings.baseREST )/contacts/imports/$( $exportId )"
        $queueBody = @{
            "status" = "queued"
        }
        $queueBodyJson = ConvertTo-Json -InputObject $queueBody -Verbose -Depth 8 -Compress
        $queue = Invoke-RestMethod -Uri $url -Method Patch -Headers $headers -Verbose -ContentType $contentType -Body $queueBodyJson

        # Loop the import status
        $sleepTime = $settings.uploadSettings.sleepTime
        $maxWaitTimeTotal = $settings.uploadSettings.maxSecondsWaiting
        $startTime = Get-Date
        Do {
            Start-Sleep -Seconds $sleepTime
            $status = Invoke-RestMethod -Uri $url -Method Get -Headers $headers -Verbose -ContentType $contentType
        } while ( $status.status -eq "idle" -and (New-TimeSpan -Start $startTime).TotalSeconds -lt $maxWaitTimeTotal)


    } finally {

        # Release the lock file
        Write-log -message "Removing the lock file now"
        Remove-Item -path $settings.lockfile -Force -Verbose

    }
}

Write-Log -message "Import done in $( $t.TotalSeconds ) seconds with status '$( $status.status )'"
Write-Log -message "Stats:"
Write-Log -message "    Added: $( $status.report.total_added )"
Write-Log -message "    Updated: $( $status.report.total_updated )"
Write-Log -message "    Ignored: $( $status.report.total_ignored )"


<#
{
    id: "e8f4143f-edd0-4f0a-8ea9-c674c049fe4f",
    status: "idle",
    message: "string",
    report: {
        total_added: 0,
        total_updated: 0,
        total_ignored: 0
    }
}
#>

#$importResults | Export-Csv -Path "$( $exportPath )\00_importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"
#Write-Log -message "Uploaded the data with $($importResults.Count) import results"



#-----------------------------------------------
# IMPORT RECIPIENTS VIA SOAP
#-----------------------------------------------
<#
# upload in batches of x
$exportPath = "$( $uploadsFolder )\$( $exportId )"
$partFiles = Get-ChildItem -Path "$( $exportPath )"

Write-Log -message "Uploading the data in $( $partFiles.count ) files"

$importResults = @()
$partFiles | ForEach {

    $f = $_

    $importRecipients = [array]@( import-csv -Path "$( $f.FullName )" -Delimiter "`t" -Encoding UTF8 )

    # if the source name does not exist, Flexmail create a new one automatically
    $importSourcesName = $sources.where( { $_.id -eq $listId } ).name
    $importSources = [array]@( [PSCustomObject]@{"name"=$importSourcesName } )
    
    # pack everything together
    $importParams = @{
        "mailingListId"=$recipientListID
        "emailAddressTypeItems"=@{value=$importRecipients;type="EmailAddressType"}
        "overwrite"=$settings.importSettings.overwrite
        "synchronise"=$settings.importSettings.synchronise
        "allowDuplicates"=$settings.importSettings.allowDuplicates
        "allowBouncedOut"=$settings.importSettings.allowBouncedOut
        "defaultLanguage"=$settings.importSettings.defaultLanguage
        "referenceField"=$settings.importSettings.referenceField
        "sources"=@{value=$importSources;type="SourcesType"}
    }
 
    $importResult = Invoke-Flexmail -method "ImportEmailAddresses" -param $importParams -customFields $customFields #-verboseCall
    
    # TODO [ ] Check if arraylist is maybe more performant
    $importResults += $importResult

} 

$importResults | Export-Csv -Path "$( $exportPath )\00_importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"

Write-Log -message "Uploaded the data with $($importResults.Count) import results"
#>
<#
#-----------------------------------------------
# DEBUG - SHOW MAILINGLIST AFTER CHANGE
#-----------------------------------------------

if ( $debug ) {
    $emailsParams = @{
        "mailingListIds"=[array]@($recipientListID)  #$mailingList.mailingListId
    }
    $emails = Invoke-Flexmail -method "GetEmailAddresses" -param $emailsParams
    $emails | Out-GridView
}
#>

#-----------------------------------------------
# RETURN VALUES TO PEOPLESTAGE
#-----------------------------------------------

# count the number of successful upload rows
$recipients = $importResults.count # | where { $_.Result -ne 0} | Select Urn

# put in the source id as the listname
#$transactionId = $params.ListName

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"=$recipients
    "TransactionId"=$campaignId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$moduleName
    "ProcessId" = $processId

    # Some more information for the broadcasts script
    "EmailFieldName"= $params.EmailFieldName
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName

    # More information about the different status of the import
    "RecipientsIgnored" = $status.report.total_ignored
    #"RecipientsQueued" = $queued
    "RecipientsSent" = $status.report.total_added + $status.report.total_updated

}

# return the results
$return

