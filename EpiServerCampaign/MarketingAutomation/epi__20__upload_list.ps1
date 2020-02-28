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
        Password = "def"
        scriptPath = "C:\FastStats\scripts\episerver\MarketingAutomation"
        MessageName = "285860339465 / 293461305923 / Message 1 / Test List v2 Copy of Florian"
        EmailFieldName = "Email"
        SmsFieldName = ""
        Path = "c:\faststats\Publish\Handel\system\Deliveries\PowerShell_285860339465  293461305923  Message 1  Test List v2 Copy of Florian_98c44a82-0b13-4f70-a517-97a73c5654ec.txt"
        ReplyToEmail = ""
        Username = "abc"
        ReplyToSMS = ""
        UrnFieldName = "Kunden ID"
        ListName = "285860339465 / 293461305923 / Message 1 / Test List v2 Copy of Florian"
        CommunicationKeyFieldName = "Communication Key"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

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
$settingsFilename = "settings.json"
$moduleName = "UPLOAD"
$processId = [guid]::NewGuid()

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
$logfile = $settings.logfile
$excludedAttributes = $settings.upload.excludedAttributes
$maxWriteCount = 800
$file = "$( $params.Path )"
$recipientListString = "$( $params.ListName )"
$uploadsFolder = $settings.upload.uploadsFolder
#$recipientListUrnFieldname = $settings.upload.recipientListUrnFieldname

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


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

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
}


################################################
#
# PREPARATION & CHECKS
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

if ( !(Test-Path -Path $uploadsFolder) ) {
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

$recipientListID = ( $recipientListString -split $settings.nameConcatChar )[1]
$recipientListName = ( $recipientListString -split $settings.nameConcatChar )[3]

Write-Log -message "Using the recipient list $( $recipientListID )"


#-----------------------------------------------
# SESSION
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

# Get Urn field of this list
$urnFieldName = $settings.upload.recipientListUrnField

# Set email field
$emailFieldName = $settings.upload.recipientListEmailField

# Load attributes online
$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$recipientListID;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = [array]( $listAttributesRaw | where  { $_ -notin $excludedAttributes } )

if ( $emailFieldName -ne $urnFieldName ) {
    $listAttributes = [array]$params.UrnFieldName + $listAttributes
} 

Write-Log -message "Using these fields in list $( $listAttributes -join "," )"


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

Write-Log -message "Start to create a new file"

$t = Measure-Command {
    $fileItem = Get-Item -Path $file
    $exportId = Split-File -inputPath $fileItem.FullName `
                           -header $true `
                           -writeHeader $true `
                           -inputDelimiter "`t" `
                           -outputDelimiter "`t" `
                           -outputColumns $listAttributes `
                           -writeCount $maxWriteCount `
                           -outputDoubleQuotes $false `
                           -outputPath $uploadsFolder
}

Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds!"


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# if you have a lot of lists, then this can take a while -> better deactivating this and using the local json file instead
<#
$recipientLists = Get-EpiRecipientLists
$listColumns = $recipientLists | where { $_.id -eq $recipientListID }
#>
#$recipientLists = Get-Content -Path "$( $settings.mailings.recipientListFile )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Get all lists first
#$recipientLists = Get-EpiRecipientLists 


#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------

# Log
Write-Log -message "URN field name ""$( $urnFieldName )""!"
Write-Log -message "E-Mail field name ""$( $emailFieldName )""!"

# Go through every export file and upload in batches of 1000
$importResults = @()
Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach-Object {

    $f = $_
    
    # Load content of file
    $csv = Get-Content -Path "$( $f.FullName )" -Encoding UTF8 
    
    # Parse the file
    $csvParsed = $csv | convertfrom-csv -Delimiter "`t"
    Write-Log -message "Reading and parsing $( $f.FullName )!"

    # Create the array for the upload
    $valArr = @()
    $csv | select -skip 1 | ForEach {
        $line = $_
        $valArr += ,( $line -split "`t" )
    }
    #$valArr
    
    # Create the additional urn and email lists for the upload
    if ( $emailFieldName -eq $urnFieldName ) {
        [array]$urnContent = $csvParsed.$emailFieldName
    } else {
        [array]$urnContent = $csvParsed.($params.UrnFieldName) #$urnFieldName
    }
    [array]$urns = $urnContent
    [array]$emails = $csvParsed.$emailFieldName

    # Change the urn field name for the upload list
    $listAttributes = $listAttributes -replace $params.UrnFieldName, $urnFieldName

    # Bring all parameter together for the upload
    $paramsEpi = @(
        @{value=$recipientListID;datatype="long"}
        ,@{value=0;datatype="long"}
        ,$urns
        ,$emails
        ,$listAttributes
        ,$valArr
    )

    # Log
    Write-Log -message "Uploading $( $urns.Count ) receivers"

    # Upload data
    $importResult = Invoke-Epi -webservice "Recipient" -method "addAll3" -param $paramsEpi -useSessionId $true

    # Check the uploaded data
    # Reference to import results:
    # https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/recipientwebservice/addall3/
    for($i = 0; $i -lt $importResult.count; $i++ ) {
        $res = New-Object PSCustomObject
        $res | Add-Member -MemberType NoteProperty -Name "Urn" -Value $urns[$i]
        $res | Add-Member -MemberType NoteProperty -Name "Email" -Value $emails[$i]
        $res | Add-Member -MemberType NoteProperty -Name "Result" -Value $importResult[$i]
        $importResults += $res
    }

} 

Write-Log -message "Created $( $importResults.Count ) import results"

# Reference for status codes: https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/recipientwebservice/addall3/
$importResults | Export-Csv -Path "$( $uploadsFolder )\$( $exportId )\importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = ( $importResults | where { $_.Result -eq 0 } ).count
Write-Host "Uploaded $( $recipients ) out of $( $importResults.Count ) in the list $( $recipientListID ) - $( $recipientListName )"

# There is no id reference for the upload in Epi
$transactionId = $recipientListID

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername
    "ProcessId" = $processId

    # More information about the different status of the import
    "RecipientsSuccessful" = $recipients
    "RecipientsValidationFailed" = ( $importResults | where { $_.Result -eq 1 } ).count
    "RecipientsUnsubscribed" = ( $importResults | where { $_.Result -eq 2 } ).count
    "RecipientsBlacklisted" = ( $importResults | where { $_.Result -eq 3 } ).count
    "RecipientsBouncedOverflow" = ( $importResults | where { $_.Result -eq 4 } ).count
    "RecipientsAlreadyInList" = ( $importResults | where { $_.Result -eq 5 } ).count
    "RecipientsFiltered" = ( $importResults | where { $_.Result -eq 6 } ).count
    "RecipientsGeneralError" = ( $importResults | where { $_.Result -eq 7 } ).count

}

# return the results
$return