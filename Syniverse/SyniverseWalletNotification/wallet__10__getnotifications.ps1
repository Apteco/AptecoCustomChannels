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
	    scriptPath= "D:\Scripts\Syniverse\WalletNotification_v2"
	    Username= "abc"
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
$moduleName = "GETNTFTEMPL"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
  $AllProtocols = @(    
      [System.Net.SecurityProtocolType]::Tls12
      #[System.Net.SecurityProtocolType]::Tls13,
      ,[System.Net.SecurityProtocolType]::Ssl3
  )
  [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
$mssqlConnectionString = $settings.responseDB


# append a suffix, if in debug mode
if ( $debug ) {
  $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data  #, System.Text.Encoding

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
# CHECK MSSQL FOR TEMPLATES
#
################################################

#-----------------------------------------------
# DECRYPT CONNECTION STRING
#-----------------------------------------------

$mssqlConnectionString = Get-SecureToPlaintext -String $settings.login.sqlserver


#-----------------------------------------------
# LOAD TEMPLATES FROM MSSQL
#-----------------------------------------------

Write-Log "Loading notification templates from SQLSERVER"

$mssqlConnection = [System.Data.SqlClient.SqlConnection]::new()
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

"Trying to load the data from MSSQL"

# define query -> currently the age of the date in the query has to be less than 12 hours
$mssqlQuery = Get-Content -Path ".\sql\getmessages.sql" -Encoding UTF8

# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = new-object System.Data.DataTable
$mssqlTable.Load($mssqlResult)
    

$mssqlConnection.Close()

# show result
#$mssqlTable


#-----------------------------------------------
# BUILD MAILING OBJECTS
#-----------------------------------------------

$mailings = [System.Collections.ArrayList]@()
$mssqlTable | foreach {

    # Load data
    $template = $_

    # Create mailing objects
    [void]$mailings.Add([Mailing]@{
        mailingId=$template.CreativeTemplateId
        mailingName=$template.Name
    })

}

$messages = $mailings | Select @{name="id";expression={ $_.mailingId }}, @{name="name";expression={ $_.toString() }}


###############################
#
# RETURN MESSAGES
#
###############################

return $messages