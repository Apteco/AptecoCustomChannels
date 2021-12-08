
    

    #-----------------------------------------------
    # LOAD SUBSCRIBER DATA FROM KLICKTIPP
    #-----------------------------------------------
    
    Write-Log -message "Loading subscribers"

    $restParams = $defaultRestParams + @{
        "Method" = "Get"
        "Uri" = "$( $settings.base )/subscriber.json"
    }
    
    # This call will only get the subscribers that have finished the DOI process
    $subscribersIndex = Invoke-RestMethod @restParams

    Write-Log -message "Got back $( $subscribersIndex.count ) subscribers"

    #Invoke-RestMethod -Uri $restParams.Uri -Method Get -Headers $headers -Verbose
    # Get Details
    $subscribers = [System.Collections.ArrayList]@()
    $subscribersIndex | Select -first 5 | ForEach { # TODO [ ] remove the 5 restriction

        $subscriberId = $_
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/subscriber/$( $subscriberId ).json"
        }
        $subscriber = Invoke-RestMethod @restParams
        [void]$subscribers.Add($subscriber)
    
    }

    Write-Log -message "Loaded $( $subscribers.count ) subscribers detail data"


    #-----------------------------------------------
    # LOAD TAG DATA FROM KLICKTIPP
    #-----------------------------------------------

    # https://support.klicktipp.com/article/393-api-function-overview

    Write-Log -message "Loading tags"
    
    $restParams = $defaultRestParams + @{
        "Method" = "Get"
        "Uri" = "$( $settings.base )/tag.json"
    }
    
    # This call will only get the tags
    $tagIndex = Invoke-RestMethod @restParams
    
    # Get Details
    $tags = [System.Collections.ArrayList]@()
    $tagIndex.psobject.members | where { $_.MemberType -eq "NoteProperty" } | ForEach {
        $tag = $_
        [void]$tags.add([PSCustomObject]@{
            "id" = $tag.Name
            "name" = $tag.Value
        })
    }

    Write-Log -message "Loaded $( $tags.count ) tags"

    <#    
    # Get Details
    $tags = [System.Collections.ArrayList]@()
    $tagIndex | ForEach {

        $tagId = $_
        $restParams = $defaultRestParams + @{
            "Method" = "Get"
            "Uri" = "$( $settings.base )/tag/$( $tagId ).json"
        }
        $tag = Invoke-RestMethod @restParams
        [void]$tags.Add($tag)
    
    }
    #>
    

    #-----------------------------------------------
    # LOAD FIELD DATA FROM KLICKTIPP
    #-----------------------------------------------

    Write-Log -message "Loading fields"

    $restParams = $defaultRestParams + @{
        "Method" = "Get"
        "Uri" = "$( $settings.base )/field.json"
    }
    
    # This call will get the fields with their names
    $fieldIndex = Invoke-RestMethod @restParams
    
    Write-Log -message "Loaded $( $fieldIndex.count ) fields"


    # TODO [x] get fields maybe and insert into postgresql
    # TODO [x] get tags and insert into postgresql




    #-----------------------------------------------
    # MAKE NEW CONNECTION TO DATABASE
    #-----------------------------------------------

    # TODO [x] add connection string to settings
    # TODO [x] add schema to settings
    # TODO [x] add rowtype to settings
    $schema = $settings.postgresSchema
    $typeName = $settings.postgresTypename

    $connection = [Npgsql.NpgsqlConnection]::new()
    $connection.ConnectionString = Get-SecureToPlaintext $settings.postgresConnString #"Host=localhost;Port=5432;Username=postgres;Password=xxx;Database=postgres;Client Encoding=UTF8;Encoding=UTF8"
    $connection.Open()


    #-----------------------------------------------
    # CHECK ROWTYPE AND REPLACE IF EXISTS
    #-----------------------------------------------

    $cmd = $connection.CreateCommand()

    $cmd.CommandText = @"
    SELECT EXISTS (
		SELECT 1
		FROM pg_type t
		LEFT JOIN pg_namespace p ON t.typnamespace = p.oid
		WHERE t.typname = '$( $typename )'
			AND p.nspname = '$( $schema )'
		);
