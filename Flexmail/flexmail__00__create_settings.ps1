
################################################
#
# START
#
################################################

#-----------------------------------------------
# LOAD SCRIPTPATH
#-----------------------------------------------

if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}

Set-Location -Path $scriptPath


#-----------------------------------------------
# LOAD MORE FUNCTIONS
#-----------------------------------------------

$functionsSubfolder = ".\functions"

"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


#-----------------------------------------------
# ASK FOR SETTINGSFILE
#-----------------------------------------------

# Default file
$settingsFileDefault = "$( $scriptPath )\settings.json"

# Ask for another path
$settingsFile = Read-Host -Prompt "Where do you want the settings file to be saved? Just press Enter for this default [$( $settingsFileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $settingsFile -eq "" -or $null -eq $settingsFile) {
    $settingsFile = $settingsFileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $settingsFile -IsValid ) {
    Write-Host "SettingsFile '$( $settingsFile )' is valid"
} else {
    Write-Host "SettingsFile '$( $settingsFile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR LOGFILE
#-----------------------------------------------

# Default file
$logfileDefault = "$( $scriptPath )\flexmail.log"

# Ask for another path
$logfile = Read-Host -Prompt "Where do you want the log file to be saved? Just press Enter for this default [$( $logfileDefault )]"

# ALTERNATIVE: The file dialog is not working from Visual Studio Code, but is working from PowerShell ISE or "normal" PowerShell Console
#$settingsFile = Set-FileName -initialDirectory "$( $scriptPath )" -filter "JSON files (*.json)|*.json"

# If prompt is empty, just use default path
if ( $logfile -eq "" -or $null -eq $logfile) {
    $logfile = $logfileDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $logfile -IsValid ) {
    Write-Host "Logfile '$( $logfile )' is valid"
} else {
    Write-Host "Logfile '$( $logfile )' contains invalid characters"
}


#-----------------------------------------------
# ASK FOR UPLOAD FOLDER
#-----------------------------------------------

# Default file
$uploadDefault = "$( $scriptPath )\uploads"

# Ask for another path
$upload = Read-Host -Prompt "Where do you want the files to be processed? Just press Enter for this default [$( $uploadDefault )]"

# If prompt is empty, just use default path
if ( $upload -eq "" -or $null -eq $upload) {
    $upload = $uploadDefault
}

# Check if filename is valid
if(Test-Path -LiteralPath $upload -IsValid ) {
    Write-Host "Upload folder '$( $upload )' is valid"
} else {
    Write-Host "Upload folder '$( $upload )' contains invalid characters"
}


################################################
#
# SETUP SETTINGS
#
################################################

#-----------------------------------------------
# SECURITY / LOGIN
#-----------------------------------------------

$user = Read-Host -Prompt "Please enter the userid for flexmail"
$token = Read-Host -AsSecureString "Please enter the token for flexmail"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password)

$login = @{
    user = $user
    token = $tokenEncrypted
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
# ALL SETTINGS TOGETHER
#-----------------------------------------------

$settings = [PSCustomObject]@{
    
    # General settings
    base="https://soap.flexmail.eu/3.0.0/flexmail.php"
    logfile = $logfile
    messageNameConcatChar = " | "

    # Upload settings
    #masterListId = "1669666"
    rowsPerUpload = 800
    changeTLS = $true
    uploadFields = $uploadFields
    uploadFolder = $upload
    
    # Detail settings
    login = $login    
    importSettings = $importSettings
    previewSettings = $previewSettings
    #responseSettings = $responseSettings
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8



################################################
#
# SOME MORE SETTINGS WITH THE API
#
################################################

#-----------------------------------------------
# CHOOSE THE MASTERLIST
#-----------------------------------------------

# TODO [ ] implement choosing the masterlist id

$mailingListsReturn = Invoke-Flexmail -method "GetMailingLists"
$mailingLists = $mailingListsReturn | select @{name="mailingListId";expression={ $_.mailingListId }}, @{name="mailingListName";expression={ $_.mailingListName }} | Out-GridView -PassThru

$settings | Add-Member -MemberType NoteProperty -Name "masterListId" -Value ( ( $mailingLists | select -first 1 ).mailingListId )


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
    "daysToLoad"=14 # the number of last days to load
    "dateFormat"="yyyy-MM-ddTHH:mm:ss"
}

$settings | Add-Member -MemberType NoteProperty -Name "responseSettings" -Value $responseSettings


################################################
#
# SAVE AGAIN WITH FILLED IN SETTINGS
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $settingsFile )" -Encoding UTF8

