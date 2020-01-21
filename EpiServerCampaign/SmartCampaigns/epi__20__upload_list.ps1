
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
$maxWriteCount = 2 # TODO [ ] set this to $settings.rowsPerUpload
$uploadsFolder = $settings.uploadsFolder


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Add assemblies
#Add-Type -AssemblyName System.Data #, System.Text.Encoding

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
# SMART CAMPAIGN ID
#-----------------------------------------------

# cut out the smart campaign id or mailing id
$messageName = $params.MessageName
$smartCampaignID = $messageName -split $settings.nameConcatChar | select -First 1


#-----------------------------------------------
# SESSION
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$settings.masterListId;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | where { $_ -notin $excludedAttributes }


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile
$fileItem = Get-Item -Path $params.Path

$exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $listAttributes -writeCount $maxWriteCount -outputDoubleQuotes $false -outputPath $uploadsFolder

#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId )!" >> $logfile


#-----------------------------------------------
# NEW WAVE
#-----------------------------------------------

$waveId = Invoke-Epi -webservice "ClosedLoop" -method "prepareNewWave" -param @($smartCampaignID) -useSessionId $true


#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------

$importResults = 0
Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach {

    $f = $_
    
    $csv = Get-Content -Path "$( $f.FullName )" -Encoding UTF8 
    
    $valArr = @()
    $csv | select -skip 1 | ForEach {
        $line = $_
        $valArr += ,( $line -split "`t" )
        $importResults += 1
    }

    $paramsEpi = @(
         @{value=$waveId;datatype="long"}
        ,$listAttributes
        ,$valArr
    )

    Invoke-Epi -webservice "ClosedLoop" -method "importRecipients" -param $paramsEpi -useSessionId $true

} 
<#
Invoke-Epi -webservice "ClosedLoop" -method "importFinishedAndScheduleMailing" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true

# TODO [ ] put this in the broadcast script where the mailing id should be tracked
Do {
    Start-Sleep -Seconds $settings.waitSecondsForMailingCreation
    $mailingId = Invoke-Epi -webservice "ClosedLoop" -method "getMailingIdByWaveId" -param @(@{value=$waveId;datatype="long"}) -useSessionId $true
} until ( $mailingId-ne 0 )
 #>

################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = $importResults

# put in the source id as the listname
$transactionId = $waveId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

