################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)


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


<#
# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
#>
$scriptPath = "D:\FastStats\Scripts\syniverse"
Set-Location -Path $scriptPath





################################################
#
# SETTINGS
#
################################################


# TODO [ ] put all settings back into settings.json

#$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$walletIds = @("abcde5")
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>"
$token = "<token>"


$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId 
}



# Current timestamp
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
#if ( $changeTLSEncryption ) {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
#}

#logfile
$logfile = "$( $scriptPath )\wallet_update.log"

Add-Type -AssemblyName System.Data  #, System.Text.Encoding

$mssqlConnectionString = "Data Source=sqlserver123;Initial Catalog=RS_Handel;Trusted_Connection=True;"



################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}


################################################
#
# FUNCTIONS
#
################################################

# load all functions
. ".\general__00__functions.ps1"



################################################
#
# UPDATE SINGLE WALLET SILENTLY
#
################################################

<#
The following will perform a net change update to an existing Wallet item.

For Persons with Apple Wallet/Passbook Wallet items, the update to the Persons device will occur automatically if the application is configured to support server-pushed updates (this is controlled by the Person via the Passbook Mobile Application). The Person is also able to manually request an update via the Passbook Mobile Application. For Persons with Android Pay/Google Wallet items, the update to the Person�s device will occur automatically via Google Wallet web services.
The wallet_item_id, campaign_ref, url, provider, created_at, and updated_at fields cannot be updated. Any values specified in the request body will be ignored.
Any fields that are specified will be updated with the new values. Any fields whose value is set to Null will be removed from the Wallet item. Any fields completely omitted will be ignored and any existing values will remain.
The only fields that will be updated on the Wallet object are: tokens, locations, and group_code

}

#>



#-----------------------------------------------
# READ FILE
#-----------------------------------------------

$dataWallets = Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with no of rows: $( $dataWallets.Count )" >> $logfile


#-----------------------------------------------
# READ CURRENT TOKENS
#-----------------------------------------------

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

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot no of wallet tokens: $( $data.tables.rows.count )" >> $logfile


#-----------------------------------------------
# UPDATE WALLETS
#-----------------------------------------------

$dataWallets | ForEach { #| where { $_."first_name" -eq "Florian" }

    $row = $_
    $rowId = $row."$( $params.UrnFieldName )"

    $newItem = New-Object -TypeName PSCustomObject

    # Get Tokens for that wallet/urn
    $tokenRow = $data.Tables.rows | where { [int]$_.Urn -eq [int]$rowId }
    $tokens = $tokenRow.value | ConvertFrom-Json 

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
           } | ConvertTo-Json -Compress

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
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUpdate wallet $( $row.WalletUrl ) with: $( $updateBody )" >> $logfile

    # update via REST API
    $contentType = "application/json"
    $walletItemDetailUrl = "$( $baseUrl )$( $row.WalletUrl )"
    $updateResponse = Invoke-RestMethod -ContentType $contentType -Method Put -Uri $walletItemDetailUrl -Headers $headers -Body $updateBody -Verbose

    # remove body information
    $updateBody = @{}
    
}


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tDone!" >> $logfile
