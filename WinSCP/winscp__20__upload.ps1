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
	    Path = "D:\Scripts\SQLServer\winscp\test.txt"
        scriptPath = "D:\Scripts\SQLServer\winscp"
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
$moduleName = "WINSCPUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


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
# PROGRAM
#
################################################


#-----------------------------------------------
# DECRYPT PASSWORD
#-----------------------------------------------

$settings.sftpSession.Password = Get-SecureToPlaintext -String $settings.sftpSession.Password


#-----------------------------------------------
# UPLOAD FILE
#-----------------------------------------------

try {
    
    # Add the right protocol
    #$settings.sftpSession | Add-Member -MemberType NoteProperty -Name "Protocol" -Value [WinSCP.Protocol]::Sftp
    $sftpSession = ConvertTo-HashtableFromPsCustomObject -psCustomObject $settings.sftpSession

    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property $sftpSession    

    Write-Log -message "Creating a new session with $( $sftpSession.HostName ) and Fingerprint $( $sftpSession.SshHostKeyFingerprint )"
    $session = New-Object WinSCP.Session
    
    try {
        # Connect
        $session.Open($sessionOptions)
        
        Write-Log -message "Session openend successfully"

        # Options for upload
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.FilePermissions = $null
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary
        if ( $settings.transfer.ignoreTimestamp ) {
            $transferOptions.PreserveTimestamp = $false
        }
        if ( $settings.transfer.ignorePermissions ) {
            $transferOptions.FilePermissions = $null
        }

        Write-Log -message "Beginning transfer now"

        # Upload files
        $transferResult = $session.PutFiles($params.Path, "$( $settings.rootUploadFolder )", $False, $transferOptions)
        
        # Throw on any error
        $transferResult.Check()
 
        # Print results
        foreach ($transfer in $transferResult.Transfers) {
            Write-Host "Upload of $($transfer.FileName) succeeded"
            Write-Log -message "Upload of $($transfer.FileName) succeeded"
        }
    }
    finally {
        Write-Log -message "Disconnecting now"
        
        # Disconnect, clean up
        $session.Dispose()
    }
 
} catch {
    Write-Host "Error: $($_.Exception.Message)"
    Write-Log -message "Error: $($_.Exception.Message)"
    throw [System.IO.InvalidDataException] "Error: $($_.Exception.Message)"
    #exit 1
}





################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = 0

# There is no id reference here, so taking the processId
$transactionId = $processId

# return object
[Hashtable]$return = @{
    
    # Mandatory return values
    "Recipients" = $recipients
    "TransactionId" = $transactionId
    
    # General return value to identify this custom channel in the broadcasts detail tables
    "CustomProvider" = $settings.providername
    "ProcessId" = $processId

}

# return the results
$return