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
	    EmailFieldName= "Email"
	    TransactionType= "Replace"
	    Password= "def"
	    scriptPath= "C:\Apteco\Integration\MSSQL"
	    MessageName= "1 | Novize"
	    SmsFieldName= ""
	    Path= "C:\Apteco\Publish\Handel\System\Deliveries\PowerShell_1  Novize_66ce38fd-191a-48b9-885f-eca1bac20803.txt"
        ReplyToEmail= ""
        database="dev"
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Urn"
	    ListName= "1 | Novize"
	    CommunicationKeyFieldName= "Communication Key"
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
$uploadsFolder = $settings.uploadsFolder
$mssqlConnectionString = $settings.psConnectionString -replace "#DATABASE#", $params.database

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}

# SQL files
$campaignsSqlFilename = "sql\mssql__21__load_delivery_metadata.sql"
$customersSqlFilename = "sql\mssql__22__load_customers.sql"
$levelUpdateSqlFilename = "sql\mssql__23__change_level.sql"

# Export file
$updateId = [guid]::NewGuid()


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
# START CHECK
#
################################################

#-----------------------------------------------
# CHECK FILE EXISTS
#-----------------------------------------------

Write-Log -message "Using update id: $( $updateId )"

$fileExists = Check-Path -Path $params.Path

if ( !$fileExists ) {
    Exit 1
}

# get the input file
$fileItem = Get-Item -Path $params.Path


#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

if ( !(Test-Path -Path $uploadsFolder) ) {
    New-Item -Path ".\$( $uploadsFolder )" -ItemType Directory
}
#Set-Location -Path $uploadsSubfolder


################################################
#
# LOAD CAMPAIGN RUN METADATA
#
################################################

Write-Log -message "Load campaign metadata"

# TODO [ ] replace this part with a function

# prepare query
$campaignSql = Get-Content -Path ".\$( $campaignsSqlFilename )" -Encoding UTF8
$campaignSql = $campaignSql -replace "#FILE#", $fileItem.Name

try {

    # build connection
    $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()
    
    # execute command
    $campaignMssqlCommand = $mssqlConnection.CreateCommand()
    $campaignMssqlCommand.CommandText = $campaignSql
    $mssqlCommand.CommandTimeout = $settings.commandTimeout # TODO [ ] check this parameter exists
    $campaignMssqlResult = $campaignMssqlCommand.ExecuteReader()
    
    # load data
    $campaignMetadata = New-Object "System.Data.DataTable"
    $campaignMetadata.Load($campaignMssqlResult)

} catch [System.Exception] {

    $errText = $_.Exception
    $errText | Write-Output
    Write-Log -message "Error: $( $errText )"

} finally {
    
    # close connection
    $mssqlConnection.Close()

}

# load variables from result
$campaignID = $campaignMetadata[0].ID
$campaignRun = $campaignMetadata[0].Run
$stepId = $campaignMetadata[0].DeliveryStepId

# log 
Write-Log -message "Got back campaign ID: $( $campaignID )"
Write-Log -message "Got back run ID: $( $campaignRun )"
Write-Log -message "Got back step ID: $( $stepId )"


################################################
#
# LOAD CUSTOMERS
#
################################################

Write-Log -message "Load customers metadata"

$maxIdsPerBatch = $settings.maxIdsPerBatch

# TODO [ ] replace this part with a function

