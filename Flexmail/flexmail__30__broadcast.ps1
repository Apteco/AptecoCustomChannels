################################################
#
# NOTES
#
################################################
#
# In diesem Skript müssen keine Anpassungen vorgenommen werden.
#


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

                # Integration Parameters
                scriptPath= "C:\FastStats\scripts\flexmail"
                settingsFile = "C:\Users\Florian\Documents\GitHub\AptecoPrivateCustomChannels\eLettershop\settings.json"

                # Parameters coming from PeopleStage
                MessageName= "1631416 | Testmail_2"
                abc= "def"
                ListName= "252060"
                Password= "def"
                Username= "abc"

                # Coming from Upload script
                RecipientsSent = 4

        }
}


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
$moduleName = "FLXBRDCST"
$processId = $params.ProcessId #[guid]::NewGuid()

if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}


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
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}



################################################
#
# PROGRAM
#
################################################


#"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUsing the recipient list $( $recipientListID )" >> $logfile

#-----------------------------------------------
# RECIPIENT LIST ID
#-----------------------------------------------

#$campaignId = ( $params.ListName -split $settings.messageNameConcatChar,2 )[0]
#Write-log -message "Using the campaign id '$( $campaignId )'"
Write-log -message "Nothing to do in broadcast script"


#-----------------------------------------------
# COUNT THE NO OF ROWS
#-----------------------------------------------


#$lines = Count-Rows -inputPath $f -header $true


#-----------------------------------------------
# RETURN VALUES TO PEOPLESTAGE
#-----------------------------------------------


# TODO [x] this is only a workaround until the handover from the return upload hashtable to the broadcast is working
$recipients = $params.RecipientsSent

# return the campaign id because this will be the reference for the response data
#$transactionId = $campaignId

# build return object
$return = [Hashtable]@{
    "Recipients" = $recipients
    "TransactionId" = $campaignId
    "CustomProvider" = $moduleName
    "ProcessId" = $processId
}

# return the results
$return


