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

$debug = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    Password= "def"
	    scriptPath= "C:\scripts"
        mode= "process"
	    abc= "def"
	    Username= "abc"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://support.klicktipp.com/article/388-rest-application-programming-interface-api

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
Set-Location -Path "$( $scriptPath )"


################################################
#
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "KTFERGE"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load database .net assemblies
. ".\bin\load_database_dll.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"

# Do the preparation
#. ".\bin\preparation.ps1"


################################################
#
# PROCESS
#
################################################


$schema = $settings.postgresSchema
$typeName = $settings.postgresTypename

$connection = [Npgsql.NpgsqlConnection]::new()
$connection.ConnectionString = Get-SecureToPlaintext $settings.postgresConnString #"Host=localhost;Port=5432;Username=postgres;Password=xxx;Database=postgres;Client Encoding=UTF8;Encoding=UTF8"
$connection.Open()

$cmd = $connection.CreateCommand()
$cmd.CommandText = @"
SELECT *
		FROM apt."Test" 
        limit 10
"@

$result = [System.Data.DataTable]::new()
$sqlResult = $cmd.ExecuteReader()

# load data
$result.Load($sqlResult, [System.Data.Loadoption]::Upsert)

$result | Out-GridView

$connection.dispose()

#Write-Host -NoNewLine 'Press any key to continue...';
#$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown');
