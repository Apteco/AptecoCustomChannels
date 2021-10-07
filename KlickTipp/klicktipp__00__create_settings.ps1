
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
$modulename = "KTCREATESETTINGS"

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
if(Test-Path -LiteralPath "$( $settingsFile )" -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\klicktipp.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath "$( $logfile )" -IsValid ) {
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

# TODO [ ] ask for a password
#$username = Read-Host -Prompt "Please enter your klicktipp username" 
#$password = Read-Host -Prompt "Please enter your klicktipp password" -AsSecureString


$passwordEncrypted = Get-PlaintextToSecure ([System.Management.Automation.PSCredential]::new("dummy",$password).GetNetworkCredential().Password)

$auth = @{
    "username" = $username          # A shared secret for authentication.
    "password" = $passwordEncrypted                   # A shared secret used for signing the JWT you generated.   
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

$uploadSettings = @{
    klickTippIdField = "subscriberId"
    #"rowsPerUpload" = 80 # should be max 100 per upload
    #"uploadsFolder" = $upload #"$( $scriptPath )\uploads\"
    #"delimiter" = "`t" # "`t"|","|";" usw.
    #"encoding" = "UTF8" # "UTF8"|"ASCII" usw. encoding for importing text file https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-6
    #"excludedAttributes" = @()
}


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
    "providername" = "klicktipp"                        # identifier for this custom integration, this is used for the response allocation
    "sqliteDB" = "$( $scriptPath )\klicktipp.sqlite"

    # Security settings
    "aesFile" = "$( $scriptPath )\aes.key"

    # Network settings
    "changeTLS" = $true
    "contentType" = "application/json;charset=utf-8"

    # API settings
    "base" = "https://api.klicktipp.com"

    # sub settings categories
    "authentication" = $auth
    #"preview" = $previewSettings
    "upload" = $uploadSettings
    #"mail" = $mail
    #"report" = $reportSettings
    
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# rename settings file if it already exists
If ( Test-Path -Path "$( $settingsFile )" ) {
    $backupPath = "$( $settingsFile ).$( $timestamp.ToString("yyyyMMddHHmmss") )"
    Write-Log -message "Moving previous settings file to $( $backupPath )" -severity ( [Logseverity]::WARNING )
    Move-Item -Path "$( $settingsFile )" -Destination "$( $backupPath )"
} else {
    Write-Log -message "There was no settings file existing yet"
}

# create json object
$json = $settings | ConvertTo-Json -Depth 99 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8



################################################
#
# DO SOME MORE SETTINGS DIRECTLY
#
################################################


#-----------------------------------------------
# RELOAD SETTINGS
#-----------------------------------------------

# Load the settings from the local json file
. ".\bin\load_settings.ps1"


#-----------------------------------------------
# CHECK LOGIN
#-----------------------------------------------

# Do the preparation
. ".\bin\preparation.ps1"

# Load fields as test of API
try {

    $restParams = $defaultRestParams + @{
        "Method" = "Get"
        "Uri" = "$( $settings.base )/field.json"
    }
    $fieldsRaw = Invoke-RestMethod @restParams

    Write-Log -message "Looks like the API access has worked"

    Write-Log -message "This account has the following fields:"

    # Bring fields into right order
    $fields = [ordered]@{}
    $fieldsRaw.psobject.Properties | ForEach {
        Write-Log -message "    $( $_.name )"
    }

} catch {

    Write-Log -message "API access failed with this message: $( $_ )" -severity ([Logseverity]::ERROR)
    Write-Log -message "Exiting the script now" -severity ([Logseverity]::WARNING)
    exit 1

}


#-----------------------------------------------
# CREATE SOME TAGS IF NOT EXISTING
#-----------------------------------------------

# Define tags
$tagsToCreate = @("AptecoOrbit","TTT","ABC.DEF")

# Load existing tags and transform them
$restParams = $defaultRestParams + @{
    "Method" = "Get"
    "Uri" = "$( $settings.base )/tag.json"
}
$tagsRaw = Invoke-RestMethod @restParams
$tags = ( $tagsRaw.psobject.members | where { $_.MemberType -eq "NoteProperty" } ).Value

# Check and create tags, if they do not exist
$tagsToCreate | ForEach {
    $tag = $_
    If ( $tags -notcontains $tag ) {
        $restParams = $defaultRestParams + @{
            "Method" = "Post"
            "Uri" = "$( $settings.base )/tag.json"
            "Body" = @{
                "name" = $tag
            } | ConvertTo-Json -Depth 99
        }
        $createdTag = Invoke-RestMethod @restParams        
        Write-Log -message "Created tag '$( $tag )' with id '$( $createdTag )'"
    }
}


################################################
#
# CREATE FOLDERS IF NEEDED
#
################################################

# Creating the lib folder for the sqlite stuff
$libFolder = ".\$( $libSubfolder )"
if ( !(Test-Path -Path "$( $libFolder )") ) {
    Write-Log -message "lib folder '$( $libFolder )' does not exist. Creating the folder now!"
    New-Item -Path "$( $libFolder )" -ItemType Directory
}


################################################
#
# DOWNLOAD AND INSTALL THE SQLITE PACKAGE
#
################################################

$sqliteDll = "System.Data.SQLite.dll"

if ( $libExecutables.Name -notcontains $sqliteDll ) {

    Write-Log -message "A browser page is opening now. Please download the system.data.sqlite package from the site like 'sqlite-netFx46-binary-bundle-x64-2015-1.0.115.0.zip'"
    Write-Log -message "Please unzip the file and put it into the lib folder"
    
    <#
    http://system.data.sqlite.org/downloads/1.0.115.0/sqlite-netFx46-binary-bundle-x64-2015-1.0.115.0.zip
    #>
    
    Start-Process "http://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki"
    
    # Wait for key
    Write-Host -NoNewLine 'Press any key if you have put the files there';
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

}


################################################
#
# PREPARE SQLITE DATABASE
#
################################################


# Create database if it does not exist
If ( -not (Test-Path -Path "$( $settings.sqliteDB )" ) ) {

    # Load functions and new assemblies
    . ".\bin\load_functions.ps1"

    Write-Log -message "Preparing sqlite database"

    #-----------------------------------------------
    # ESTABLISHING CONNECTION TO SQLITE
    #-----------------------------------------------

    # Load assemblies for sqlite
    #$assemblyFileSqlite = $libExecutables.Where({$_.name -eq "System.Data.SQLite.dll"})
    #[Reflection.Assembly]::LoadFile($assemblyFileSqlite.FullName)
    $connection = [System.Data.SQLite.SQLiteConnection]::new()

    # Create a new connection to a database (in-memory or file)
    # If the database does not exist, it will be created automatically
    #$connection.ConnectionString = "Data Source=:memory:;Version=3;New=True;"
    $connection.ConnectionString = "Data Source=$( $settings.sqliteDb );Version=3;New=True;"
    $connection.Open()

    # Load more extensions for sqlite, e.g. the Interop which includes json1
    #$connection.EnableExtensions($true)
    #$assemblyFileInterop = Get-Item -Path ".\sqlite-netFx46-binary-x64-2015-1.0.113.0\SQLite.Interop.dll"
    #$connection.LoadExtension($assemblyFileInterop.FullName, "sqlite3_json_init");

    # Create a new command which can be reused
    $command = [System.Data.SQLite.SQLiteCommand]::new($connection)


    #-----------------------------------------------
    # CREATE TABLES FOR STORING KLICKTIPP DATA
    #-----------------------------------------------

    <#
    # Drop a table, if exists
    $command.CommandText = "DROP TABLE IF EXISTS items";
    [void]$command.ExecuteNonQuery();
    #>

    # Create a new table for object items, if it is not existing
    $command.CommandText = @"
    CREATE TABLE IF NOT EXISTS items (
        id TEXT
        ,object TEXT 
        ,ExtractTimestamp TEXT
        ,properties TEXT
    )
"@
    [void]$command.ExecuteNonQuery();

    $command.Dispose()
    $connection.Dispose()

} 



################################################
#
# INITIAL LOAD OF DATA
#
################################################

$decision = $Host.UI.PromptForChoice('Loading all klicktipp receivers now', 'Are you sure you want to proceed?', @('&Yes'; '&No'), 1)

If ( $decision -eq "0" ) {

    . ".\bin\load_subscribers.ps1"

}


################################################
#
# END STUFF
#
################################################

# Do the end stuff
. ".\bin\end.ps1"


################################################
#
# WAIT FOR KEY
#
################################################

Write-Host -NoNewLine 'Press any key to continue...';
$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');