if ($campaignID -gt 0 -and $campaignRun -gt 0 -and $stepId -gt 0 ) {
    
    # build connection
    $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()

    # load customer file
    $c = Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8 
    $cIds = ( $c | select @{name="Urn";expression={ ($_."$( $params.UrnFieldName )").Trim() }} ).Urn #$c."$( $params.UrnFieldName )"
    
    # create datatable
    $customerMetadata = new-object "System.Data.DataTable"

    # loop through batches to update
    for ($i = 0 ; $i -lt $cIds.Count ; $i += $maxIdsPerBatch) {
        
        # prepare the IDs to update
        $min = $i
        $max = $i + $maxIdsPerBatch -1        
        $cIdsBatch = [array]@($cIds)[$min..$max] -join ","
        
        $cIdsBatch
                 
        # prepare query
        $customerSql = Get-Content -Path ".\$( $customersSqlFilename )" -Encoding UTF8
        $customerSql = $customerSql -replace "#CAMPAIGN#", $campaignID
        $customerSql = $customerSql -replace "#RUN#", $campaignRun
        $customerSql = $customerSql -replace "#STEP#", $stepId
        $customerSql = $customerSql -replace "#CUSTOMERURN#", $cIdsBatch
        
        $customerSql

        try {

            # execute command
            $customerMssqlCommand = $mssqlConnection.CreateCommand()
            $customerMssqlCommand.CommandText = $customerSql
            $customerMssqlResult = $customerMssqlCommand.ExecuteReader()
    
            # load data
            $customerMetadata.Load($customerMssqlResult, [System.Data.Loadoption]::Upsert)
           

        } catch [System.Exception] {

            $errText = $_.Exception
            $errText | Write-Output
            Write-Log -message "Error: $( $errText )" -severity ([LogSeverity]::ERROR)

            # throw it back to PeopleStage
            throw $_

        } finally {
    
            

        }

    }

    $customerMetadata | Export-Csv -Path ".\$( $uploadsFolder )\$( $updateId )__input.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation

    # log 
    Write-Log -message "Got back $( $customerMetadata.Rows.Count ) customers to change the level"

    # close connection
    $mssqlConnection.Close()

}
    

################################################
#
# CHANGE LEVEL
#
################################################

# Determine which level to change
$levelToUpdate = ( $params.MessageName -split $settings.messageNameConcatChar )[0]

Write-Log -message "Changing level for $( $customerMetadata.rows.Count ) customers to level $( $levelToUpdate )"

# loop through all customers to change
if ($customerMetadata.rows.Count -gt 0 ) {

    # build connection -> check if the connection can keeped open
    $mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
    $mssqlConnection.ConnectionString = $mssqlConnectionString
    $mssqlConnection.Open()

    $changedLevel = @()
    $customerMetadata.rows | ForEach {
    
        $customer = $_

        # create customer object
        $customerLevel = New-Object PSCustomObject
        $customerLevel | Add-Member -MemberType NoteProperty -Name "Urn" -Value $customer.Urn
        $customerLevel | Add-Member -MemberType NoteProperty -Name "LevelBeforeUpdate" -Value $customer.LevelName
        $customerLevel | Add-Member -MemberType NoteProperty -Name "LevelToUpdate" -Value $levelToUpdate

        # prepare query
        $levelUpdateSql = Get-Content -Path ".\$( $levelUpdateSqlFilename )" -Encoding UTF8
        $levelUpdateSql = $levelUpdateSql -replace "#URN#", $customer.Urn
        $levelUpdateSql = $levelUpdateSql -replace "#LEVEL#", $levelToUpdate

        try {

            # execute command
            $levelUpdateMssqlCommand = $mssqlConnection.CreateCommand()
            $levelUpdateMssqlCommand.CommandText = $levelUpdateSql
            $levelUpdateSql
            $updateResult = $levelUpdateMssqlCommand.ExecuteScalar() #$mssqlCommand.ExecuteNonQuery()
    
        } catch [System.Exception] {

            $errText = $_.Exception
            $errText | Write-Output
            Write-Log -message "Error: $( $errText )" -severity ([LogSeverity]::ERROR)

            # Throwing this exception back to PeopleStage now
            throw $_

        } finally {
    
            

        }

        # Update the customer level
        $customerLevel | Add-Member -MemberType NoteProperty -Name "ReturnValueFromDatabase" -Value $updateResult
        $changedLevel += $customerLevel

    }

    # close connection
    $mssqlConnection.Close()

    Write-Log -message "Changed level for $( $changedLevel.count ) customers to level $( $levelToUpdate )"

    $changedLevel | Export-Csv -Path ".\$( $uploadsFolder )\$( $updateId )__output.csv" -Encoding UTF8 -Delimiter "`t" -NoTypeInformation


}


################################################
#
# FINISH
#
################################################

# log 
Write-Log -message "Done with Upload!"


#-----------------------------------------------
# RETURN VALUES TO PEOPLESTAGE
#-----------------------------------------------


$recipients = $changedLevel | where { $_.ReturnValueFromDatabase -eq 0} | Select Urn

[Hashtable]$return = @{
    "Recipients"=$recipients.Count
    "TransactionId"=$updateId
}

$return
