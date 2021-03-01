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

Good hints on PowerShell Classes and inheritance

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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$processId = $params.ProcessId #[guid]::NewGuid()
$modulename = "TRBROADCAST"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>

Add-Type -AssemblyName System.Security

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
        Write-Log -message "    $( $param ) = '$( $params[$param] )'"
    }
}


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