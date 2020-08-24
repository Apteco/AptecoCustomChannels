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
        "TransactionType" = "Replace"
        "Password" = "b"
        "scriptPath" = "D:\Scripts\Syniverse\WalletUpdate"
        "MessageName" = "abcde5 | Apteco Demo"
        "EmailFieldName" = "Email"
        "SmsFieldName" = "WalletUrl"
        "Path" = "d:\faststats\Publish\Handel\system\Deliveries\abcde5  Apteco Demo_9fd79edf-6bd3-45ff-8dc1-5fb78e0cd3ba.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "abcde5 | Apteco Demo"
        "CommunicationKeyFieldName" = "Communication Key"
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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "SYNWALUPDATE"
$processId = [guid]::NewGuid()


# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{
    nameConcatChar = " | "
    logfile = "wallets.log"
}

# TODO [ ] put all settings back into settings.json

$walletIds = @("abcde5")
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>"
$token = "<token>"
$mssqlConnectionString = "Data Source=localhost;Initial Catalog=RS_Handel;User Id=faststats_service;Password=abc123;"

# Current timestamp
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
#if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
#}

# more settings
$logfile = $settings.logfile

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

<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>



################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments: $( [Environment]::GetCommandLineArgs() )"

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    $( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# UPDATE SINGLE WALLET SILENTLY
#-----------------------------------------------

<#
The following will perform a net change update to an existing Wallet item.

For Persons with Apple Wallet/Passbook Wallet items, the update to the Person s device will occur automatically if the application is configured to support server-pushed updates (this is controlled by the Person via the Passbook Mobile Application). The Person is also able to manually request an update via the Passbook Mobile Application. For Persons with Android Pay/Google Wallet items, the update to the Person s device will occur automatically via Google Wallet web services.
The wallet_item_id, campaign_ref, url, provider, created_at, and updated_at fields cannot be updated. Any values specified in the request body will be ignored.
Any fields that are specified will be updated with the new values. Any fields whose value is set to Null will be removed from the Wallet item. Any fields completely omitted will be ignored and any existing values will remain.
The only fields that will be updated on the Wallet object are: tokens, locations, and group_code

}

#>

#-----------------------------------------------
# PREPARE
#-----------------------------------------------

$contentType = "application/json" 

$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId 
}

$campaignId = $params.MessageName -split $settings.nameConcatChar | select -First 1

#-----------------------------------------------
# READ FILE
#-----------------------------------------------

$dataWallets = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8

Write-Log -message "Got a file with no of rows: $( $dataWallets.Count )"


#-----------------------------------------------
# READ CURRENT TOKENS FROM SQLITE
#-----------------------------------------------
<#
$assemblyFile = "D:\FastStats\Scripts\syniverse\sqlite-netFx46-binary-x64-2015-1.0.112.0\System.Data.SQLite.dll" # download precompiled binaries for .net or "System.Data.SQLite"
[Reflection.Assembly]::LoadFile($assemblyFile) 
$connString = "Data Source=""$( $scriptPath )\syniverse.sqlite"";Version=3;"
$sqlCommand = "select * from wallet_tokens_latest"

$conn = New-Object -TypeName System.Data.SQLite.SQLiteConnection
$conn.ConnectionString = $connString
$conn.Open()

$cmd = New-Object -TypeName System.Data.SQLite.SQLiteCommand
$cmd.CommandText = $sqlCommand
$cmd.Connection = $conn

$dataAdapter = New-Object -TypeName System.Data.SQLite.SQLiteDataAdapter
$dataAdapter.SelectCommand = $cmd

$data = New-Object -TypeName System.Data.DataSet
$dataAdapter.fill($data)
#$data.tables.rows | Out-GridView

$dataAdapter.Dispose()
$cmd.Dispose()
$conn.Dispose()

Write-Log -message "Got no of wallet tokens: $( $data.tables.rows.count )"
#>

#-----------------------------------------------
# READ CURRENT TOKENS FROM MSSQL
#-----------------------------------------------

Write-Log -message "Loading tokens $( $params.MessageName )"

$mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

"Trying to load the data from MSSQL"

$mssqlQuery = @"
SELECT * FROM [Live_Webhooks].[dbo].[Wallets_Existing] where campaign_token = '$( $campaignId )'
"@

# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = new-object System.Data.DataTable
$mssqlTable.Load($mssqlResult)
    
