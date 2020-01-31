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
        scriptPath = "C:\FastStats\scripts\episerver\marketingautomation"
	    MessageName= "60715369129 / 53712729219 / Apteco Test Mailing / Test List"
	    abc= "def"
	    SmsFieldName= ""
	    Path= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns\Optivo_Test Apteco_66ce38fd-191a-48b9-885f-eca1bac20803.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Urn"
	    ListName= "60715369129 / 53712729219 / Apteco Test Mailing / Test List"
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
$maxWriteCount = 2 # TODO [ ] change this later to a higher number
$file = "$( $params.Path )"
$recipientListString = "$( $params.ListName )"
$uploadsFolder = $settings.upload.uploadsFolder

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
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t$( $moduleName )" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile

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
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

$recipientListID = ( $recipientListString -split $settings.nameConcatChar )[0]

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing the recipient list $( $recipientListID )" >> $logfile


#-----------------------------------------------
# SESSION
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$recipientListID;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true

$listAttributes = $listAttributesRaw | where  { $_ -notin $excludedAttributes }

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing these fields in list $( $listAttributes -join "," )" >> $logfile


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile

$t = Measure-Command {
    $fileItem = Get-Item -Path $file
    $exportId = Split-File -inputPath $fileItem.FullName
                            -header $true
                            -writeHeader $true
                            -inputDelimiter "`t"
                            -outputDelimiter "`t"
                            -outputColumns $listAttributes
                            -writeCount $maxWriteCount
                            -outputDoubleQuotes $false
                            -outputPath $uploadsFolder
}

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId ) in $( $t.Seconds ) seconds!" >> $logfile


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# if you have a lot of lists, then this can take a while -> better deactivating this and using the local json file instead
<#
$recipientLists = Get-EpiRecipientLists
$listColumns = $recipientLists | where { $_.id -eq $recipientListID }
#>
$recipientLists = Get-Content -Path "$( $settings.mailings.recipientListFile )" -Encoding UTF8 -Raw | ConvertFrom-Json

#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------

# 

[array]$urnFieldName = ( $recipientLists | where { $_.id -eq $recipientListID } ).'ID-Feld' #@(,$recipientLists.'ID-Feld')
[array]$emailFieldName = "email" #@(,"email")
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tURN field name ""$( $urnFieldName )""!" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tE-Mail field name ""$( $emailFieldName )""!" >> $logfile

# Go through every export file and upload in batches of 1000
$importResults = @()
Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach-Object {

    $f = $_
    
    $csv = Get-Content -Path "$( $f.FullName )" -Encoding UTF8 
    $csvParsed = $csv | convertfrom-csv -Delimiter "`t"
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tReading and parsing $( $f.FullName )!" >> $logfile


    $valArr = @()
    $csv | select -skip 1 | ForEach {
        $line = $_
        $valArr += ,( $line -split "`t" )
    }
    #$valArr
    
    [array]$urns = $csvParsed.$urnFieldName
    [array]$emails = $csvParsed.$emailFieldName

    $paramsEpi = @(
        @{value=$recipientListID;datatype="long"}
        ,@{value=0;datatype="long"}
        ,$urns
        ,$emails
        ,$listAttributes
        ,$valArr
    )

    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUploading $( $urns.Count ) receivers" >> $logfile

    $importResult = Invoke-Epi -webservice "Recipient" -method "addAll3" -param $paramsEpi -useSessionId $true

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

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCreated $( $importResults.Count ) import results" >> $logfile

$importResults | Export-Csv -Path "$( $uploadsFolder )\$( $exportId )\importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = $importResults | where { $_.Result -ne 0} | Select Urn

# There is no id reference for the upload in Epi
$transactionId = $recipientListID

# return object
[Hashtable]$return = @{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$settings.providername
}

# return the results
$return