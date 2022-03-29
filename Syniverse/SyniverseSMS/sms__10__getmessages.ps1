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
	    scriptPath= "D:\Scripts\Syniverse\SMS"
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

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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

$script:moduleName = "SYNSMS-GET-MAILINGS"

try {

    # Load general settings
    . ".\bin\general_settings.ps1"

    # Load settings
    . ".\bin\load_settings.ps1"

    # Load network settings
    . ".\bin\load_networksettings.ps1"

    # Load functions
    . ".\bin\load_functions.ps1"

    # Start logging
    . ".\bin\startup_logging.ps1"

    # Load preparation ($cred)
    . ".\bin\preparation.ps1"

} catch {

    Write-Log -message "Got exception during start phase" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
    Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
    
    throw $_.exception  

    exit 1

}


################################################
#
# PROGRAM
#
################################################

$messages = [System.Collections.ArrayList]@()
try {

  ################################################
  #
  # TRY
  #
  ################################################

  #-----------------------------------------------
  # LOAD TEMPLATES FROM MSSQL
  #-----------------------------------------------

  $mssqlConnection = [System.Data.SqlClient.SqlConnection]::new()
  $mssqlConnection.ConnectionString = $mssqlConnectionString

  $mssqlConnection.Open()

  Write-Log -message "Establishing connection to MSSQL database now"

  # define query -> currently the age of the date in the query has to be less than 12 hours
  $mssqlQuery = Get-Content -Path ".\sql\getmessages.sql" -Encoding UTF8

  # execute command
  $mssqlCommand = $mssqlConnection.CreateCommand()
  $mssqlCommand.CommandText = $mssqlQuery
  $mssqlResult = $mssqlCommand.ExecuteReader()
      
  # load data
  $mssqlTable = [System.Data.DataTable]::new()
  $mssqlTable.Load($mssqlResult)
  
  Write-Log -message "Loaded $( $mssqlTable.Rows.Count ) templates from MSSQL. Closing the database connection now"

  # Close connection
  $mssqlConnection.Close()

  Write-Log -message "Connection closed"


  #-----------------------------------------------
  # TRANSFORM MSSQL RESULT INTO PSCUSTOMOBJECT
  #-----------------------------------------------

  Write-Log -message "Transforming the result for PeopleStage"

  $mailings = [System.Collections.ArrayList]@()
  $mssqlTable.Rows | foreach {

      # Load data
      $template = $_

      # Create mailing objects
      [void]$mailings.Add([Mailing]@{
          mailingId=$template.CreativeTemplateId
          mailingName=$template.Name
      })

  }
    
  # Transform the mailings array into the needed output format
    $columns = @(
        @{
            name="id"
            expression={ $_.mailingId }
        }
        @{
            name="name"
            expression={ $_.toString() }
        }
    )
    [void]$messages.AddRange(@( $mailings | Select $columns ))

    Write-Log -message "Loaded $( $messages.Count ) templates for PeopleStage"


} catch {

  ################################################
  #
  # ERROR HANDLING
  #
  ################################################

  Write-Log -message "Got exception during execution phase" -severity ( [LogSeverity]::ERROR )
  Write-Log -message "  Type: '$( $_.Exception.GetType().Name )'" -severity ( [LogSeverity]::ERROR )
  Write-Log -message "  Message: '$( $_.Exception.Message )'" -severity ( [LogSeverity]::ERROR )
  Write-Log -message "  Stacktrace: '$( $_.ScriptStackTrace )'" -severity ( [LogSeverity]::ERROR )
  
  throw $_.exception

} finally {

  ################################################
  #
  # RETURN
  #
  ################################################

  $messages

}
