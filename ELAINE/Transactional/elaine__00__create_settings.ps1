
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

    # There are three methods available to load the actionmailings
    # 1 = api_getMessageInfo
    # 2 = api_getActionmails
    # 3 = api_getMailingsByStatus + api_getDetails
    loadMailingsMethod = 2 # 1|2|3
    
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

    "rowsPerUpload"         = 80                            # rows per upload, if BULK is used (available since 6.2.2)
    "uploadsFolder"         = "$( $scriptPath )\uploads\"   # upload folder where the message status is stored
    "initialWaitForStatus"  = 10                            # initial wait of seconds until the status will be firstly checked 
    "checkEveryNSeconds"    = 10                            # seconds to wait if all messages have been sent out
    "timeout"               = 300                            # max seconds to wait until the message status check will fail
    "priority"              = 99                            # 99 is default value, 100 is for emergency mails           
    "override"              = $false                        # overwrite array data with profile data
    "updateProfile"         = $false                        # update existing contacts with array data
    "notifyUrl"             = ""                            # notification url if bounced, e.g. like "http://notifiysystem.de?email=[c_email]"
    "blacklist"             = $true                         # false means the blacklist will be ignored, a group id can also be passed and then used as an exclusion list
    "waitForSuccess"        = $true                         # wait until transactional mailings are sent out

    # Those will be filled later in the script
    "requiredFields"        = @()                           # additional fields that are required
    "variantColumn"         = ""                            # column for variants
    "emailColumn"           = ""                            # column for email
    "urnColumn"             = ""                            # column for urn (primary key)
    "urnContainsEmail"      = $false                         # If this is set, the email will be concatenated with the URN like "123|user@example.tld"

    # Database settings
    "writeToDatabase"       = $false                        # If the results should be written to a separate database like the reponse database
    "writeMethod"           = "SqlClient"                   # SqlClient|SqlServer -> SqlClient is generally available and inserts data with single records where SqlServer (SqlServer Management) can insert a whole table object at once,
                                                            # but only available if installed on that machine with 'Install-Module -Name SqlServer -AllowClobber'
                                                            # SqlServer is not implemented yet
    "databaseInstance"      = "localhost"                   # The database instance to write into    
    "databaseName"          = "RS_Handel"                   # The database to write into
    "databaseSchema"        = "dbo"                         # The schema of the insert table
    "databaseTable"         = "ELAINETransactional"         # The table to write into
    "trustedConnection"     = $false                        # Use trusted connection for SQL Server authentication, if not you will need to enter the details in the next step

}

# Enter the details if no trusted connection is used
If ( $uploadSettings.trustedConnection -eq $false -and $uploadSettings.writeToDatabase) {
    
    # Ask for credentials and encrypt the password
    $sqlCred = Get-Credential -Message "Enter your SQL Auth credentials"
    $sqlCred.Password.MakeReadOnly()
    $sqlCredEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$sqlCred.Password).GetNetworkCredential().Password) #-keyFile $keyFile
    
    # Save into uploads object
    $uploadSettings.add("databaseUser",$sqlCred.UserName)
    $uploadSettings.add("databasePass",$sqlCredEncrypted)
    
}


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{

    # General
    base="https://ed92.elaine-asp.de/http/api/"         # Default url
    defaultResponseFormat = "json"                      # json|text|serialize|xml
    changeTLS = $true                                   # should tls be changed on the system?
    nameConcatChar = " / "                              # character to concat mailing/campaign id with mailing/campaign name
    logfile="$( $scriptPath )\elaine.log"               # path and name of log file
    providername = "ELN"                                # identifier for this custom integration, this is used for the response allocation
    checkVersion = $true                                # check elaine version for some specific calls
    
    # Session 
    aesFile = $keyFile                                  # encryption key for saving credentials
    encryptToken = $true                                # $true|$false if the session token should be encrypted
    
    # Detail settings
    login = $loginSettings
    preview = $previewSettings
    mailings = $mailingsSettings
    upload = $uploadSettings

}

$logfile = $settings.logfile


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
"Choose the email field"
$emailField = $fields | Out-GridView -PassThru
$settings.upload.emailColumn = $emailField.f_name


#-----------------------------------------------
# CHOOSE URN FIELD
#-----------------------------------------------

<#
Choose the urn field for the primary key
#>
"Choose the URN field"
$urnField = $fields | Out-GridView -PassThru
$settings.upload.urnColumn = $urnField.f_name


#-----------------------------------------------
# CHOOSE VARIANT FIELD
#-----------------------------------------------


<#
Choose the variant field, e.g. for language dependent accounts/templates
If there is no variant field, just cancel
#>
"Choose the variant field if needed or just cancel it"
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
"Choose other required fields or just cancel it"
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



################################################
#
# CHECK SOME FOLDERS
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.upload.uploadsFolder
if ( !(Test-Path -Path $uploadsFolder) ) {
    Write-Log -message "Upload $( $uploadsFolder ) does not exist. Creating the folder now!"
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}
