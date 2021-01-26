
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

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}


################################################
#
# SETUP SETTINGS
#
################################################


#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$keyFile = "$( $scriptPath )\aes.key"
$token = Read-Host -AsSecureString "Please enter the password for artegic ELAINE API user"
$tokenEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$token).GetNetworkCredential().Password) #-keyFile $keyFile

$loginSettings = @{
    username = "<username>"
    token = $tokenEncrypted 
}


#-----------------------------------------------
# MAILINGS SETTINGS
#-----------------------------------------------

$mailingsSettings = @{
}

#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email" #Email|Sms
    #"FromAddress"="info@apteco.de"
    #"FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    #"Subject"="Test-Subject"
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{

    "rowsPerUpload" = 80                                # rows per upload, if BULK is used (available since 6.2.2)
    "uploadsFolder" = "$( $scriptPath )\uploads\"       # upload folder where the message status is stored
    "timeout" = 60                                      # max seconds to wait until the message status check will fail
    "priority" = 99                                     # 99 is default value, 100 is for emergency mails           
    "override" = $false                                 # overwrite array data with profile data
    "updateProfile" = $false                            # update existing contacts with array data
    "notifyUrl" = ""                                    # notification url if bounced, e.g. like "http://notifiysystem.de?email=[c_email]"
    "blacklist" = $true                                 # false means the blacklist will be ignored, a group id can also be passed and then used as an exclusion list
    "waitForSuccess" = $true                            # 

    # Those will be filled later in the script
    "requiredFields" = @()                              # additional fields that are required
    "variantColumn" = ""                                # column for variants
    "emailColumn" = ""                                  # column for email
    "urnColumn" = ""                                    # column for urn (primary key)
    "urnContainsEmail" = $true                          # If this is set, the email will be concatenated with the URN like "123|user@example.tld"
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?
# TODO [ ] Documentation of all these parameters and the ones above

$settings = @{

    # General
    base="https://ed92.elaine-asp.de/http/api/"   # Default url
    defaultResponseFormat = "json" # json|text|serialize|xml
    changeTLS = $true                                   # should tls be changed on the system?
    nameConcatChar = " / "                              # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\elaine.log"               # path and name of log file
    providername = "ELN"                                # identifier for this custom integration, this is used for the response allocation
    checkVersion = $true                                # check elaine version for some specific calls
    
    # Session 
    aesFile = $keyFile
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    login = $loginSettings
    preview = $previewSettings
    #mailings = $mailingsSettings
    upload = $uploadSettings

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


################################################
#
# LAST SETTINGS USING THE NEW LOGIN DATA
#
################################################

#-----------------------------------------------
# CREATE HEADERS AND LOGIN SETUP
#-----------------------------------------------

Create-ELAINE-Parameters


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

$fields = Invoke-ELAINE -function "api_getDatafields"


#-----------------------------------------------
# CHOOSE EMAIL FIELD
#-----------------------------------------------

<#
Choose the email field
#>
$emailField = $fields | Out-GridView -PassThru
$settings.upload.emailColumn = $emailField.f_name


#-----------------------------------------------
# CHOOSE URN FIELD
#-----------------------------------------------

<#
Choose the urn field for the primary key
#>
$urnField = $fields | Out-GridView -PassThru
$settings.upload.urnColumn = $urnField.f_name


#-----------------------------------------------
# CHOOSE VARIANT FIELD
#-----------------------------------------------


<#
Choose the variant field, e.g. for language dependent accounts/templates
If there is no variant field, just cancel
#>
$variantField = $fields | Out-GridView -PassThru
$settings.upload.variantColumn = $variantField.f_name


#-----------------------------------------------
# CHOOSE OTHER REQUIRED FIELDS
#-----------------------------------------------

<#
Choose some fields
c_email and c_urn are not needed as required
If there are not more fields, just cancel
#>
$fields = Invoke-ELAINE -function "api_getDatafields"
$requiredFields = $fields | Out-GridView -PassThru
$settings.upload.requiredFields = $requiredFields.f_name


#-----------------------------------------------
# SAVE
#-----------------------------------------------

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8
