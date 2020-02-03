Function Query-SQLServer {

    param(
         [Parameter(Mandatory=$true)][string]$connectionString 
        ,[Parameter(Mandatory=$true)][string]$query 
    )

    try {

        # build connection
        $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        $mssqlConnection.ConnectionString = $connectionString 
        $mssqlConnection.Open()
        
        # execute command
        $mssqlCommand = $mssqlConnection.CreateCommand()
        $mssqlCommand.CommandText = $query
        $mssqlResult = $mssqlCommand.ExecuteReader()
        
        # load data
        $result = new-object "System.Data.DataTable"
        $result.Load($mssqlResult)

        # return result datatable
        return $result

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        #Write-Log -message "Error: $( $errText )"

    } finally {
        
        # close connection
        $mssqlConnection.Close()

    }

}

Function NonQuery-SQLServer {

    param(
         [Parameter(Mandatory=$true)][string]$connectionString 
        ,[Parameter(Mandatory=$true)][string]$command 
    )

    try {

        # build connection
        $mssqlConnection = New-Object "System.Data.SqlClient.SqlConnection"
        $mssqlConnection.ConnectionString = $connectionString 
        $mssqlConnection.Open()
        
        # execute command
        $mssqlCommand = $mssqlConnection.CreateCommand()
        $mssqlCommand.CommandText = $command
        $result = $mssqlCommand.ExecuteNonQuery()
        
        # return result datatable
        return $result

    } catch [System.Exception] {

        $errText = $_.Exception
        $errText | Write-Output
        #Write-Log -message "Error: $( $errText )"

    } finally {
        
        # close connection
        $mssqlConnection.Close()

    }

}