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
	    MessageName= "1631416 | Testmail_2"
	    abc= "def"
	    SmsFieldName= ""
	    Path= "c:\faststats\Publish\Handel\system\Deliveries\PowerShell_252060_e4ed1786-ce5d-4e51-af54-e97bb45d73a4.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Kunden ID"
	    ListName= "252060"
	    CommunicationKeyFieldName= "Communication Key"
    }
}





################################################
#
# NOTES
#
################################################


# TODO [ ] abc


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
$uploadsSubfolder = "uploads"
$settingsFilename = "settings.json"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

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
$uploadsFolder = ".\$( $uploadsSubfolder )"
$logfile = $settings.logfile


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}



################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUPLOAD" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}



################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# CHECK UPLOAD FOLDER
#-----------------------------------------------

if ( !(Test-Path -Path $uploadsFolder) ) {
    New-Item -Path $uploadsFolder -ItemType Directory
}
Set-Location -Path $uploadsFolder


#-----------------------------------------------
# CHECK SOURCES
#-----------------------------------------------

# TODO [ ] make sources available in dropdown boxes?

$sources = Invoke-Flexmail -method "GetSources" -param @{} -responseNode "sources"
$listId = ( $params.ListName -split $settings.messageNameConcatChar )[0]

if ( $listId -notin $sources.id ) {
    $sourcesString = ( $sources | select @{name="concat";expression={ "$( $_.id ) ($( $_.name ))" }} ).concat -join "`n"
    $exceptionText = "List-ID $( $listId ) not found. Please use one of the following IDs without the description in the brackets:`n$( $sourcesString )" 
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tThrowing Exception: $( $exceptionText )" >> $logfile
    throw [System.IO.InvalidDataException] $exceptionText 
    
}


#-----------------------------------------------
# IDENTIFY CUSTOM FIELDS
#-----------------------------------------------

$customFields = Invoke-Flexmail -method "GetCustomFields" -param @{} -responseNode "customFields"


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile

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

$t = Measure-Command {
    $fileItem = Get-Item -Path $params.Path
    $exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $fields -writeCount $settings.rowsPerUpload -outputDoubleQuotes $true
}

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId ) in $( $t.Seconds ) seconds!" >> $logfile


#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

#$campaignId = ( $params.MessageName -split $settings.messageNameConcatChar )[0]
$recipientListID = $settings.masterListId

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing the recipient list $( $recipientListID )" >> $logfile


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
# IMPORT RECIPIENTS
#-----------------------------------------------

# upload in batches of x
$partFiles = Get-ChildItem -Path ".\$( $exportId )"

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUploading the data in $( $partFiles.count ) files" >> $logfile

$importResults = @()
$partFiles | ForEach {

    $f = $_

    $importRecipients = [array]@( import-csv -Path "$( $f.FullName )" -Delimiter "`t" -Encoding UTF8 )

    # if the source name does not exist, Flexmail create a new one automatically
    $importSourcesName = $sources.where( { $_.id -eq $params.ListName } ).name
    $importSources = [array]@( [PSCustomObject]@{"name"=$importSourcesName } )
    
    # pack everything together
    $importParams = @{
        "mailingListId"=$recipientListID
        "emailAddressTypeItems"=@{value=$importRecipients;type="EmailAddressType"}
        "overwrite"=$settings.importSettings.overwrite
        "synchronise"=1#$settings.importSettings.synchronise
        "allowDuplicates"=$settings.importSettings.allowDuplicates
        "allowBouncedOut"=$settings.importSettings.allowBouncedOut
        "defaultLanguage"=$settings.importSettings.defaultLanguage
        "referenceField"=$settings.importSettings.referenceField
        "sources"=@{value=$importSources;type="SourcesType"}
    }
 
    $importResult = Invoke-Flexmail -method "ImportEmailAddresses" -param $importParams -customFields $customFields #-verboseCall
    $importResults += $importResult

} 

$importResults | Export-Csv -Path "$( $exportId )\00_importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUploaded the data with $($importResults.Count) import results" >> $logfile

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
$recipients = ( $importResults | where { $_.errorCode -eq 0} ).count

# put in the source id as the listname
$transactionId = $params.ListName

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

