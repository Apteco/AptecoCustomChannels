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
        ProcessId = "1088d463-c20b-43d5-9630-1cfd0501d01f"
        MessageName = "34362 / 30449 / Kampagne A / Aktiv / UPLOAD"
        Username = "a"
        TransactionId = "1088d463-c20b-43d5-9630-1cfd0501d01f"
        CustomProvider = "TRUPLOAD"
        UrnFieldName = "Kunden ID"
        Password = "b"
        ListName = "34362 / 30449 / Kampagne A / Aktiv / UPLOAD"
        Path = "d:\faststats\Publish\Handel\system\Deliveries\PowerShell_34362  30449  Kampagne A  Aktiv  UPLOAD_52af38bc-9af1-428e-8f1d-6988f3460f38.txt.converted"
        scriptPath = "D:\Scripts\TriggerDialog\v2"
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
$modulename = "TRBROADCAST"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Overriding the process ID in the broadcast script so upload and broadcast have the same process ID
$processId = $params.ProcessId

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


###############################################
#
# PROGRAM
#
################################################


Write-Log -message "Nothing to do in the broadcast script"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [x] Forward the right numbers here

# count the number of successful upload rows
$recipients = $params.RecipientsQueued #$upload.count

# put in the source id as the listname
$transactionId = $processId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$params.CorrelationId #$transactionId
    "CustomProvider"=$moduleName
    "ProcessId" = $processId
}

# return the results
$return