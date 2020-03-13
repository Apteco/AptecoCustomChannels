
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
	    EmailFieldName= "Email"
	    TransactionType= "Replace"
	    Password= "def"
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns"
	    MessageName= "275324762694 / Test: Smart Campaign Mailing"
	    abc= "def"
	    SmsFieldName= ""
	    Path= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns\Optivo_Test Apteco_66ce38fd-191a-48b9-885f-eca1bac20803.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Urn"
	    ListName= "252060"
	    CommunicationKeyFieldName= "Communication Key"
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

TODO [ ] implement more logging

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
$excludedAttributes = $settings.excludedAttributes
$maxWriteCount = $settings.rowsPerUpload
$uploadsFolder = $settings.uploadsFolder
$urnFieldName = $settings.urnFieldName
$campaignType = $settings.campaignType

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
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
        Write-Log -message "    $( $param ): $( $params[$param] )"
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
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# SMART CAMPAIGN ID
#-----------------------------------------------

# cut out the smart campaign id or mailing id
$messageName = $params.MessageName
$smartCampaignID = $messageName -split $settings.nameConcatChar | select -First 1

Write-Log -message "Recognised the smart campaign id $( $smartCampaignID )"


#-----------------------------------------------
# SESSION
#-----------------------------------------------

Write-Log -message "Opening a new session in EpiServer valid for $( $settings.ttl )"

Get-EpiSession


#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS
#-----------------------------------------------

Write-Log -message "Checking the campaign id"

$campaigns = Get-EpiCampaigns -campaignType $campaignType

if ($campaigns -notcontains $smartCampaignID) {
    Write-Log -message "No valid campaign/mailing ID"  
    throw [System.IO.InvalidDataException] "No valid campaign/mailing ID"  
} else {
    Write-Log -message "Campaign ID seems to be valid"
}



#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

Write-Log -message "Checking attributes for $( $settings.masterListId )"

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$settings.masterListId;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true

Write-Log -message "Got back $( $listAttributesRaw )"

#$listAttributes = $listAttributesRaw | where { $_ -notin $excludedAttributes }
$listAttributes = [array]$params.UrnFieldName + [array]( $listAttributesRaw | where  { $_ -notin $excludedAttributes } )

Write-Log -message "Filtered the attributes. Those fields are left: $( $listAttributes )"


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

$fileItem = Get-Item -Path $params.Path

Write-Log -message "Loading the file $( $fileItem.FullName )"

$exportId = ""
$t = Measure-Command {

    # TODO [x] put in the measure command from the marketing automation module
    $exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $listAttributes -writeCount $maxWriteCount -outputDoubleQuotes $false -outputPath $uploadsFolder

}

Write-Log -message "Done with export id $( $exportId ) in $( $t.Seconds ) seconds"


#-----------------------------------------------
# NEW WAVE
#-----------------------------------------------

Write-Log -message "Creating a new wave for $( $smartCampaignID )"

$waveId = Invoke-Epi -webservice "ClosedLoop" -method "prepareNewWave" -param @($smartCampaignID) -useSessionId $true

Write-Log -message "Got back wave id $( $waveId )"


#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------

Write-Log -message "Beginning to load the splitted file now"

# Loading all splitted and filtered files
$importResults = 0
Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach {

    # Creating the file object
    $f = $_
    
    Write-Log -message "Loading $( $f.FullName )"

    # Loading the part file
    $csv = Get-Content -Path "$( $f.FullName )" -Encoding UTF8 
    
    # Creating the array without the header
    $valArr = @()
    $csv | Select-Object -skip 1 | ForEach-Object {
        $line = $_
        $valArr += ,( $line -split "`t" )
        $importResults += 1
    }

    # Change the urn field name for the upload list
    $listAttributes = $listAttributes -replace $params.UrnFieldName, $urnFieldName

    Write-Log -message "Changed the urn field name from $( $params.UrnFieldName ) to $urnFieldName"
    Write-Log -message "Those fields are left to upload: $( $listAttributes )"

    # Bring all parameter together for the upload
    $paramsEpi = @(
         @{value=$waveId;datatype="long"}
        ,$listAttributes
        ,$valArr
    )

    # Upload data
    Invoke-Epi -webservice "ClosedLoop" -method "importRecipients" -param $paramsEpi -useSessionId $true

    Write-Log -message "File part upload done. Total $( $importResults )"

} 

Write-Log -message "Whole upload done. Uploaded $( $importResults )"

# Schedule the mailing
# TODO [ ] remove this after the test with release 2019-Q4
Invoke-Epi -webservice "ClosedLoop" -method "importFinishedAndScheduleMailing" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true

Write-Log -message "Triggered the wave now and created a mailing."
switch ( $settings.syncType ) {

    "async" {
        Write-Log -message "async upload -> The upload is done now and the mailing id will be enriched later"
    }

    "sync" {
        Write-Log -message "synced upload -> loop until mailing id is send back"
    }
}

################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [x] Implement Write-Host for messages in the system health monitor and in the deliveryjobsummary table in the ws-database 

# count the number of successful upload rows
$recipients = $importResults

# put in the source id as the listname
$transactionId = $waveId

Write-Host "Uploaded $( $recipients ) records with wave id $( $transactionId )"

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$settings.providername
    "ProcessId" = $processId
}

# return the results
$return

