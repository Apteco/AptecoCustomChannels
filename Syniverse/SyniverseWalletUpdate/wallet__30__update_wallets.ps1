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
        "scriptPath" = "D:\Scripts\Syniverse\WalletUpdate_v2"
        "MessageName" = "all | Use all wallet campaigns - no filter"
        "EmailFieldName" = "Email"
        "SmsFieldName" = "WalletUrl"
        "Path" = "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\Syniverse\SyniverseWalletUpdate\PowerShell_all  Use all wallet campaigns - no filter_c5f92c51-08e9-4db0-b1f0-b9670cefc0d4.txt"
        "ReplyToEmail" = ""
        "Username" = "a"
        "ReplyToSMS" = ""
        "UrnFieldName" = "Kunden ID"
        "ListName" = "all | Use all wallet campaigns - no filter"
        "CommunicationKeyFieldName" = "Communication Key"
    }
}

################################################
#
# NOTES
#
################################################

<#

# TODO [ ] implement rate limiting of vibes

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
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "SYNWALUPDATE"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
# TODO [x] change this path back

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

# Current timestamp
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

# more settings
$logfile = $settings.logfile
#$mssqlConnectionString = $settings.responseDB


# append a suffix, if in debug mode
if ( $debug ) {
  $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

#Add-Type -AssemblyName System.Data  #, System.Text.Encoding

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
# PROGRAM
#
################################################


#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


#-----------------------------------------------
# UPDATE SINGLE WALLET SILENTLY
#-----------------------------------------------

<#
The following will perform a net change update to an existing Wallet item.

For Persons with Apple Wallet/Passbook Wallet items, the update to the Person s device will occur automatically if the application is configured to support server-pushed updates (this is controlled by the Person via the Passbook Mobile Application). The Person is also able to manually request an update via the Passbook Mobile Application. For Persons with Android Pay/Google Wallet items, the update to the Person s device will occur automatically via Google Wallet web services.
The wallet_item_id, campaign_ref, url, provider, created_at, and updated_at fields cannot be updated. Any values specified in the request body will be ignored.
Any fields that are specified will be updated with the new values. Any fields whose value is set to Null will be removed from the Wallet item. Any fields completely omitted will be ignored and any existing values will remain.
The only fields that will be updated on the Wallet object are: tokens, locations, and group_code

#>

#-----------------------------------------------
# AUTHENTICATION + HEADERS
#-----------------------------------------------

$baseUrl = $settings.base
$contentType = $settings.contentType
$headers = @{
    "Authorization"="Basic $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
    "X-API-Version"="2"
    "int-companyid"=$settings.companyId
}


#-----------------------------------------------
# LOAD WALLET CAMPAIGN + LOAD DETAILS
#-----------------------------------------------

$chosenCampaign = [Mailing]::new($params.MessageName)
#$campaignId = $params.MessageName -split $settings.nameConcatChar | select -First 1
$campaignId = $chosenCampaign.mailingId

# Details not needed at the moment
<#
if ( $campaignId -ne "all" ) {

    $param = @{
        "Uri" = "$( $baseUrl )/companies/$( $settings.companyId )/campaigns/wallet/$( $campaignId )"
        "ContentType" = $contentType
        "Method" = "Get"
        "Headers" = $headers
        "Verbose" = $true
    }
    $walletDetails = Invoke-RestMethod @param
}
#>

#-----------------------------------------------
# READ FILE
#-----------------------------------------------

$data = @( Import-Csv -Path "$( $params.Path )" -Delimiter "`t" -Encoding UTF8 )

Write-Log -message "Got a file with no of rows: $( $data.Count )"


#-----------------------------------------------
# FILTER ENTRIES BY CHOSEN WALLET CAMPAIGN
#-----------------------------------------------

if ( $campaignId -ne "all" ) {
    $dataWallets = $data | where { $_."$( $params.SmsFieldName )" -like "*$( $campaignId )*" }
} else {
    $dataWallets = $data
}

Write-Log -message "Filtered file down to $( $dataWallets.Count ) because of wallet campaign '$( $campaignId )'"


#-----------------------------------------------
# READ CURRENT TOKENS FROM MSSQL
#-----------------------------------------------
<#
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
#>

#-----------------------------------------------
# PREPARE DATA TO UPLOAD
#-----------------------------------------------


# Check which meta fields to upload
$excludeFields = [System.Collections.ArrayList]@()
( $settings.upload.excludeFields.psobject.Members | where { $_.Membertype -eq "NoteProperty" -and $_.Value -eq $false } ) | ForEach {
    $fieldToExclude = $_.Name
    [void]$excludeFields.Add($params.$fieldToExclude)
}
Write-Log -message "Will exclude the fields $( $excludeFields -join "," ) from upload"

# Prepare the data
$parsedData = [System.Collections.ArrayList]@()
$dataWallets | ForEach {

    $row = $_   
    $tokens = [PSCustomObject]::new()

    # See, which tokens have changed
    $row.psobject.Members | where { $_.membertype -like 'noteproperty' -and $_.Name -notin @($params.SmsFieldName) -and $_.Name -notin $excludeFields } | ForEach {
        
        $tokenKey = $_.Name
        $newValue = $row."$( $tokenKey )"

        #if ( $row."$( $tokenKey )" ) { # if the field from the campaign is setted
            #if ( $row."$( $tokenKey )" -ne $tokens."$( $tokenKey )" ) { # if the values are different
               
                # new value
                #$newValue = $row."$( $tokenKey )"

        switch ( $newValue.Substring(0,1) ) {
            <#
            # add value
            "+" {
                $newItem | Add-Member -MemberType NoteProperty -Name $tokenKey -Value ( [double]$newValue + [double]$tokens."$( $tokenKey )")
            }

            # subtract value
            "-" {
                $newItem | Add-Member -MemberType NoteProperty -Name $tokenKey -Value ( [double]$newValue - [double]$tokens."$( $tokenKey )")
            }
            #>
            # replace value
            default {
                $tokens | Add-Member -MemberType NoteProperty -Name $tokenKey -Value $newValue
            }                
        }
            #}
        #}
    }

    # add to array
    [void]$parsedData.add([PSCustomObject]@{
        "mdn" = $row."$( $params.SmsFieldName )"
        "tokens" = $tokens
    })

}

Write-Log -message "Prepared $( $parsedData.Count ) records to upload"

# Filenames
$tempFolder = "$( $uploadsFolder )\$( $processId )"
New-Item -ItemType Directory -Path $tempFolder
Write-Log -message "Will save files to temporary directory '$( $tempFolder )'"

# Export data to upload
$parsedData | ConvertTo-Json -Depth 20 | Set-Content -Path "$( $tempFolder )\upload.json" -Encoding UTF8 #-Delimiter "`t" -NoTypeInformation


#-----------------------------------------------
# UPDATE WALLETS
#-----------------------------------------------

$updateResponses = [System.Collections.ArrayList]@()
$parsedData | ForEach {

    $row = $_
    $rowId = $row.mdn

    # prepare the tokens to be updated
    $updateBody = @{
               
        # Change the fields/token
        # A table with first class fields can be found here https://developer.vibes.com/display/APIs/Wallet+Manager+First+Class+Fields
        "tokens"=$row.tokens
        
        # Add locations if you wish to trigger them by lat/long
        <#               
        "locations"=@(@{
            "latitude" = 49.774040
            "longitude" = 7.164084
            "relevant_text"="Visit Someone"
        },@{
            "latitude" = 51.521304
            "longitude" = -0.144838
            "relevant_text"="Visit RIBA in London"
        })
        #>

        # Add another message in the same update
        <#
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
        #>

    } | ConvertTo-Json -Depth 20 -Compress

    # log  
    #Write-Log -message "Update wallet $( $row.WalletUrl ) with: $( $updateBody )"

    # update via REST API
    $walletItemDetailUrl = "$( $baseUrl )$( $rowId )"
    $updateParams = @{
        ContentType = $contentType
        Method = "Put"
        Uri = $walletItemDetailUrl
        Headers = $headers
        Body = $updateBody
        Verbose = $true
    }
    $updateResponse = Invoke-RestMethod @updateParams

    # Add to array
    [void]$updateResponses.add($updateResponse)

    # remove body information
    $updateBody = @{}
    
}

$updateResponses | ConvertTo-Json -Depth 20 | Set-Content -Path "$( $tempFolder )\response.json" -Encoding UTF8
#$uploadErrors | ConvertTo-Json -Depth 20 | Set-Content -Path "$( $tempFolder )\errors.json" -Encoding UTF8

Write-Log -message "Updated $( $updateResponses.count ) wallets"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = $updateResponses.count # ( $importResults | where { $_.Result -eq 0 } ).count

# There is no id reference for the upload in Epi
$transactionId = $processId

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername
    "ProcessId" = $processId

    # More information about the different status of the import
    #"RecipientsIgnored" = 
    #"RecipientsQueued" = $queued
    #"RecipientsSent" = 
    "RecipientsFailed" = $uploadErrors.Count

}

# return the results
$return

