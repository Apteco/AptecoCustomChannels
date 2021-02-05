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
        ,[System.Net.SecurityProtocolType]::Ssl3
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
# AUTH FOR REST API
#-----------------------------------------------

# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $settings.login.user ):$( Get-SecureToPlaintext $settings.login.token )"))

# Step 3. Form the header and add the Authorization attribute to it
$script:headers = @{
    Authorization = "Basic $encodedCredentials"
}

#-----------------------------------------------
# OTHER HEADERS
#-----------------------------------------------

$contentType = "application/json; charset=utf-8" # possibly only "application/json"


#-----------------------------------------------
# CHECK SOURCES
#-----------------------------------------------

# TODO [ ] make sources available in dropdown boxes?

$sources = Invoke-Flexmail -method "GetSources" -param @{} -responseNode "sources"
$listId = ( $params.ListName -split $settings.messageNameConcatChar,3 )[2]

if ( $listId -notin $sources.id ) {
    $sourcesString = ( $sources | select @{name="concat";expression={ "$( $_.id ) ($( $_.name ))" }} ).concat -join "`n"
    $exceptionText = "List-ID $( $listId ) not found. Please use one of the following IDs without the description in the brackets:`n$( $sourcesString )" 
    Write-Log -message "Throwing Exception: $( $exceptionText )"
    throw [System.IO.InvalidDataException] $exceptionText 
    
}


#-----------------------------------------------
# IDENTIFY CUSTOM FIELDS
#-----------------------------------------------

$customFields = Invoke-Flexmail -method "GetCustomFields" -param @{} -responseNode "customFields"


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

Write-Log -message "Start to create a new file"

<#

custom fields

id                label             type
--                -----             ----
custom_salutation Custom_Salutation Text
voucher_1         Voucher_1         Text
voucher_2         Voucher_2         Text
voucher_3         Voucher_3         Text

#>

# merge fixed/standard fields with existing custom fields
$fields = $settings.uploadFields + $customFields.id

# Move file to temporary uploads folder
$source = Get-Item -Path $params.path
$destination = "$( $uploadsFolder )\$( $source.name )"
Copy-Item -path $source.FullName -Destination $destination

# Split file in parts
$t = Measure-Command {
    $fileItem = Get-Item -Path $destination
    $exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $fields -writeCount $settings.rowsPerUpload -outputDoubleQuotes $true
}

Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"


#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

$campaignId = ( $params.ListName -split $settings.messageNameConcatChar,2 )[0]
$recipientListID = $settings.masterListId

Write-Log -message "Using the recipient list $( $recipientListID )"


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

if ( $debug ) {
    $emailsParams = @{
        "mailingListIds"=[array]@($recipientListID)  #$mailingList.mailingListId
    }
    $emails = Invoke-Flexmail -method "GetEmailAddresses" -param $emailsParams
    $emails | Out-GridView
}


#-----------------------------------------------
# IMPORT RECIPIENTS VIA REST
#-----------------------------------------------

# Create an import id
$url = "$( $settings.baseREST )/contacts/imports"
$jobBody = @{
    "id" = $exportId
    "resubscribe_blacklisted_contacts" = $settings.resubscribeBlacklistedContacts
}
$jobBodyJson = ConvertTo-Json -InputObject $jobBody -Verbose -Depth 8 -Compress
$jobUrl = Invoke-RestMethod -Uri $url -Method Post -Headers $script:headers -Verbose -ContentType $contentType -Body $jobBodyJson

# Import the data
$url = "$( $settings.baseREST )/contacts/imports/$( $exportId )/records"

$exportPath = "$( $uploadsFolder )\$( $exportId )"
$partFiles = Get-ChildItem -Path "$( $exportPath )"
Write-Log -message "Uploading the data in $( $partFiles.count ) files"

# https://api.flexmail.eu/documentation/#post-/contacts/imports
$partFiles | ForEach {

    $f = $_

    # Data
    $importRecipients = [array]@( import-csv -Path "$( $f.FullName )" -Delimiter "`t" -Encoding UTF8 )

    # if the source name does not exist, Flexmail create a new one automatically
    $importSourcesName = $sources.where( { $_.id -eq $listId } ).name
    $importSources = [array]@( [PSCustomObject]@{"name"=$importSourcesName } )
    
    $recipientListID
    $importRecipients
    $importSources
    $customFields

    
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


    $uploadBodyJson = ConvertTo-Json -InputObject $uploadBody -Verbose -Depth 8 -Compress
    $importRecords = Invoke-RestMethod -Uri $url -Method Post -Headers $script:headers -Verbose -ContentType $contentType -Body $uploadBodyJson
    

} 

# Queue the import for processing
$url = "$( $settings.baseREST )/contacts/imports/$( $exportId )"
$queueBody = @{
    "status" = "queued"
}
$queueBodyJson = ConvertTo-Json -InputObject $queueBody -Verbose -Depth 8 -Compress
$queue = Invoke-RestMethod -Uri $url -Method Patch -Headers $script:headers -Verbose -ContentType $contentType -Body $queueBodyJson

# Loop the import status
Do {
    Start-Sleep -Seconds 10 # TODO [ ] put this into settings
    $status = Invoke-RestMethod -Uri $url -Method Get -Headers $script:headers -Verbose -ContentType $contentType
} while ( $status.status -eq "idle" )

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
    #"RecipientsIgnored" = $ignored
    #"RecipientsQueued" = $queued
    #"RecipientsSent" = $sent
}

# return the results
$return

