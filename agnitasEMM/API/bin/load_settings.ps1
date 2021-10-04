# Load settings
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$passwordEncrypted = Get-PlaintextToSecure ([System.Management.Automation.PSCredential]::new("dummy",$password).GetNetworkCredential().Password)


$auth = @{
    "Username" = "apteco_ws"          # A shared secret for authentication.
    #"Password" = $passwordEncrypted                   # A shared secret used for signing the JWT you generated.   
}

$settings = @{

    # General settings
    "nameConcatChar" =   " | "
    "logfile" = ".\emm.log"                                    # logfile
    "providername" = "agnitasEMM"                        # identifier for this custom integration, this is used for the response allocation

    # Security settings
    "aesFile" = "$( $scriptPath )\aes.key"
    #"sessionFile" = "$( $scriptPath )\session.json"         # name of the session file
    #"ttl" = 25                                              # Time to live in minutes for the current session, normally 30 minutes for TriggerDialog
    #"encryptToken" = $true                                  # $true|$false if the session token should be encrypted

    # Network settings
    "changeTLS" = $true
    "contentType" = "application/json;charset=utf-8"

    # Triggerdialog settings
    "base" = "https://ws.agnitas.de/2.0/"
    #"customerId" = ""
    #"createCampaignsWithDate" = $true

    # sub settings categories
    "authentication" = $auth
    #"dataTypes" = $dataTypeSettings
    #"preview" = $previewSettings
    #"upload" = $uploadSettings
    #"mail" = $mail
    #"report" = $reportSettings
    
}