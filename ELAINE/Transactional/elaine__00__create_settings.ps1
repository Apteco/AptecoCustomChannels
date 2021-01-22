
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
# AWS SETTINGS
#-----------------------------------------------
<#
$accessKey = Read-Host -AsSecureString "Please enter the access key for AWS S3"
$accessKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$accessKey).GetNetworkCredential().Password) -keyFile $keyFile

$secretKey = Read-Host -AsSecureString "Please enter the secret key for AWS S3"
$secretKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$secretKey).GetNetworkCredential().Password) -keyFile $keyFile


$awsSettings = @{

    accessKey = $accessKeyEncrypted # enter your access key
    secretKey = $secretKeyEncrypted # enter the secret key
    region = "eu-central-1"
    service = "s3"
    endpoint = "https://s3-eu-central-1.amazonaws.com"

}
#>


#-----------------------------------------------
# MAILINGS SETTINGS
#-----------------------------------------------

$mailingsSettings = @{
    #states = @("paused","live") # paused|live
    #recipientListFile = "$( $scriptPath )\recipientlists.json"
    #status = "NEW" # NEW|SENDING|DONE|CANCELED -> default should be "SENDING" for productive use, for testing purposes and fill the lists without an email send, use "NEW"
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
    #sessionFile = "$( $scriptPath )\session.json"                        # name of the session file
    #ttl = 15                                            # Time to live in minutes for the current session, normally 20 minutes for EpiServer Campaign
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    # aws = $awsSettings
    login = $loginSettings
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
