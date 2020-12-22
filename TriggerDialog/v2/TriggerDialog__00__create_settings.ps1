
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
$timestamp = [datetime]::Now


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem ".\$( $functionsSubfolder )" -Filter "*.ps1" -Recurse | ForEach {
    . $_.FullName
}


################################################
#
# SETTINGS
#
################################################

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$authSecret = Read-Host -AsSecureString "Please enter the authentication secret for TriggerDialog"
$authSecretEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$authSecret).GetNetworkCredential().Password)

$ssoTokenKey = Read-Host -AsSecureString "Please enter the SSO token key for TriggerDialog"
$ssoTokenKeyEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$ssoTokenKey).GetNetworkCredential().Password)


$auth = @{

    "partnerSystemIdExt" = "<partnersystemidext>"                    # The numeric id of your partnersystem in our system.
    "partnerSystemCustomerIdExt" = "<partnersystemcustomeridext>"    # The alphanumeric id identifying your customer, you want to act for.
    "authenticationSecret" = $authSecretEncrypted                    # A shared secret for authentication.
    "ssoTokenKey" = $ssoTokenKeyEncrypted                            # A shared secret used for signing the JWT you generated.    

}


#-----------------------------------------------
# PREVIEW SETTINGS
#-----------------------------------------------

$previewSettings = @{
    "Type" = "Email" #Email|Sms
    "FromAddress"="info@apteco.de"
    "FromName"="Apteco"
    "ReplyTo"="info@apteco.de"
    "Subject"="Test-Subject"
    
}


#-----------------------------------------------
# UPLOAD SETTINGS
#-----------------------------------------------

$uploadSettings = @{
    #"rowsPerUpload" = 800
    "uploadsFolder" = "$( $scriptPath )\uploads\"
    "delimiter" = "`t" # "`t"|","|";" usw.
    "encoding" = "UTF8" # "UTF8"|"ASCII" usw. encoding for importing text file https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/import-csv?view=powershell-6
    #"excludedAttributes" = @()
}


#-----------------------------------------------
# BROADCAST SETTINGS
#-----------------------------------------------

$broadcastSettings = @{
    
}


#-----------------------------------------------
# MAIL NOTIFICATION SETTINGS
#-----------------------------------------------
$smtpPass = Read-Host -AsSecureString "Please enter the SMTP password"
$smtpPassEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$smtpPass).GetNetworkCredential().Password)

$mail = @{
    smtpServer = "smtp.example.com"
    port = 587
    from = "admin@example.com"
    username = "admin@example.com"
    password = $smtpPassEncrypted
}



#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

# TODO [ ] use url from PeopleStage Channel Editor Settings instead?

$settings = @{

    # General settings
    "logfile" = "$( $scriptPath )\triggerdialog.log"              # logfile
    "nameConcatChar" =   " / "
    "providername" = "triggerdialog"                              # identifier for this custom integration, this is used for the response allocation

    # Security settings
    "aesFile" = "$( $scriptPath )\aes.key"
    "sessionFile" = "$( $scriptPath )\session.json"       # name of the session file
    "ttl" = 25                                            # Time to live in minutes for the current session, normally 30 minutes for TriggerDialog
    "encryptToken" = $true                                # $true|$false if the session token should be encrypted

    # Network settings
    "changeTLS" = $true
    "contentType" = "application/json;charset=utf-8"

    # Triggerdialog settings
    # UAT https://dm-uat.deutschepost.de/gateway
    # Production https://dm.deutschepost.de/gateway
    "base" = "https://dm-uat.deutschepost.de/gateway"
    "customerId" = ""
    "createCampaignsWithDate" = $true

    # payloads    
    "defaultPayload" = @{
        "firstname" = "<firstname>"                              # The systemuser’s firstname (max. 50 characters).
        "lastname" = "<lastname>"                                # The systemuser’s lastname (max. 50 characters).
        "email" = "<email>"                   # The systemuser’s email address (max. 150 characters).
        "username" = "<username>"                         # The systemuser’s username (max. 80 characters). Must be unique for the same partnersystem customer.
        "masClientId" = "<partnersystemcustomeridext>"                    # same as partnerSystemCustomerIdExt
        "masId" = "<partnersystemidext>"                            # same as partnerSystemIdExt
        "iss" = "<issuer>" 
        "exp" = 0                                  # Should expire in around 2 minutes
        "iat" = 0
    }

    # jwt header
    "headers" = @{
        alg = "HS512"
        typ = "JWT"
    }

    # sub settings categories
    "authentication" = $auth
    "preview" = $previewSettings
    "upload" = $uploadSettings
    "broadcast" = $broadcastSettings
    "mail" = $mail
    
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
# DO SOME MORE SETTINGS DIRECTLY
#
################################################


#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$contentType = $settings.contentType
$headers = @{
    "accept" = $settings.contentType
}

#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

Get-TriggerDialogSession
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret $settings.authentication.authenticationSecret
$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )

$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

if ( $jwtDecoded.payload.customerIds.Count -gt 1 ) {
    $customerId = $jwtDecoded.payload.customerIds | Out-GridView -PassThru
} elseif ( $jwtDecoded.payload.customerIds.Count -eq 1 ) {
    $customerId = $jwtDecoded.payload.customerIds[0]
} else {
    exit 0
}

$settings.customerId = $customerId


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
