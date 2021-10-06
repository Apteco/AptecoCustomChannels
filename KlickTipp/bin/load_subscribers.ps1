    #-----------------------------------------------
    # LOAD DATA FROM KLICKTIPP
    #-----------------------------------------------

    $restParams = $defaultRestParams + @{
        "Method" = "Get"
        "Uri" = "$( $settings.base )/subscriber.json"
    }
    
    # This call will only get the subscribers that have finished the DOI process
    $subscribersIndex = Invoke-RestMethod @restParams
    
    #Invoke-RestMethod -Uri $restParams.Uri -Method Get -Headers $headers -Verbose
    # Get Details
    $subscribers = [System.Collections.ArrayList]@()
    $subscribersIndex | ForEach {

        $subscriberId = $_
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
        }
        $subscriber = Invoke-RestMethod @restParams
        [void]$subscribers.Add($subscriber)
    
    }

    #-----------------------------------------------
    # MAKE NEW CONNECTION TO DATABASE
    #-----------------------------------------------

    $connection = [System.Data.SQLite.SQLiteConnection]::new()
    $connection.ConnectionString = "Data Source=$( $settings.sqliteDb );Version=3;New=True;"
    $connection.Open()
    $command = [System.Data.SQLite.SQLiteCommand]::new($connection)


    #-----------------------------------------------
    # PREPARE QUERIES FOR INSERTING DATA
    #-----------------------------------------------

    # Prepare command for inserting rows
    $insertStatementItems = @"
    INSERT INTO
        items(id, object, ExtractTimestamp, properties)
    VALUES
        (@id, @object, @ExtractTimestamp, @properties)
"@

    #-----------------------------------------------
    # LOADING DATA FROM KLICKTIPP INTO SQLITE
    #-----------------------------------------------

    $insertedRows = 0
    $t = Measure-Command {

        #-----------------------------------------------
        # LOADING ITEMS
        #-----------------------------------------------

        $sqliteTransaction = $connection.BeginTransaction()
        $subscribers | ForEach {

            $row = $_
            
            $command.CommandText = $insertStatementItems

            [void]$command.Parameters.AddWithValue("@object", "subscriber")        
            [void]$command.Parameters.AddWithValue("@ExtractTimestamp", $timestamp.tostring("yyyyMMddHHmmss"))

            [void]$command.Parameters.AddWithValue("@id", $row.id)
            #[void]$command.Parameters.AddWithValue("@createdAt", $row.createdAt)
            #[void]$command.Parameters.AddWithValue("@updatedAt", $row.updatedAt)
            #[void]$command.Parameters.AddWithValue("@archived", $row.archived)
            [void]$command.Parameters.AddWithValue("@properties", ( $row | ConvertTo-Json -Compress -Depth 99 ))

            [void]$command.Prepare()

            $insertedRows += $command.ExecuteNonQuery()

        }
        $sqliteTransaction.Commit()

    }


    #-----------------------------------------------
    # CLOSING CONNECTION
    #-----------------------------------------------

    $command.Dispose()
    $connection.Dispose()


    #-----------------------------------------------
    # LOG RESULTS
    #-----------------------------------------------

    Write-Log -message "Inserted $( $insertedRows ) items in total"
    Write-Log -message "Needed $( $t.TotalSeconds ) seconds for inserting data"