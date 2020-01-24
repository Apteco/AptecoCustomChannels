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
$logfile = $settings.logfile

# SQL files
$sql = Get-Content -Path ".\sql\mssql__11__getlevel.sql" -Encoding UTF8


################################################
#
# FUNCTIONS
#
################################################

Add-Type -AssemblyName System.Data

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tGETMAILINGS" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
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

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tLoad level metadata" >> $logfile


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
    "$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tError: $( $errText )" >> $logfile

} finally {
    
    # close connection
    $mssqlConnection.Close()

}

"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tGot $( $resultData.rows.Count ) rows for the level." >> $logfile


################################################
#
# RETURN
#
################################################

return $resultData | select @{name="id";expression={ $_.id }}, @{name="name";expression={ "$( $_.id )$( $settings.messageNameConcatChar )$( $_.name )" }}

