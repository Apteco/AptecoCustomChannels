
################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
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


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# SETUP SETTINGS
#
################################################


#-----------------------------------------------
# SECURITY / LOGIN
#-----------------------------------------------

$token = Read-Host -AsSecureString "Please enter the token for flexmail"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password)

$login = @{
    user = <clientid>
    token = $tokenEncrypted
}

# Create login object to be able to fetch data in this script itself
$settings = @{
    base="https://soap.flexmail.eu/3.0.0/flexmail.php"
    login = $login
}

#-----------------------------------------------
# LIST IMPORT SETTINGS
#-----------------------------------------------

# sometimes the language field is not filled per uploaded row, than it is better to remove it from this array and set it through the default language
$uploadFields = @(
    "emailAddress",
    "title",
    "name",
    "surname",
    "city",
    "province",
    "country",
    "phone",
    "fax",
    "mobile",
    "website",
    "language",
    "gender",
    "birthday",
    "company",
    "market",
    "activities",
    "employees",
    "nace",
    "turnover",
    "vat",
    "keywords",
    "free_field_1",
    "free_field_2",
    "free_field_3",
    "free_field_4",
    "free_field_5",
    "free_field_6",
    "custom",
    "barcode",
    "referenceId",
    "zipcode",
    "address",
    "function"
)

$importSettings = @{
        "overwrite"=1 #1|0
        "synchronise"=0 #1|0
        "allowDuplicates"=0 #1|0
        "allowBouncedOut"=0 #1|0
        "defaultLanguage"="de" #nl, fr, en, de, it, es, ru, da, se, zh, pt, pl
        "referenceField"="email" # one of those: https://flexmail.be/nl/api/manual/type/80-referencefieldtype
}


#-----------------------------------------------
# EMAIL PREVIEW DEFAULT VALUES
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email" #Email|Sms
    "FromAddress"="info@apteco.de"
    "FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    "Subject"="Test-Subject"
}


#-----------------------------------------------
# RESPONSE DOWNLOAD SETTINGS
#-----------------------------------------------

# Get Campaigns List first
$campaigns = Invoke-Flexmail -method "GetCampaigns"
$campaignArray = $campaigns | Out-GridView -PassThru # example id is: 7275152   
$campaignArray = $campaignArray.campaignId

# Put Response settings together
$responseSettings = @{
    "responseFolder"="$( $scriptPath )\responses"
    "campaignsToDownload"=$campaignArray
    "daysToLoad"=7 # the number of last days to load
    "dateFormat"="yyyy-MM-ddTHH:mm:ss"
}


#-----------------------------------------------
# ALL SETTINGS TOGETHER
#-----------------------------------------------

$settings = @{
    base="https://soap.flexmail.eu/3.0.0/flexmail.php"
    login = $login
    masterListId = "1669666"
    rowsPerUpload = 800
    changeTLS = $true
    uploadFields = $uploadFields
    logfile = "$( $scriptPath )\flexmail.log"
    importSettings = $importSettings
    previewSettings = $previewSettings
    messageNameConcatChar = " | "
    responseSettings = $responseSettings
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8

