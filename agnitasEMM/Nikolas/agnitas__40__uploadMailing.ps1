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
	    scriptPath= "C:\Users\NLethaus\Documents\GitHub\Agnitas-EMM"
        Path = "C:\Users\NLethaus\Documents\GitHub\Agnitas-EMM\data\DatenPeopleStage.txt"
        MessageName = "777645 / Kopie von Skate" 

    }
}


################################################
#
# NOTES
#
################################################

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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
$script:moduleName = "AGNITAS-UPLOAD-MAILING"

# Load general settings
. ".\bin\general_settings.ps1"

# Load settings
. ".\bin\load_settings.ps1"

# Load network settings
. ".\bin\load_networksettings.ps1"

# Load prepartation
. ".\bin\preparation.ps1"

# Load functions
. ".\bin\load_functions.ps1"

# Load assemblies (dll files in subfolder)
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach-Object {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}

# Start logging
. ".\bin\startup_logging.ps1"


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json;" # charset=utf-8"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}

#-------------------------------------------------------------------
# STEP 1: Add Process Id Column to $params.Path
#-------------------------------------------------------------------

$dataCsv = @()
$dataCsv = Import-Csv -Path $params.Path -Delimiter "`t" -Encoding UTF8
# Add send_id column to recipient csv file
$dataCsv | Add-Member -MemberType NoteProperty -Name "send_id" -Value $send_id

# Add timestamp to uploaded csv-file
$dirName  = [io.path]::GetDirectoryName($params.Path)
$filename = [io.path]::GetFileNameWithoutExtension($params.Path)
$ext      = [io.path]::GetExtension($params.Path)
$timestamp= get-date -f yyyy-MM-dd--HH-mm-ss

$newPath  = "$dirName\$filename$timestamp$ext"

$dataCsv | Export-Csv -Path $newPath -Delimiter "`t" -NoTypeInformation


#-------------------------------------------------------------------
# STEP 2: WinSCP - Upload PeopleStage Recipients into SFTP Server
#-------------------------------------------------------------------
# Load the Assembly and setup the session properties
try{
    # Load WinSCP .NET assembly
    # Setup session options
    $sessionOptions = New-Object WinSCP.SessionOptions -Property @{
        Protocol = [winSCP.Protocol]::Sftp
        HostName = $settings.sftpSession.HostName
        Username = $settings.sftpSession.Username
        Password = Get-SecureToPlaintext -String $settings.sftpSession.Password
        SshHostKeyFingerprint = $settings.sftpSession.SshHostKeyFingerprint
    }

    # This Object will connect to the SFTP Server
    $session = New-Object WinSCP.Session

    
    # Connect and send files, then close session
    try{
        # Connect
        $session.DebugLogPath = "$( $params.ScriptPath )/sftp.log"
        $session.Open($sessionOptions)

        Write-Log -message "Session openend successfully"

        # TransferOptions set to Binary
        $transferOptions = New-Object WinSCP.TransferOptions
        $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

        # Put the file using PutFiles Method accross to SFTP Server with the $transferOptions: binary
        $transferResult = $session.PutFiles($newPath, "/import/", $false, $transferOptions)
        
        # Put the same file also in the archive
        $transferResult = $session.PutFiles($newPath, "/archive/", $false, $transferOptions)
        $transferResult.Check()

        # Write to the console and the log whether the file transfer was successful    
        Write-Log -message "Upload of $( $transferResult.Transfers.FileName ) to $( $transferResult.Transfers.Destination ) succeeded"
                
    }finally{
        # Disconnect, clean up
        $session.Dispose()
    }
    
# Catch em errors
}catch{
    Write-Host "Error: $( $_ )" #.Exception.Message )"
    exit 1
}


#--------------------------------------------------------
# [ ] TODO Zum Felder abgleich die globale Liste an Empfängern verwenden
#-------------------------------------------------------- 
<#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailinglist-mailinglistMailinglistIdRecipientsGet
#>


#---------------------------------------------------------
# STEP 3: Trigger Autoimport - REST
#---------------------------------------------------------
$autoimport_id = 847 # API-Auto-Import Id in Agnitas EMM
$c = 0 # time counter

$endpoint = "$( $apiRoot )/autoimport/$( $autoimport_id )"
$invokePost = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $header -ContentType $contentType -Verbose


# Checking whether the Autoimport has finished uploading the recipients into Agnitas
do{
    $invokeGet = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -ContentType $contentType -Verbose
    Write-Log -message $invokeGet.status
    
    if($invokeGet.status -ne "running"){
        break
    }
    
    Start-Sleep -Seconds 2
    $c += 2
    Write-Log -message "Loading Upload - waited for $( $c ) seconds"
    
}while($invokeGet.status -eq "running" -and $c -lt 100)

Write-Log -message "Upload successfully finished"


#-----------------------------------------------
# STEP 4: BUILD TARGETGROUPS OBJECTS - SOAP
#-----------------------------------------------
# This is targetGroup where the recipients will be in
# [ ] TODO - Rotate around 10 targetGroups
$str = "54368 / Zielgruppe_mit_sendID"
$targetGroup = [TargetGroup]::new($str)

# Each recipient will get a same unique Send_Id to determine which recipients came from this import
$eql = @"
`send_id` = '$( $send_id )'
"@

# Load data from Agnitas EMM
$param = @{
    targetID = [Hashtable]@{
        type = "int"
        value = $targetGroup.targetGroupId
    }

    description = [Hashtable]@{
        type = "string"
        value = "Hello World"
    }

    eql = [Hashtable]@{
        type = "string"
        value = $eql
    }
}

$targetgroupsEmm = Invoke-Agnitas -method "UpdateTargetGroup" -param $param -verboseCall -noresponse -namespace "http://agnitas.com/ws/schemas" #-wsse $wsse #-verboseCall

################################################
#
# RETURN
#
################################################

# [ ] TODO return also the params which the broadcast script will need
return $targetgroupsEmm
