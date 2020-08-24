
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
$moduleName = "SYNWALDOWNLOAD"
$processId = [guid]::NewGuid()

<#
$assemblyFile = "$( $scriptPath )\sqlite-netFx46-binary-x64-2015-1.0.112.0\System.Data.SQLite.dll" # download precompiled binaries for .net or "System.Data.SQLite"
$connString = "Data Source=""$( $scriptPath )\syniverse.sqlite"";Version=3;"
$mssqlConnectionString = "Data Source=APTWARSQL1;Initial Catalog=PS_FUG;Trusted_Connection=True;"
#>

# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$walletIds = @("abcdef5","1aptr7","ncmlbf","osdmeh") #hbet0z
$baseUrl = "https://public-api.cm.syniverse.eu"
$companyId = "<companyId>" 
$token = "<token>"


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

# Change encoding to UTF8 for sqlite
#[Console]::OutputEncoding = [text.encoding]::utf8

# create new export folder
$exportId = [guid]::NewGuid()
New-Item -Path $scriptPath -Name $exportId -ItemType Directory


# more settings
$logfile = "wallets.log" #$settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

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
# NOTES
#
################################################


<#


# Loyalty Card Template

SmartLink: https://mpages.cm.syniverse.eu/c/icsjv5

Fields:
{{first_name}} : First Name of the end-user
{{last_name}} : Last Name of the end-user
{{points}} : Points balance of the end-user
{{qrcode}} : QR Code’s code/number
{{qrcodetext}} : QR Code’s text underneath of the QR Code
{{content1}} : At the back of the pass, additional content of the first area

Example: https://mpages.cm.syniverse.eu/c/icsjv5/20191006?data[first_name]=Zeynep&data[last_name]=Ozyer&data[points]=100&data[qrcode]=23747364&data[qrcodetext]=Thank%20You&data[content1]=You%20can%20also%20book%20your%20demo%20now%3Ahttps%3A%2F%2Fwww.apteco.com%2Fbook-a-demo

# Offer Card Template

SmartLink: https://mpages.cm.syniverse.eu/c/1aptr7

Fields:
{{first_name}} : First Name of the end-user
{{last_name}} : Last Name of the end-user
{{code}} : Voucher special code as a column
{{qrcode}} : QR Code’s code/number
{{qrcodetext}} : QR Code’s text underneath of the QR Code


Example: https://mpages.cm.syniverse.eu/c/1aptr7/20191006?data[first_name]=Zeynep&data[last_name]=Ozyer&data[code]=Apt10&data[qrcode]=27364&data[qrcodetext]=Thank%20You



# General

* Our Wallet Manager platform enables updates to offers and loyalty cards already saved to a Person's Apple Wallet/Passbook or Google Wallet/Android Pay application. Mobile Wallet Campaigns cannot be created with an API, they must be created through the Wallet Manager UI.
* Each Company can have one or more Mobile Wallet Campaigns active at any given time. A Mobile Wallet Campaign is a template and a definition of a Wallet Item. A Wallet Item is a specific instance of a Mobile Wallet Campaign template that has been installed on one or more devices for a Person. 
* A Wallet Item can contain content, like brand logo, that is common to all other Persons participating in the campaign. A Wallet Item can also contain Person-specific information like a name or loyalty point balance. Only Person-specific information can be updated with an API. Common content can be updated through the UI.


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
# GET WALLETS
#
################################################


$contentType = "application/json" 

$headers = @{
    "Authorization"="Basic $( $token )"
    "X-API-Version"="2"
    "int-companyid"=$companyId # correct?
}


$walletDetails = @()
$walletIds | ForEach {
    $walletId = $_
    $walletUrl = "$( $baseUrl )/companies/$( $companyId )/campaigns/wallet/$( $walletId )"
    $walletDetails += Invoke-RestMethod -ContentType $contentType -Method Get -Uri $walletUrl -Headers $headers
}

