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
	    scriptPath= "C:\FastStats\scripts\TriggerDialog"
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
}

$scriptPath = "$( $params.scriptPath )"
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
# CREATE PAYLOAD
#-----------------------------------------------

$payload = $settings.defaultPayload.PsObject.Copy()
$payload.iat = Get-Unixtime
$payload.exp = ( (Get-Unixtime) + 3600 )


#-----------------------------------------------
# CREATE JWT AND AUTH URI
#-----------------------------------------------

$jwt = Create-JWT -headers $settings.headers -payload $payload -secret ( Get-SecureToPlaintext -String $settings.login.secret )
$authUri = "$( $settings.base )/triggerdialog/sso/auth?jwt=$( $jwt )"
#$authUri

#-----------------------------------------------
# CHECK UPLOAD FOLDER
#-----------------------------------------------

if ( !(Test-Path -Path $uploadsSubfolder) ) {
    New-Item -Path ".\$( $uploadsSubfolder )" -ItemType Directory
}
Set-Location -Path $uploadsSubfolder


#-----------------------------------------------
# CHECK SOURCES
#-----------------------------------------------

# TODO [ ] make sources available in dropdown boxes?
# TODO [ ] Check Print Nodes and Campaigns


#-----------------------------------------------
# IDENTIFY CUSTOM FIELDS
#-----------------------------------------------

# TODO [ ] if needed, create a updateCampaignVariableRequest to add new variables

#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile

# TODO [ ] implement the split file method for the incoming data

$t = Measure-Command {
    $fileItem = Get-Item -Path $params.Path
    $exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $fields -writeCount $settings.rowsPerUpload -outputDoubleQuotes $true
}

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId ) in $( $t.Seconds ) seconds!" >> $logfile



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

    # TODO [ ] implement the TriggerDialog Campaign Trigger method and check the response data

} 


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUploaded the data with $($importResults.Count) import results" >> $logfile


#-----------------------------------------------
# RETURN VALUES TO PEOPLESTAGE
#-----------------------------------------------

$recipients = $importResults.count # | where { $_.Result -ne 0} | Select Urn
$transactionId = $params.ListName #$campaignId

[Hashtable]$return = @{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

$return
