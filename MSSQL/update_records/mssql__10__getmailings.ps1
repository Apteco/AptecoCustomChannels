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
	    Password= "def"
	    scriptPath= "C:\Apteco\Integration\MSSQL"
        Username= "abc"
        database="dev"
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
$settingsFilename = "settings.json"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# more settings
$logfile = $settings.logfile
$mssqlConnectionString = $settings.psConnectionString -replace "#DATABASE#", $params.database

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}

# SQL files
$sql = Get-Content -Path "sql\mssql__11__getlevel.sql" -Encoding UTF8


################################################
#
# FUNCTIONS
#
################################################

Add-Type -AssemblyName System.Data

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


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

#-----------------------------------------------
# SQL CONNECTION STRING
#-----------------------------------------------

$mssqlConnectionString = $settings.psConnectionString 

# This allows the replacement in the connection string if this script is deployed on different environments like dev, test and prod
# In this case the database is delivered through the channel editor in PeopleStage
#$mssqlConnectionString = $mssqlConnectionString -replace "#DATABASE#", $params.database


#-----------------------------------------------
# LOG
#-----------------------------------------------

Write-Log -message "Load level metadata" 


#-----------------------------------------------
# QUERY
#-----------------------------------------------

# TODO [ ] replace this part with a function

try {

    # build connection
    $mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()
    
    # execute command
    $mssqlCommand = $mssqlConnection.CreateCommand()
    $mssqlCommand.CommandText = $sql
    $mssqlResult = $mssqlCommand.ExecuteReader()
    
    # load data
    $resultData = New-Object "System.Data.DataTable"
    $resultData.Load($mssqlResult)

} catch [System.Exception] {

    $errText = $_.Exception
    $errText | Write-Output
    Write-Log -message "Error: $( $errText )" 

} finally {
    
    # close connection
    $mssqlConnection.Close()

}

Write-Log -message "Got $( $resultData.rows.Count ) rows for the level." 


################################################
#
# RETURN
#
################################################

return $resultData | select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.messageNameConcatChar )$( $_.name )" }}

