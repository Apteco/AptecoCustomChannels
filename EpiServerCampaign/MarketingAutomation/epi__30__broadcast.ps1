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
        scriptPath = "C:\FastStats\scripts\episerver\marketingautomation"
        MessageName = "53712729219  60715369129 / 53712729219 / Apteco Test Mailing / Test List"
        abc = "def"
        ListName = "60715369129 / 53712729219 / Apteco Test Mailing / Test List"
        Password = "def"
        Username = "abc"
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
$moduleName = "BROADCAST"

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

$transactionalMailingID = ( $params.MessageName -split $settings.nameConcatChar )[1]

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing the recipient list $( $recipientListID )" >> $logfile


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# fill return variables
$transactionId = $transactionalMailingID
$recipients = 0 # TODO [ ] Fill this from the previous upload script

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$settings.providername
}

# return the results
$return