# close connection
$mssqlConnection.Close()

Write-Log -message "Got no of wallet tokens: $( $mssqlTable.rows.count )"


#-----------------------------------------------
# UPDATE WALLETS
#-----------------------------------------------

$results = @()
$dataWallets | ForEach { #| where { $_."first_name" -eq "Florian" }

    $row = $_
    $rowId = $row."$( $params.SmsFieldName )" #$row."$( $params.UrnFieldName )"

    $newItem = New-Object -TypeName PSCustomObject

    # Get Tokens for that wallet/urn
    $tokenRow = $mssqlTable.Rows | where { $_.url -eq $rowId }  #$data.Tables.rows | where { [int]$_.Urn -eq [int]$rowId }
    $tokens = $tokenRow.tokens | ConvertFrom-Json  #$tokenRow.value | ConvertFrom-Json 

    # See, which tokens have changed
    $tokens.psobject.Members | where-object membertype -like 'noteproperty' | ForEach {
    
        $tokenKey = $_.Name
        if ( $row."$( $tokenKey )" ) { # if the field from the campaign is setted
            if ( $row."$( $tokenKey )" -ne $tokens."$( $tokenKey )" ) { # if the values are different
               
                # new value
                $newValue = $row."$( $tokenKey )"

                switch ( $newValue.Substring(0,1) ) {
                    
                    # add value
                    "+" {
                        $newItem | Add-Member -MemberType NoteProperty -Name $tokenKey -Value ( [double]$newValue + [double]$tokens."$( $tokenKey )")
                    }

                    # subtract value
                    "-" {
                        $newItem | Add-Member -MemberType NoteProperty -Name $tokenKey -Value ( [double]$newValue - [double]$tokens."$( $tokenKey )")
                    }

                    # replace value
                    default {
                        $newItem | Add-Member -MemberType NoteProperty -Name $tokenKey -Value $newValue
                    }                
                }
            }
        }
    }

    # prepare the tokens to be updated
    $updateBody = @{
               "tokens"=$newItem               
               "locations"=@(@{
                    "latitude" = 49.774040
                    "longitude" = 7.164084
                    "relevant_text"="Visit Someone"
               },@{
                    "latitude" = 51.521304
                    "longitude" = -0.144838
                    "relevant_text"="Visit RIBA in London"
               })
               "message"=@{
                     "template"="Enjoy your update"
                     "header"="Enjoy your update"
                     #"image_url":"http://www.google.com/wallet.jpg"
                  }
                "google_wallet"= @{
                    "messages"= @(,
                    @{
                        "header"= "Enjoy your update"
                        "body"= "Enjoy your update"
                        "action_uri"= "https://www.apteco.com"
                        #"image_uri": "http://www.vibes.com/sites/all/themes/vibes/images/logo.png"
                    }
                )
                }
               <#
               "passbook"= @{
                  "notification"= "This is a notification"
                }
                #>                
           } | ConvertTo-Json -Depth 8 -Compress


           <#

           "locations": [
      {
        "latitude": 43.6867,
        "longitude": -85.0102,
        "relevant_text": "Visit our State St store"
      }

      "passbook": {
      "notification": "This is a notification"
    },



    "message":{
         "template":"This is the updated message I would like to send.",
         "header":"Header, for Android Pay only.",
         "image_url":"http://www.google.com/wallet.jpg"
      },

      "google_wallet": {
      "messages": [
        {
          "header": "Message",
          "body": "This is a message",
          "action_uri": "http://vibescm.com",
          "image_uri": "http://www.vibes.com/sites/all/themes/vibes/images/logo.png"
        }
      ]
    },

      #>




    # log  
    Write-Log -message "Update wallet $( $row.WalletUrl ) with: $( $updateBody )"

    # update via REST API
    $walletItemDetailUrl = "$( $baseUrl )$( $rowId )"
    $updateResponse = Invoke-RestMethod -ContentType $contentType -Method Put -Uri $walletItemDetailUrl -Headers $headers -Body $updateBody -Verbose

    $results += $updateResponse

    # remove body information
    $updateBody = @{}
    
}


Write-Log -message "Done!"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# TODO [ ] check return results

# count the number of successful upload rows
$recipients = $results.count # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference for the upload in Epi
$transactionId = 0 #$recipientListID

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername

}

# return the results
$return

