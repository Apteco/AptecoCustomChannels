
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
$libSubfolder = "lib"
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



################################################
#
# SETUP SETTINGS
#
################################################


#-----------------------------------------------
# LOGIN DATA
#-----------------------------------------------

$keyFile = "$( $scriptPath )\aes.key"
$pass = Read-Host -AsSecureString "Please enter the password for SFTP"
$passEncrypted = Get-PlaintextToSecure ((New-Object PSCredential "dummy",$pass).GetNetworkCredential().Password) -keyFile $keyFile


#-----------------------------------------------
# ALL SETTINGS
#-----------------------------------------------

$settings = @{
    
    # General
    changeTLS = $true                                   # should tls be changed on the system?
    logfile = "winscp.log"                              # logfile
    providername = "winscp"                             # identifier for this custom integration, this is used for the response allocation

    # Security
    aesFile = $keyFile

    # Upload settings
    rootUploadFolder = "/Support/Florian/"
    
    # SFTP Settings
    transfer = @{
        ignoreTimestamp = $true
        ignorePermissions = $true
    }

    sftpSession = @{
        HostName = "ftp.apteco.com"
        UserName = "apteco-support"
        Password = $passEncrypted
        #SshHostKeyFingerprint = "ssh-rsa 1024 yBbfoAT0V4ETSOjRVMOsFBGcH1IjZ7RngJDi0NfBHmo="
    }

  
}

#-----------------------------------------------
# ADD SERVER FINGERPRINT
#-----------------------------------------------

# Add the right protocol
$settings.sftpSession.Add("Protocol",[WinSCP.Protocol]::Sftp)
    
# Setup session options
$sessionOptions = New-Object WinSCP.SessionOptions -Property $settings.sftpSession 
$session = New-Object WinSCP.Session
    
$fingerprint = $session.ScanFingerprint($sessionOptions,"SHA-256") # Helper, to find out server fingerprint
$settings.sftpSession.Add("SshHostKeyFingerprint",$fingerprint)

$settings.sftpSession.Remove("Protocol")

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

