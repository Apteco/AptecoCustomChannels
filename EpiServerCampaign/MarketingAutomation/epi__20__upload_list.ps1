<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

#>

################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

<#
$params = [hashtable]@{
    "ReplyToSMS"=""
    "EmailFieldName"= "Email"
    "Username"= "abc"
    "MessageName"= ""
    "ReplyToEmail"= ""
    "UrnFieldName"="KU-Id"
    "Password"= "def"
    "ListName"= "286159604975 / Loyaltyprogramm - Willkommen / "
    "TransactionType"= "Replace"
    "Path"= "\\APTECO-P-FAST01.buenting.de\Publish\buenting\system\Deliveries\PowerShell_286159604975  Loyaltyprogramm - Willkommen  _ef4fe146-7bc0-4bbc-9498-ac40721c4a5e.txt"
    "SmsFieldName"= ""
    "CommunicationKeyFieldName"= "Communication Key"
}

#>


################################################
#
# NOTES
#
################################################


# TODO [x] bring in a possibility to duplicate a list -> in a separate powershell file


################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
<#
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
#>
$scriptPath = "D:\Apteco\Scripts\episerver_marketing_automation"
Set-Location -Path $scriptPath

################################################
#
# SETTINGS
#
################################################


# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json

$excludedAttributes = @("Opt-in Source","Opt-in Date","Created","Modified","Erstellt am","Geändert am","Opt-in-Quelle","Opt-in-Datum")
$maxWriteCount = 2
$logfile = $settings.logfile
$file = "$( $params.Path )"
$recipientListString = "$( $params.ListName )"


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

################################################
#
# FUNCTIONS
#
################################################

# load all functions
. ".\epi__00__functions.ps1"


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
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
# RECIPIENT LIST ID
#-----------------------------------------------

# TODO [ ] check this name concatenation

$recipientListID = $recipientListString -split $settings.nameConcatChar | select -First 1

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

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile$t = Measure-Command {    $fileItem = Get-Item -Path $file    $exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $listAttributes -writeCount $maxWriteCount -outputDoubleQuotes $false}"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId ) in $( $t.Seconds ) seconds!" >> $logfile


#-----------------------------------------------
# LISTS
#-----------------------------------------------

# if you have a lot of lists, then this can take a while -> better deactivating this and using the local json file instead
<#
$recipientLists = Get-EpiRecipientLists
$listColumns = $recipientLists | where { $_.id -eq $recipientListID }
#>
$recipientLists = Get-Content -Path "$( $scriptPath )\$( $settings.recipientListFile )" -Encoding UTF8 -Raw | ConvertFrom-Json

#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------


# upload in batches of 1000

[array]$urnFieldName = ( $recipientLists | where { $_.id -eq $recipientListID } ).'ID-Feld' #@(,$recipientLists.'ID-Feld')[array]$emailFieldName = "email" #@(,"email")
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tURN field name $( $urnFieldName )!" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tE-Mail field name $( $emailFieldName )!" >> $logfile


$importResults = @()
Get-ChildItem -Path ".\$( $exportId )" | ForEach {

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

$importResults | Export-Csv -Path "$( $scriptPath )\$( $exportId )\importresults.csv" -Encoding UTF8 -NoTypeInformation -Delimiter "`t"

$recipients = $importResults | where { $_.Result -ne 0} | Select Urn
$transactionId = "123"

[Hashtable]$return = @{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

$return