$walletFile = "$( $scriptPath )\$( $exportId )\wallets.csv"
$walletDetails | Export-Csv -Path "$( $walletFile )" -Encoding UTF8 -Force -Delimiter "`t" -NoTypeInformation

exit 0

#$walletDetails | export-csv 

################################################
#
# GET RESPONSES
#
################################################

$walletItems = @()
$walletDetails | ForEach {
    $walletDetail = $_
    $walletItemsUrl = "$( $baseUrl )$( $walletDetail.url )/items"
    $walletItems += Invoke-RestMethod -ContentType $contentType -Method Get -Uri $walletItemsUrl -Headers $headers
}

#$walletItems | Out-GridView

#$walletItems | convertto-json -depth 8 | Out-File -filepath "$( $scriptPath )_wallets.json" -Encoding utf8

#$walletItems | Export-Csv -Path "$( $scriptPath )\wallets.csv" -Encoding UTF8 -Force -Delimiter "`t" -NoTypeInformation

$walletItemsFile = "$( $scriptPath )\$( $exportId )\wallet_items.csv"
$walletItems |
    select wallet_item_id, group_code, active, @{name="wallet_id";expression={ $_.campaign_ref.id }}, @{name="wallet_type";expression={ $_.campaign_ref.type }}, @{name="provider";expression={ $_.provider }},url,created_at, updated_at |
    Export-Csv -Path "$( $walletItemsFile )" -Encoding UTF8 -Force -Delimiter "`t" -NoTypeInformation



################################################
#
# GET TOKENS
#
################################################

#$walletItems | select wallet_item_id -expand tokens | convertto-json -depth 8 | Out-File -filepath "$( $scriptPath )\wallet_items_tokens.json" -Encoding utf8

$keyvalueTokens = @()
$walletItems | select wallet_item_id, updated_at -expand tokens | ForEach {
    
    $item = $_
    $kv = New-Object -TypeName PSCustomObject
    $kv | Add-Member -MemberType NoteProperty -Name "key" -Value $item.wallet_item_id
    $kv | Add-Member -MemberType NoteProperty -Name "value" -Value ( $item | ConvertTo-Json -Compress )
    $kv | Add-Member -MemberType NoteProperty -Name "time" -Value $item.updated_at

    $keyvalueTokens += $kv

}

#$keyvalue | Out-GridView

$tokenFile = "$( $scriptPath )\$( $exportId )\wallet_item_tokens.csv"
$keyvalueTokens | Export-Csv -Delimiter "`t" -Path "$( $tokenFile )" -NoTypeInformation -Encoding UTF8



################################################
#
# GET LOCATIONS
#
################################################

#$walletItems | select wallet_item_id -expand locations | convertto-json -depth 8 | Out-File -filepath "$( $scriptPath )\wallet_items_locations.json" -Encoding utf8

$keyvalueLocations = @()
$walletItems | select wallet_item_id, updated_at -expand locations | ForEach {
    
    $item = $_
    $kv = New-Object -TypeName PSCustomObject
    $kv | Add-Member -MemberType NoteProperty -Name "key" -Value $item.wallet_item_id
    $kv | Add-Member -MemberType NoteProperty -Name "value" -Value ( $item | ConvertTo-Json -Compress )
    $kv | Add-Member -MemberType NoteProperty -Name "time" -Value $item.updated_at

    $keyvalueLocations += $kv

}

#$keyvalue | Out-GridView

$locationFile = "$( $scriptPath )\$( $exportId )\wallet_item_locations.csv"
$keyvalueLocations | Export-Csv -Delimiter "`t" -Path "$( $locationFile )" -NoTypeInformation -Encoding UTF8

exit 0

################################################
#
# INSERT FILES IN SQLITE
#
################################################

$walletFile = Sanitize-FilenameSQLITE -Filename $walletFile
$walletItemsFile = Sanitize-FilenameSQLITE -Filename $walletItemsFile
$tokenFile = Sanitize-FilenameSQLITE -Filename $tokenFile
$locationFile = Sanitize-FilenameSQLITE -Filename $locationFile

