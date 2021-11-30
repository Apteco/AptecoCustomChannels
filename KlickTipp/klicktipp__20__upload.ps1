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

        # Integration parameters
        scriptPath = 'D:\Scripts\KlickTipp'
        mode = 'subscribtion'

        # PeopleStage parameters
        TransactionType = 'Replace'
        Password = 'b'
        MessageName = '10 | subscribe'
        EmailFieldName = 'email'
        SmsFieldName = ''
        Path = 'd:\faststats\Publish\Handel\system\Deliveries\PowerShell_10  subscribe_5489da76-fd7d-4608-83b7-3f973de38895.txt'
        ReplyToEmail = ''
        Username = 'a'
        ReplyToSMS = ''
        UrnFieldName = 'Kunden ID'
        ListName = '10 | subscribe'
        CommunicationKeyFieldName = 'Communication Key'

        # Parameters from previous script

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
$modulename = "KTUPLOAD"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"

# Do the preparation
. ".\bin\preparation.ps1"


################################################
#
# PROCESS
#
################################################

# Load the input csv
$csv = @( import-csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding utf8 )

Write-Log "Loaded the data with $( $csv.Count ) records"

# The counters for logging later
$successful = 0
$failed = 0

switch ( $params.mode ) {

    #-----------------------------------------------
    # ADD/REMOVE TAG
    #-----------------------------------------------

    "tags" {

        # Split the listname string
        $listnameSplit = $params.ListName -split $settings.nameConcatChar,2,"SimpleMatch"
        $tagId = $listnameSplit[0]
        $tagName = $listnameSplit[1]

        # Load existing tags
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/tag.json"
        }
        $tags = Invoke-RestMethod @restParams

        # Transform tags
        $tagList = [System.Collections.ArrayList]@()
        $tags.psobject.members | where { $_.MemberType -eq "NoteProperty" } | ForEach {
            $tag = $_
            [void]$tagList.add([PSCustomObject]@{
                "id" = $tag.Name
                "name" = $tag.Value
            })
        }
        
        # Check if tag is still valid
        if ( $taglist.id -contains $tagid ) {
        
            # TODO  [ ] create the loops here
            Switch ( $tagName.Substring(0,1) ) {

                "+" {


                    $csv | ForEach {

                        # Read current row
                        $row = $_

                        # Prepare adding the tag
                        $restParams = $defaultRestParams + @{
                            "Method" = "Post"
                            "Uri" = "$( $settings.base )/subscriber/tag.json"
                            "Body" = @{
                                "email" = $row.( $params.EmailFieldName )
                                "tagids" = $tagId
                            } | ConvertTo-Json -Depth 99
                        }
                        
                        # Add the tag
                        $addTag = $false
                        try {
                            $addTag = Invoke-RestMethod @restParams
                        } catch {} # Just ignore errors and count it as failed
                        
                        # Increase counters
                        If ( $addTag ) {
                            $successful += 1
                        } else {
                            $failed += 1
                        }

                    } 
            
                }

                "-" {

                    $csv | ForEach {

                        # Read current row
                        $row = $_
                    
                        $restParams = $defaultRestParams + @{
                            "Method" = "Post"
                            "Uri" = "$( $settings.base )/subscriber/untag.json"
                            "Body" = @{
                                "email" = $row.( $params.EmailFieldName )
                                "tagid" = $tagId
                            } | ConvertTo-Json -Depth 99
                        }

                        # Add the tag
                        $removeTag = $false
                        try {
                            $removeTag = Invoke-RestMethod @restParams
                        } catch {} # Just ignore errors and count it as failed
                        
                        # Increase counters
                        If ( $removeTag ) {
                            $successful += 1
                        } else {
                            $failed += 1
                        }

                    }

                }

            }

        } else {

            Write-Log -message "Tag '$( $params.ListName )' does not exist" -severity ( [Logseverity]::WARNING )
            throw [System.IO.InvalidDataException] "Tag '$( $params.ListName )' does not exist"
        
        }

    }


    #-----------------------------------------------
    # SUBSCRIBE / UNSUBSCRIBE
    #-----------------------------------------------   

    # Setup if mode parameter is not present or not "tags"
    default {
        
        # Make connection to reflect changes here directly in the database
        $connection = [System.Data.SQLite.SQLiteConnection]::new()
        $connection.ConnectionString = "Data Source=$( $settings.sqliteDb );Version=3;New=True;"
        $connection.Open()
        $command = [System.Data.SQLite.SQLiteCommand]::new($connection)

        # Prepare command for inserting rows
        $insertedRows = 0
        $insertStatementItems = @"
        INSERT INTO
            items(id, object, ExtractTimestamp, properties)
        VALUES
            (@id, @object, @ExtractTimestamp, @properties)
"@

        # Create transaction
        $sqliteTransaction = $connection.BeginTransaction()

        # Split the listname string
        $listnameSplit = $params.ListName -split $settings.nameConcatChar,2,"SimpleMatch"
        $process = $listnameSplit[0]

        $list = $modeList

        # Load fields
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/field.json"
        }
        $fieldsRaw = Invoke-RestMethod @restParams

        # Bring fields into right order
        $fields = [ordered]@{}
        $klickTippColumns = [System.Collections.ArrayList]@()
        $fieldsRaw.psobject.Properties | ForEach {
            $field = $_
            $fields.Add($field.name,$field.value)
            [void]$klickTippColumns.add($field.Name)
        }

        # Compare the columns between the CSV and KlickTipp
        $csvColumns = ( $csv | Get-Member -MemberType NoteProperty ).Name
        $difference = Compare -ReferenceObject $klickTippColumns -DifferenceObject $csvColumns -IncludeEqual 
        $equalColumns = ( $difference | where { $_.SideIndicator -eq "==" } ).InputObject
        $columnsOnlyCsv = ( $difference | where { $_.SideIndicator -eq "=>" } ).InputObject
        $columnsOnlyKlickTipp = ( $difference | where { $_.SideIndicator -eq "<=" } ).InputObject

        Write-Log -message "Equal columns: $( $equalColumns -join ", " )"
        Write-Log -message "Columns only CSV: $( $columnsOnlyCsv -join ", " )"
        Write-Log -message "Columns only KlickTipp: $( $columnsOnlyKlickTipp -join ", " )"

        switch ( $process ) {

            # subscribe
            "10" {

                $csv | ForEach {

                    # Read current row
                    $row = $_

                    # Prepare fields object
                    $fields = [Ordered]@{}
                    $equalColumns | ForEach {
                        $fields.Add($_, $row.$_)
                    }

                    # Prepare adding the subscriber
                    $restParams = $defaultRestParams + @{
                        "Method" = "Post"
                        "Uri" = "$( $settings.base )/subscriber.json"
                        "Body" = [ordered]@{
                            email = $row.( $params.EmailFieldName )
                            #smsnumber = ""
                            #listid = 0
                            #tagid = 0
                            fields = $fields
                        } | ConvertTo-Json -Depth 99
                    }

                    # Add the subscriber
                    $addSubscriber = $false
                    try {

                        $subscribedUser = Invoke-RestMethod @restParams

                        $addSubscriber = $true

                        # Add to database
                        $command.CommandText = $insertStatementItems
                        [void]$command.Parameters.AddWithValue("@object", "subscriber")        
                        [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $timestamp.tostring("yyyyMMddHHmmss"))
                        [void]$command.Parameters.AddWithValue("@id", $subscribedUser.id)
                        [void]$command.Parameters.AddWithValue("@properties", ( $subscribedUser | ConvertTo-Json -Compress -Depth 99 ))
                        [void]$command.Prepare()
                        $insertedRows += $command.ExecuteNonQuery()

                    } catch {}

                    # Increase counters
                    If ( $addSubscriber ) {
                        $successful += 1
                    } else {
                        $failed += 1
                    }


                }

            }

            # update
            "20" {

                If ( $csvColumns -contains $settings.upload.klickTippIdField ) {

                    $csv | ForEach {

                        # Read current row
                        $row = $_
                        
                        # Check if subscriber id is filled
                        $subscriberId = $row.( $settings.upload.klickTippIdField )
                        If ( $subscriberId ) {

                            # Prepare fields object
                            $fields = [Ordered]@{}
                            $equalColumns | ForEach {
                                $fields.Add($_, $row.$_)
                            }

                            # Prepare API call
                            $restParams = $defaultRestParams + @{
                                "Method" = "Put"
                                "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
                                "Body" = [ordered]@{
                                    fields = $fields
                                    #newemail = ""
                                    #newsmsnumber = ""
                                } | ConvertTo-Json -Depth 99
                            }
            
                            # Add the subscriber
                            $updated = $false
                            try {
        
                                $updatedUser = Invoke-RestMethod @restParams
        
                                $updated = $true

                                # The updating does not deliver the whole object, so no need to put it back to database
                                # TODO [ ] Think about if it makes sense to reload the subscriber object and write it to the database
                                <#
                                $restParams = $defaultRestParams + @{
                                    "Method" = "Get"
                                    "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
                                }
                                $subscriber = Invoke-RestMethod @restParams

                                # Add to database
                                $command.CommandText = $insertStatementItems
                                [void]$command.Parameters.AddWithValue("@object", "subscriber")        
                                [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $timestamp.tostring("yyyyMMddHHmmss"))
                                [void]$command.Parameters.AddWithValue("@id", $subscriberId)
                                [void]$command.Parameters.AddWithValue("@properties", ( $subscriber | ConvertTo-Json -Compress -Depth 99 ))
                                [void]$command.Prepare()
                                $insertedRows += $command.ExecuteNonQuery()

                                #>
        
                            } catch {}
        
                            # Increase counters
                            If ( $updated ) {
                                $successful += 1
                            } else {
                                $failed += 1
                            }


                        } else {
                            $msg = "Subscriber id for $( $row.( $params.EmailFieldName ) ) not filled"
                            Write-Log -message $msg -severity ( [Logseverity]::WARNING )
                        }
                        
                    }


                } else {
                    $msg = "No subscriberID column from KlickTipp is present"
                    Write-Log -message $msg -severity ( [Logseverity]::ERROR )
                    throw [System.IO.InvalidDataException] $msg
                }

            }

            # unsubscribe
            "30" {

                $csv | ForEach {

                    # Read current row
                    $row = $_

                    $restParams = $defaultRestParams + @{
                        "Method" = "Post"
                        "Uri" = "$( $settings.base )/subscriber/unsubscribe.json"
                        "Body" = @{
                            email = $row.( $params.EmailFieldName )
                        } | ConvertTo-Json -Depth 99
                    }

                    # Add the subscriber
                    $unsubscribed = $false
                    try {

                        $unsubscribedUser = Invoke-RestMethod @restParams

                        $unsubscribed = $true

                        # Add to database
                        $command.CommandText = $insertStatementItems
                        [void]$command.Parameters.AddWithValue("@object", "unsubscriber")        
                        [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $timestamp.tostring("yyyyMMddHHmmss"))
                        [void]$command.Parameters.AddWithValue("@id", $row.( $params.EmailFieldName ))
                        [void]$command.Parameters.AddWithValue("@properties", $null)
                        [void]$command.Prepare()
                        $insertedRows += $command.ExecuteNonQuery()

                    } catch {}

                    # Increase counters
                    If ( $unsubscribed ) {
                        $successful += 1
                    } else {
                        $failed += 1
                    }
                    
                }

            }

            # delete
            "40" {
                
                If ( $csvColumns -contains $settings.upload.klickTippIdField ) {

                    $csv | ForEach {

                        # Read current row
                        $row = $_
                        
                        # Check if subscriber id is filled
                        $subscriberId = $row.( $settings.upload.klickTippIdField )
                        If ( $subscriberId ) {

                            $restParams = $defaultRestParams + @{
                                "Method" = "Delete"
                                "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ) ).json"
                            }
        
                            # Add the subscriber
                            $deleted = $false
                            try {
        
                                $deletedUser = Invoke-RestMethod @restParams
        
                                $deleted = $true
                                
                                # Add to database
                                $command.CommandText = $insertStatementItems
                                [void]$command.Parameters.AddWithValue("@object", "delete")        
                                [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $timestamp.tostring("yyyyMMddHHmmss"))
                                [void]$command.Parameters.AddWithValue("@id", $subscriberId )
                                [void]$command.Parameters.AddWithValue("@properties", $null)
                                [void]$command.Prepare()
                                $insertedRows += $command.ExecuteNonQuery()
                                        
                            } catch {}
        
                            # Increase counters
                            If ( $deleted ) {
                                $successful += 1
                            } else {
                                $failed += 1
                            }


                        } else {
                            $msg = "Subscriber id for $( $row.( $params.EmailFieldName ) ) not filled"
                            Write-Log -message $msg -severity ( [Logseverity]::WARNING )
                        }
                        
                    }


                } else {
                    $msg = "No subscriberID column from KlickTipp is present"
                    Write-Log -message $msg -severity ( [Logseverity]::ERROR )
                    throw [System.IO.InvalidDataException] $msg
                }

            }

        }

        # Commit transaction
        $sqliteTransaction.Commit()

        # Closing connection to database
        $command.Dispose()
        $connection.Dispose()
    
    }

}

# Do the end stuff
. ".\bin\end.ps1"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

Write-Log -message "Records successfully processed: $( $successful )"
Write-Log -message "Records failed: $( $failed )" -severity ( [Logseverity]::WARNING )

$queued = $successful

If ( $queued -eq 0 ) {
    Write-Host "Throwing Exception because of 0 records"
    throw [System.IO.InvalidDataException] "No records were successfully uploaded"  
}

# return object
$return = [Hashtable]@{

    # Mandatory return values
    "Recipients"        = $queued 
    "TransactionId"     = $processId

    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider"    = $moduleName
    "ProcessId"         = $processId

    # Some more information for the broadcasts script
    #"Path"              = $params.Path
    #"UrnFieldName"      = $params.UrnFieldName
    #"CorrelationId"     = $result.correlationId

    # More information about the different status of the import
    "RecipientsIgnored" = $failed
    "RecipientsQueued" = $queued

}

# return the results
$return