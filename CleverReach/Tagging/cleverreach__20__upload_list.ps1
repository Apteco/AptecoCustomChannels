
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

        # PeopleStage Native Parameters
        EmailFieldName = "email"
        TransactionType = "Replace"
        Password = "b"
        MessageName = "GV.Test"
        SmsFieldName = ""
        Path = "D:\Apteco\Publish\GV\system\Deliveries\PowerShell_GV.Test_bea06b6d-8842-4f17-a1e0-2a9ca114ba63.txt"
        ReplyToEmail = ""
        Username = "a"
        ReplyToSMS = ""
        UrnFieldName = "Con Acc Id"
        ListName = "GV.Test"
        CommunicationKeyFieldName = "Communication Key"

        # PeopleStage Integration Parameters
        scriptPath = "D:\Scripts\CleverReach\Tagging"
        uploadType = "batch"

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
$functionsSubfolder = "functions"
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "CLVRUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
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
# FUNCTIONS & ASSEMBLIES
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
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.upload.uploadsFolder

$foldersToCheck = @(
    $uploadsFolder
    ".\$( $libSubfolder )"
)

$foldersToCheck | ForEach {
    $checkFolder = $_
    if ( !(Test-Path -Path $checkFolder) ) {
        Write-Log -message "Folder $( $checkFolder ) does not exist. Creating the folder now!"
        New-Item -Path "$( $checkFolder )" -ItemType Directory
    }
}


#-----------------------------------------------
# FORWARDING PARAMETERS
#-----------------------------------------------


<#

JUST FORWARDING A FEW PARAMETERS TO THE BROADCAST TO DO EVERYTHING THERE

#>

Write-Log -message "Just forwarding parameters to broadcast"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = 0 #$upload.count

# put in the source id as the listname
$transactionId = $processId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
    "CustomProvider"=$moduleName
    "ProcessId" = $processId
    "EmailFieldName"= $params.EmailFieldName
    "Path"= $params.Path
    "UrnFieldName"= $params.UrnFieldName
}

# return the results
$return