"@

    # load data
    $datatable = [System.Data.DataTable]::new()
    $sqlResult = $cmd.ExecuteReader()
    $datatable.Load($sqlResult, [System.Data.Loadoption]::Upsert)

    # Remove if it exists
    if ( $datatable.exists -eq $true ) {
        $cmd = $connection.CreateCommand()
        $cmd.CommandText = "DROP TYPE ""$( $schema )"".""$( $typename )"""
        $cmd.ExecuteNonQuery()
    }
    
    # Add datatype with properties of json
    $arraysAndObjects = @("tags","smart_tags","outbound","manual_tags")
    $properties = $subscribers | Get-Member -MemberType NoteProperty | where { $_.Name -notin $arraysAndObjects } | Select Name, @{name="sqltype";expression={ """$( $_.Name )"" text" }}
    $cmd = $connection.CreateCommand()
    $cmd.CommandText = "CREATE TYPE ""$( $schema )"".""$( $typename )"" as ($( $properties.sqltype -join ', ' ));"
    $cmd.ExecuteNonQuery()
    

    #-----------------------------------------------
    # PREPARE QUERIES FOR INSERTING DATA
    #-----------------------------------------------

    # Prepare command for inserting rows
    $insertStatementItems = @"
    INSERT INTO
        $( $schema )."Test" ("id", "object", "ExtractTimestamp", "properties")
    VALUES
        (@id, @object, @extracttimestamp, @properties)
"@

    #-----------------------------------------------
    # LOADING DATA FROM KLICKTIPP INTO SQLITE
    #-----------------------------------------------
    
    $extractTimestamp = [long]$timestamp.tostring("yyyyMMddHHmmss")
    $insertedRows = 0
    $t = Measure-Command {

        #-----------------------------------------------
        # LOADING SUBSCRIBERS ITEMS
        #-----------------------------------------------

        $transaction = $connection.BeginTransaction()
        $insertedSubscribers = 0
        $subscribers | ForEach {

            $row = $_

            # Prepare statement
            $command = $connection.CreateCommand()
            $command.CommandText = $insertStatementItems
            
            # Add all fields
            [void]$command.Parameters.AddWithValue("@object", "subscriber")        
            [void]$command.Parameters.AddWithValue("@extracttimestamp", $extractTimestamp)
            [void]$command.Parameters.AddWithValue("@id", $row.id)

            # Add json value
            $jsonParam = [Npgsql.NpgsqlParameter]::new("@properties",[NpgsqlTypes.NpgsqlDbType]::json)
            $jsonParam.Value = ( $row | ConvertTo-Json -Compress -Depth 99 )
            $command.Parameters.Add($jsonParam)

            # Prepare and insert
            [void]$command.Prepare()
            $insertedSubscribers += $command.ExecuteNonQuery()

        }
        $transaction.Commit()
        Write-Log -message "Inserted $( $insertedSubscribers ) items in total"
        $insertedRows += $insertedSubscribers


        #-----------------------------------------------
        # LOADING TAGS ITEMS
        #-----------------------------------------------

        $transaction = $connection.BeginTransaction()
        $command = $connection.CreateCommand()
        $command.CommandText = $insertStatementItems
        [void]$command.Parameters.AddWithValue("@object", "tags")        
        [void]$command.Parameters.AddWithValue("@extracttimestamp", $extractTimestamp)
        [void]$command.Parameters.AddWithValue("@id", 0)
        $jsonParam = [Npgsql.NpgsqlParameter]::new("@properties",[NpgsqlTypes.NpgsqlDbType]::json)
        $jsonParam.Value = ( $tagIndex | ConvertTo-Json -Compress -Depth 99 )
        $command.Parameters.Add($jsonParam)

        <#
        $tags | ForEach {

            $row = $_

            # Prepare statement
            $command = $connection.CreateCommand()
            $command.CommandText = $insertStatementItems
            
            # Add all fields
            [void]$command.Parameters.AddWithValue("@object", "tags")        
            [void]$command.Parameters.AddWithValue("@extracttimestamp", $extractTimestamp)
            [void]$command.Parameters.AddWithValue("@id", $row.id)

            # Add json value
            $jsonParam = [Npgsql.NpgsqlParameter]::new("@properties",[NpgsqlTypes.NpgsqlDbType]::json)
            $jsonParam.Value = ( $row | ConvertTo-Json -Compress -Depth 99 )
            $command.Parameters.Add($jsonParam)

            # Prepare and insert
            [void]$command.Prepare()
            $insertedTags += $command.ExecuteNonQuery()

        }
        #>
        $transaction.Commit()
        Write-Log -message "Inserted tags"
        $insertedRows += 1


        #-----------------------------------------------
        # LOADING FIELDS ITEMS
        #-----------------------------------------------

        $transaction = $connection.BeginTransaction()
        $command = $connection.CreateCommand()
        $command.CommandText = $insertStatementItems
        [void]$command.Parameters.AddWithValue("@object", "fields")        
        [void]$command.Parameters.AddWithValue("@extracttimestamp", $extractTimestamp)
        [void]$command.Parameters.AddWithValue("@id", 0)
        $jsonParam = [Npgsql.NpgsqlParameter]::new("@properties",[NpgsqlTypes.NpgsqlDbType]::json)
        $jsonParam.Value = ( $fieldIndex | ConvertTo-Json -Compress -Depth 99 )
        $command.Parameters.Add($jsonParam)
        $transaction.Commit()
        Write-Log -message "Inserted fields"
        $insertedRows += 1

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



    <#

/* klicktipp columns */

SELECT t3.*
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test" --, json_to_record(t.properties) AS x(id text, name text);
		) t1
	WHERE rank = 1
	) t2
	,json_populate_record(NULL::"apt"."myrowtype", t2.properties) t3




/* tags */

SELECT id
	,json_array_elements_text(properties -> 'tags')
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test" --, json_to_record(t.properties) AS x(id text, name text);
		) t1
	WHERE rank = 1
	) t2


/* tags lookup */

SELECT je.KEY AS Code
	,je.value AS Description
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test"
		WHERE OBJECT = 'tags'
		) t1
	WHERE t1.rank = 1
	) t2
	,json_each_text(t2.properties) je
    

/* manual tags */

SELECT t2.id
	,t3.KEY
	,t3.value
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test"
		) t1
	WHERE rank = 1
	) t2
	,json_each_text(properties -> 'manual_tags') t3


/* smart_tags */

SELECT t2.id
	,t3.KEY
	,t3.value
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test"
		) t1
	WHERE rank = 1
	) t2
	,json_each_text(properties -> 'smart_tags') t3



/* outbound */


SELECT t2.id
	,t3.KEY
	,t3.value
FROM (
	SELECT *
	FROM (
		SELECT *
			,ROW_NUMBER() OVER (
				PARTITION BY id ORDER BY "ExtractTimestamp" DESC
				) AS rank
		FROM apt."Test"
		) t1
	WHERE rank = 1
	) t2
	,json_each_text(properties -> 'outbound') t3







/* SCV query */

/* This join is made via email */

SELECT coalesce(s1.id, 'isu#' || s2.id, 'kt#' || s3.id) AS id
	,coalesce(s1.email, s2.email, s3.email) AS email
	,s2.id AS isu_id
	,s3.id AS klicktipp_id
	,s3.count AS klicktipp_count
FROM (
	SELECT '789' AS id
		,'test2@example.de' AS email
	) AS s1
FULL OUTER JOIN (
	SELECT '456' AS id
		,'test1@example.de' AS email
	
	UNION ALL
	
	SELECT '123' AS id
		,'test2@example.de' AS email
	) AS s2 ON s1.email = s2.email
FULL OUTER JOIN (
	SELECT id
		,email
		,count
	FROM (
		SELECT id
			,email
			,rank() OVER (
				PARTITION BY email ORDER BY id DESC
				) AS newest_id_rank
			,count(email) OVER (PARTITION BY email)
		FROM (
			SELECT *
				,properties ->> 'email' email
			FROM (
				SELECT *
					,ROW_NUMBER() OVER (
						PARTITION BY id ORDER BY "ExtractTimestamp" DESC
						) AS rank
				FROM apt."Test"
				) t1
			WHERE rank = 1
			) t2
		) t3
	WHERE newest_id_rank = 1
	) AS s3 ON s1.email = s3.email




    #>