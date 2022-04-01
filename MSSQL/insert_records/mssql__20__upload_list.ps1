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
	    TransactionType = 'Replace'
        Password = 'b'
        scriptPath = 'E:\Apteco\Scripts\rabatt_zuordnung_v2'
        MessageName = '0 | Rabatte zuordnen'
        EmailFieldName = 'email'
        SmsFieldName = ''
        Path = '\\APTECO\Publish\Handel\system\Deliveries\PowerShell_0  Rabatte zuordnen_b7a3e63b-6864-4a77-a779-d2796e979dc3.txt'
        ReplyToEmail = ''
        Username = 'a'
        ReplyToSMS = ''
        PreviewMessageScript = ''
        UrnFieldName = 'KU-Id'
        ListName = '0 | Rabatte zuordnen'
        CommunicationKeyFieldName = 'Communication Key'
    }
}


################################################
#
# NOTES
#
################################################

<#

# TODO [x] add measure

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

$script:moduleName = "RABATT-UPLOAD"


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

try {

    
    ################################################
    #
    # TRY
    #
    ################################################

    #-----------------------------------------------
    # CHECK INPUT FILE
    #-----------------------------------------------

    $file = $params.Path
    $fileExists = Check-Path -Path $file

    if ( $fileExists ) {

            # get the input file
            $fileItem = Get-Item -Path $file

    } else {
        
        $msg = "Exit script, file does not exist"
        Write-Log -message $msg -severity ( [Logseverity]::ERROR )
        throw [System.IO.InvalidDataException] $msg

    }


    #-----------------------------------------------
    # LOG
    #-----------------------------------------------

    Write-Log -message "Using: $( $fileItem.FullName )"
    #Write-Log -message "Connection String: $( $settings.connectionString )"
    Write-Log -message "Default Days valid: $( $settings.defaultValidDays )"
    Write-Log -message "Default Days for Redeem: $( $settings.defaultDaysRedeem )"


    #-----------------------------------------------
    # CHECK RABATTE FOLDER
    #-----------------------------------------------

    if ( !(Test-Path -Path $rabatteSubfolder) ) {
        New-Item -Path ".\$( $rabatteSubfolder )" -ItemType Directory
    }



    ################################################
    #
    # TODO
    #
    ################################################

    <#

    - [x] Implement error handling
    - [x] Kontrollgruppen noch abziehen
    - [x] Don't write something if Rabatte were not used

    #>

    ################################################
    #
    # LOAD CAMPAIGN RUN METADATA
    #
    ################################################

    $t = Measure-Command {
        
        Write-Log -message "Load campaign metadata"

        $campaignSql = Get-Content -Path "$( $campaignsSqlFilename )" -Encoding UTF8
        $campaignSqlReplacement = @{
            "#FILE#"=$fileItem.Name
        }
        $campaignSql = Replace-Tokens -InputString $campaignSql -Replacements $campaignSqlReplacement

        # load data
        $campaignMetadata = Query-SQLServer -connectionString "$( $mssqlConnectionString )" -query "$( $campaignSql )"

        # load variables from result
        $campaignID = $campaignMetadata[0].ID
        $campaignRun = $campaignMetadata[0].Run
        $stepId = $campaignMetadata[0].DeliveryStepId

        # log 
        Write-Log -message "Got back campaign ID: $( $campaignID )"
        Write-Log -message "Got back run ID: $( $campaignRun )"
        Write-Log -message "Got back step ID: $( $stepId )"

        If ( -not $campaignId.length() -gt 0 ) {

            $msg = "Exit script, file does not exist"
            Write-Log -message $msg -severity ( [Logseverity]::ERROR )
            throw [System.IO.InvalidDataException] $msg

        }

    }

    Write-Log -message "Load campaign metadata in $( $t.totalSeconds ) seconds"


    ################################################
    #
    # INSERT CUSTOMERS
    #
    ################################################

    $t = Measure-Command {


        # log
        Write-Log -message "Insert customer rows"

        # prepare query
        $customersSql = Get-Content -Path ".\$( $customersSqlFilename )" -Encoding UTF8
        $customersSqlReplacement = [Hashtable]@{
            "#CAMPAIGN#"=$campaignID
            "#RUN#"= $campaignRun
            "#STEP#"=$stepId
            "#DEFAULTVALIDDAYS#"= $settings.defaultValidDays
            "#DEFAULTDAYSREDEEM#"= $settings.defaultDaysRedeem
            "#RABATTGUID#" = $RABATTGUID
            "#ROWSPERPAGE#" = $settings.joinRowsPerPage
        }
        $customersSql = Replace-Tokens -InputString $customersSql -Replacements $customersSqlReplacement
        $customersSql | Set-Content ".\$( $rabatteSubfolder )\$( $RABATTGUID ).txt" -Encoding UTF8

        # insert customer with Rabatt
        $customerMssqlResult = NonQueryScalar-SQLServer -connectionString "$( $mssqlConnectionString )" -command "$( $customersSql )"

    }

    Write-Log -message "Added $( $customerMssqlResult ) customer rows in $( $t.totalSeconds ) seconds"


    ################################################
    #
    # INSERT CAMPAIGN RUN METADATA
    #
    ################################################

    $t = Measure-Command {

        # only add data, if query was more than 0 rows
        if ( $customerMssqlResult -gt 0 ) {

            # log
            Write-Log -message "Insert campaign metadata"

            try {

            $sqlBulkCopy = New-Object -TypeName System.Data.SqlClient.SqlBulkCopy($mssqlConnectionString, [System.Data.SqlClient.SqlBulkCopyOptions]::KeepIdentity)
            #$sqlBulkCopy.EnableStreaming = $true
            $sqlBulkCopy.DestinationTableName = $bulkDestination
            $sqlBulkCopy.BatchSize = $settings.bulkBatchsize
            $sqlBulkCopy.BulkCopyTimeout = $settings.bulkTimeout
            $bulkResult = $sqlBulkCopy.WriteToServer($campaignMetadata)

            } catch [System.Exception] {

                $errText = $_.Exception
                $errText | Write-Output
                Write-Log -message "Error: $( $errText )"

            } finally {

                $sqlBulkCopy.Close()

            }
            

        } else {

            # log
            Write-Log -message "Rabatte not used, no campaign metadata rows"

        }

    }

    Write-Log -message "Inserted campaign metadata rows in $( $t.totalSeconds ) seconds"



    ################################################
    #
    # INSERT RABATTE
    #
    ################################################

    $t = Measure-Command {

        # only add data, if query was more than 0 rows
        if ( $customerMssqlResult -gt 0 ) {

            # log
            Write-Log -message "Insert Rabatte rows"

            # prepare query
            $rabattSql = Get-Content -Path ".\$( $rabattSqlFilename )" -Encoding UTF8
            
            $rabattSqlReplacement = @{
                "#CAMPAIGN#"=$campaignID
                "#RUN#"= $campaignRun
            }
            $rabattSql = Replace-Tokens -InputString $rabattSql -Replacements $rabattSqlReplacement

            NonQuery-SQLServer -connectionString $mssqlConnectionString -command $rabattSql
        
            # log
            Write-Log -message "Added $( $rabattResult ) Rabatte rows for $( $customerMssqlResult ) customers"
            #Write-Host "Added $( $rabattResult ) Rabatte rows for $( $customerMssqlResult ) customers" # TODO [ ] is this last variable correct?

        } else {

            # log
            Write-Log -message "Rabatte not used, no Rabatte rows"

        }

    }

    Write-Log -message "Inserted rabatte rows in $( $t.totalSeconds ) seconds"



    ################################################
    #
    # FINISH
    #
    ################################################

    $end = New-TimeSpan -Start $timestamp -End ([Datetime]::Now)

    # log 
    Write-Log -message "'$( $script:moduleName )' done in $( $end.totalSeconds ) seconds!"


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

    # TODO [ ] Check the return values

    # count the number of successful upload rows
    $recipients = $rabattResult

    # put in the source id as the listname
    $transactionId = $processId

    # return object
    $return = [Hashtable]@{
        "Recipients"=$recipients
        "TransactionId"=$transactionId
        "CustomProvider"=$settings.providername
        "ProcessId" = $transactionId
        "NewLines" = $recipients
    }

    # return the results
    $return

}
