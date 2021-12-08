
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
# LOAD DLL SETTINGS
#-----------------------------------------------

# Load some dll settings first
. ".\bin\load_database_dll.ps1"


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


#-----------------------------------------------
# ASK FOR DATABASE
#-----------------------------------------------

Write-Log -message "Which database do you want to use?"
$dbType = [psdb].GetEnumNames() | Out-GridView -PassThru
Write-log -message "Using '$( $dbType )'"


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

# TODO [x] ask for a password
$username = Read-Host -Prompt "Please enter your klicktipp username" 
$password = Read-Host -Prompt "Please enter your klicktipp password" -AsSecureString

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

$settings = [Hashtable]@{

    # General settings
    "nameConcatChar" =   " | "
    "logfile" = $logfile                                    # logfile
    "providername" = "klicktipp"                        # identifier for this custom integration, this is used for the response allocation
    "dbType" = $dbType

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

#-----------------------------------------------
# ADD DB SETTINGS
#-----------------------------------------------

switch ($dbtype) {

    { $_ -eq [psdb]::POSTGRES } { 

        $postgresConnString = Read-Host -Prompt "Please enter the connection string similar like 'Host=localhost;Port=5432;Username=postgres;Password=xxx;Database=postgres'" 
        $postgresConnStringEncrypted = Get-PlaintextToSecure $postgresConnString

        $settings.add("postgresDll","Npgsql.dll")
        $settings.add("postgresSchema","apt")
        $settings.add("postgresTypename","aptrowtype")
        $settings.add("postgresConnString",$postgresConnStringEncrypted)

     }

    # Otherwise just use sqlite
    Default {

        $settings.add("sqliteDB", "$( $scriptPath )\klicktipp.sqlite")
        $settings.add("sqliteDll", "System.Data.SQLite.dll")

    }

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
$tagsToCreate = @("AptecoOrbit") #,"TTT","ABC.DEF")

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
# DOWNLOAD AND INSTALL THE DLL FILES
#
################################################


#-----------------------------------------------
# ADD DB SETTINGS
#-----------------------------------------------

switch ($dbtype) {

    { $_ -eq [psdb]::POSTGRES } { 

        $postgresDll = $settings.postgresDll

        # TODO [ ] needs to be filled with postgres step by step download from nuget

        <#

        These files from nuget worked

        FileDescription                        CompanyName           FileVersionRaw
        ---------------                        -----------           --------------
        Microsoft.Bcl.AsyncInterfaces          Microsoft Corporation 4.700.20.21406
        Npgsql                                 Npgsql                4.0.12.0
        System.Buffers                         Microsoft Corporation 4.6.28619.1
        System.Memory                          Microsoft Corporation 4.6.28619.1
        System.Numerics.Vectors                Microsoft Corporation 4.6.26515.6
        System.Runtime.CompilerServices.Unsafe Microsoft Corporation 4.700.20.12001
        System.Text.Encodings.Web              Microsoft Corporation 4.700.21.11602
        System.Text.Json                       Microsoft Corporation 4.700.19.46214
        System.Threading.Tasks.Extensions      Microsoft Corporation 4.6.28619.1
        System.ValueTuple                      Microsoft Corporation 4.6.26515.6

        #>

     }

    # Otherwise just use sqlite
    Default {

        $sqliteDll = $settings.sqliteDll

        if ( $libExecutables.Name -notcontains $sqliteDll ) {

            # Temporary destination for download
            $tempfolderDestination = "$( $env:TEMP )/$( [guid]::NewGuid().toString() )"
            $tempfileDestination = "$( $tempfolderDestination ).nupkg"
            
            if ( $libDlls.Name -notcontains $sqliteDll ) {
            
                Write-Log -message "The sqlite package will be downloaded now"
                
                # Download and unzip the latest package
                Invoke-RestMethod -Uri "https://www.nuget.org/api/v2/package/Stub.System.Data.SQLite.Core.NetFramework" -OutFile $tempfileDestination
                Expand-Archive -Path $tempfileDestination -DestinationPath $tempfolderDestination
            
                # Load nuspec
                $nuspecFile = Get-ChildItem -Path $tempfolderDestination -Filter  "*.nuspec" | Select -first 1 | Get-Content -Encoding utf8
                $nuspec = [xml]$nuspecFile
                $metadata = $nuspec.package.metadata
            
                # Confirm you read the licence details
                Start-Process $metadata.licenseUrl
                $decision = $Host.UI.PromptForChoice("Confirmation", "Can you confirm you read '$( $metadata.licenseUrl )' that just opened?", @('&Yes'; '&No'), 1)
            
                If ( $decision -eq "0" ) {
            
                    # Means yes and proceed
                    
                    # Destination
                    $libDestination = "$( $libFolder )/$( $metadata.id )_$( $metadata.version )"
                    New-Item -Path $libDestination -ItemType Directory
            
                    # Choose the .net archive
                    $nugetLib = "$( $tempfolderDestination )\lib"
                    $nugetBuild = "$( $tempfolderDestination )\build"
                    $netVersion = Get-ChildItem -Path $nugetLib | Select Name | Out-GridView -PassThru
                    Write-Log -message "Using .net version '$( $netVersion.Name )'"
            
                    # Copy files over
                    Copy-Item -Path "$( $nugetLib )/$( $netVersion.Name )/*.*" -Destination $libDestination 
                    If ( [System.Environment]::Is64BitOperatingSystem ) {
                        $architecture = "x64"
                    } else {
                        $architecture = "x86"
                    }
                    Copy-Item -Path "$( $nugetBuild )/$( $netVersion.Name )/$( $architecture )/*.*" -Destination $libDestination
            
                    # Remove temporary files
                    Remove-Item -Path $tempfolderDestination -Force -Recurse
                    Remove-Item -Path $tempfileDestination -Force
            
                } else {
                    
                    # Remove temporary files
                    Remove-Item -Path $tempfolderDestination -Force -Recurse
                    Remove-Item -Path $tempfileDestination -Force
            
                    # Leave the process here
                    exit 0
            
                }
            
            
            }        
        }

    }

}




################################################
#
# PREPARE SQLITE DATABASE
#
################################################


switch ($dbtype) {

    { $_ -eq [psdb]::POSTGRES } { 

        # TODO [ ] fill this with the right script

        <#
        
        -- Table: apt.Test

        -- DROP TABLE IF EXISTS apt."Test";

        CREATE TABLE IF NOT EXISTS apt."Test"
        (
            id text COLLATE pg_catalog."default" NOT NULL,
            object text COLLATE pg_catalog."default",
            "ExtractTimestamp" bigint,
            properties json
        )

        TABLESPACE pg_default;

        ALTER TABLE IF EXISTS apt."Test"
            OWNER to postgres;
        
        #>

     }

    # Otherwise just use sqlite
    Default {


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
    }

}




################################################
#
# INITIAL LOAD OF DATA
#
################################################

# $decision = $Host.UI.PromptForChoice('Loading all klicktipp receivers now', 'Are you sure you want to proceed?', @('&Yes'; '&No'), 1)

# If ( $decision -eq "0" ) {

#     . ".\bin\load_subscribers.ps1"

# }


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

