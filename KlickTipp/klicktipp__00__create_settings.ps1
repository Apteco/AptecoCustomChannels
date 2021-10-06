
################################################
#
# INPUT
#
################################################


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------

$debug = $true
$configMode = $true


################################################
#
# NOTES
#
################################################

<#

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "EMMCREATESETTINGS"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"


################################################
#
# START
#
################################################


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\emm.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# LOAD LOGGING MODULE NOW
#-----------------------------------------------

$settings = @{
    "logfile" = $logfile
}

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"


#-----------------------------------------------
# LOG THE NEW SETTINGS CREATION
#-----------------------------------------------

Write-Log -message "Creating a new settings file" -severity ( [Logseverity]::WARNING )


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$soapUsername = Read-Host "Please enter your agnitas EMM SOAP username"
$soapPassword = Read-Host -AsSecureString "Please enter your agnitas EMM SOAP password"
$soapPasswordEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$soapPassword).GetNetworkCredential().Password)

$auth = @{
    SOAP = @{
        username = $soapUsername
        password = $soapPasswordEncrypted
    }
}

#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------
<#
$previewSettings = @{
    "Type" = "Email" #Email|Sms
    "FromAddress"="info@apteco.de"
    "FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    "Subject"="Test-Subject"
}
#>

#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------
<#
$uploadSettings = @{
    "rowsPerUpload" = 80 # should be max 100 per upload
    "uploadsFolder" = $upload #"$( $scriptPath )\uploads\"
    "delimiter" = "`t" # "`t"|","|";" usw.
    "encoding" = "UTF8" # "UTF8"|"ASCII" usw. encoding for importing text file https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-6
    "excludedAttributes" = @()
}
#>

#-----------------------------------------------
# REPORT SETTINGS
#-----------------------------------------------
<#
$reportSettings = @{
    "delimiter" = ";"   # The delimiter used by TriggerDialog for report data
}
#>

#-----------------------------------------------
# MAIL NOTIFICATION SETTINGS
#-----------------------------------------------
<#
$smtpPass = Read-Host -AsSecureString "Please enter the SMTP password"
$smtpPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$smtpPass).GetNetworkCredential().Password)

$mail = @{
    smtpServer = "smtp.example.com"
    port = 587
    from = "admin@example.com"
    username = "admin@example.com"
    password = $smtpPassEncrypted
}
#>


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{

    # General settings
    "nameConcatChar" =   " | "
    "logfile" = $logfile                                    # logfile
    "providername" = "agnitasEMM"                        # identifier for this custom integration, this is used for the response allocation

    # Security settings
    "aesFile" = "$( $scriptPath )\aes.key"
    #"sessionFile" = "$( $scriptPath )\session.json"         # name of the session file
    #"ttl" = 25                                              # Time to live in minutes for the current session, normally 30 minutes for TriggerDialog
    #"encryptToken" = $true                                  # $true|$false if the session token should be encrypted

    # Network settings
    "changeTLS" = $true
    "contentType" = "application/json;charset=utf-8"

    # Triggerdialog settings
    "baseSOAP" = "https://ws.agnitas.de/2.0/"
    "base" = "xxx"
    #"customerId" = ""
    #"createCampaignsWithDate" = $true

    # sub settings categories
    "authentication" = $auth
    #"dataTypes" = $dataTypeSettings
    #"preview" = $previewSettings
    #"upload" = $uploadSettings
    #"mail" = $mail
    #"report" = $reportSettings
    
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# rename settings file if it already exists
If ( Test-Path -Path $settingsFile ) {
    $backupPath = "$( $settingsFile ).$( $timestamp.ToString("yyyyMMddHHmmss") )"
    Write-Log -message "Moving previous settings file to $( $backupPath )" -severity ( [Logseverity]::WARNING )
    Move-Item -Path $settingsFile -Destination $backupPath
} else {
    Write-Log -message "There was no settings file existing yet"
}

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path $settingsFile -Encoding UTF8



################################################
#
# DO SOME MORE SETTINGS DIRECTLY
#
################################################

# Load the settings from the local json file
. ".\bin\load_settings.ps1"


#-----------------------------------------------
# CHECK LOGIN
#-----------------------------------------------



#-----------------------------------------------
# CREATE SOME TAGS
#-----------------------------------------------

# Create AptecoOrbit Tag