".mode csv",".separator \t",".import $( $walletFile ) wallets" | .\sqlite3.exe syniverse.sqlite
".mode csv",".separator \t",".import $( $walletItemsFile ) wallet_items" | .\sqlite3.exe syniverse.sqlite
".mode csv",".separator \t",".import $( $tokenFile ) wallet_item_tokens" | .\sqlite3.exe syniverse.sqlite
".mode csv",".separator \t",".import $( $locationFile ) wallet_item_locations" | .\sqlite3.exe syniverse.sqlite


################################################
#
# READ DATA FROM SQLITE
#
################################################

[Reflection.Assembly]::LoadFile($assemblyFile) 

$sqlCommand = "select wallet_item_id from wallet_items_unique where wallet_item_id not in ( select CommunicationKey from wallet_x_urn )"

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




################################################
#
# READ DATA FROM MSSQL
#
################################################

Add-Type -AssemblyName System.Data  #, System.Text.Encoding

# the enviroment variable fills from the designer user defined variables


$mssqlConnection = New-Object System.Data.SqlClient.SqlConnection
$mssqlConnection.ConnectionString = $mssqlConnectionString

$mssqlConnection.Open()

$urns = "'$( $data.tables.rows.wallet_item_id -join "','" )'"
$mssqlQuery = @"
SELECT [Urn]
      ,format([CommunicationTime],'yyyy-MM-dd HH:mm:ss') as [CommunicationTime]
      ,[CommunicationKey]
      ,[UrnDefinitionId]
      ,[AgentUrn]
  FROM [PS_FUG].[dbo].[Communications]
  where CommunicationTime >= DateAdd(day,-2,GetDate())
   and lower([CommunicationKey]) in ($( $urns ))
"@


"Trying to load the data from MSSQL"

# define query -> currently the age of the date in the query has to be less than 12 hours
#$mssqlQuery = “Select * from dbo.JobStatus where Job = 'ArtikeldatenMaterialisieren' and datediff(hh, [Letztebereitstellung], GETDATE()) <= 12 " #and Letztebereitstellung > dateadd(day,-1, getdate())"
#    "'$( $data.tables.rows.wallet_item_id -join "','" )'"
# execute command
$mssqlCommand = $mssqlConnection.CreateCommand()
$mssqlCommand.CommandText = $mssqlQuery
$mssqlResult = $mssqlCommand.ExecuteReader()
    
# load data
$mssqlTable = new-object “System.Data.DataTable”
$mssqlTable.Load($mssqlResult)

$mssqlTable
    
# check for result
#$mssqlSuccess = ( $mssqlTable | Select -First 1 ).BUSINESS_UNIT
$mssqlSuccess = $mssqlTable.rows.Count -gt 0

$mssqlConnection.Close()


################################################
#
# EXPORT DATA FROM MSSQL
#
################################################

$walletUrnFile = Sanitize-FilenameSQLITE -Filename "$( $scriptPath )\$( $exportId )\wallet_urns.csv"
$mssqlTable | Export-Csv -Path $walletUrnFile -Encoding UTF8 -Force -Delimiter "`t" -NoTypeInformation
".mode csv",".separator \t",".import $( $walletUrnFile ) wallet_x_urn" | .\sqlite3.exe syniverse.sqlite


################################################
#
# EXPORT DATA FROM SQLITE
#
################################################


$sqlCommand = "select * from wallet_urn_latest" #wallet_urn_unique"


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



$data.tables.rows | Export-Csv -Path "D:\FastStats\PUBLISH\FUG\public\Variables\wallet_x_urn_latest.csv" -Encoding UTF8 -Force -Delimiter "`t" -NoTypeInformation


<#
sqlite> .header on
sqlite> .mode csv
sqlite> .once c:/work/dataout.csv
sqlite> SELECT * FROM tab1;
sqlite> .system c:/work/dataout.csv

#>

# return something
$walletItems | select @{name="id";expression={ $_.wallet_item_id }}, @{name="name";expression={ $_.tokens.first_name + " " + $_.tokens.last_name }}