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
        scriptPath = "C:\FastStats\scripts\episerver\MarketingAutomation"
        TransactionId = "293461305923"
        CustomProvider = "epima"
        MessageName = "285860339465 / 293461305923 / Message 1 / Test List v2 Copy of Florian"
        ListName = "285860339465 / 293461305923 / Message 1 / Test List v2 Copy of Florian"
        Password = "def"
        Username = "abc"
        RecipientsSuccessful = 4
        RecipientsValidationFailed = 0
        RecipientsUnsubscribed = 0
        RecipientsBlacklisted = 0
        RecipientsBouncedOverflow = 0
        RecipientsAlreadyInList = 0
        RecipientsFiltered = 0
        RecipientsGeneralError = 0
        ProcessId = "abc"
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
$processId = $params.ProcessId #[guid]::NewGuid()

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
# PROGRAM
#
################################################

#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

$transactionalMailingID = ( $params.MessageName -split $settings.nameConcatChar )[0]

Write-Log -message "Using the transactional mailing id $( $transactionalMailingID )"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# fill return variables
$transactionId = $transactionalMailingID
$recipients = If ( $null -eq $params.RecipientsSuccessful ) { 0 } else { $params.RecipientsSuccessful } # the feature of the parameters delivered by the upload is only supported from 2019-Q4 upwards

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"=$recipients
    "TransactionId"=$transactionId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"=$settings.providername
    
}

# return the results
$return