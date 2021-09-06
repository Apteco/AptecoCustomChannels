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
	    Password= "def"
	    scriptPath= "D:\Scripts\TriggerDialog\v2"
	    abc= "def"
	    Username= "abc"
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
$processId = [guid]::NewGuid()
$modulename = "TRREPORT"
$timestamp = [datetime]::Now

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

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & LIBRARIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

<#
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
#>

Add-Type -AssemblyName System.Security


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
        Write-Log -message "    $( $param ) = '$( $params[$param] )'"
    }
}


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$headers = @{
    "accept" = $settings.contentType
}


#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

$newSessionCreated = Get-TriggerDialogSession
$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# LOAD REPORTS SUMMARY
#-----------------------------------------------

#$reportOverview = Invoke-TriggerDialog -customerId $customerId -path "recipientreport/overview" -headers $headers -deactivatePaging
#exit 0

#-----------------------------------------------
# LOAD CAMPAIGNS
#-----------------------------------------------

$campaigns = Invoke-TriggerDialog -customerId $customerId -path "longtermcampaigns" -headers $headers #-deactivatePaging


#-----------------------------------------------
# LOAD CAMPAIGNS REPORT
#-----------------------------------------------

$headers.accept = "text/csv"
$reportDetail = [System.Collections.ArrayList]@()
$campaigns | ForEach {

    $campaign = $_

    $reportDate = [Datetime]::Today.AddDays(-30)
    $endDate = [Datetime]::Today.AddDays(-1)

    $reports = [System.Collections.ArrayList]@()
    Do {
        $reportDate = $reportDate.AddDays(1)            
        $headers.accept = "text/csv"
        $report = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipientreport/detail?campaignId=$( $campaign.id )&customerId=$( $customerId )&reportDate=$( $reportDate.ToString("yyyy-MM-dd") )" -Verbose -Headers $headers -ContentType $contentType
        if ( ($report | measure -line ).lines -gt 1 ) {
            $reports.AddRange(( $report | ConvertFrom-Csv -Delimiter $settings.report.delimiter ))
        }
    } until ( $reportDate -eq $endDate )

    <#
    $reportCsv = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipientreport/detail?campaignId=$( $campaign.id )&customerId=$( $customerId )&reportDate=2021-03-03" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson
    $csvData = $reportCsv | ConvertFrom-Csv -Delimiter $settings.report.delimiter
    if ( $csvData.count -gt 0 ) {
        [void]$reportDetail.AddRange(( $csvData ))
    }
    #>
    $reportDetail.AddRange($reports)

}


#-----------------------------------------------
# CREATE A SCHEDULED TASK FOR THIS SCRIPT
#-----------------------------------------------

# TODO [ ] separate this task creation from the script?
# TODO [ ] Ask to add task for daily download of reports
# Check if task already exists

# Do you want to create a daily running task for this?
$confirmation = Read-Host "Do you want to create a daily running task for this [y/n]?"
if ($confirmation -eq "y") {

    #-----------------------------------------------
    # SETTINGS
    #-----------------------------------------------

    # Get the local app data folder of the user executing the scheduled task
    $scriptBlock = [Scriptblock]{
        [System.Environment]::GetEnvironmentVariables()['LOCALAPPDATA']
    }


    #-----------------------------------------------
    # ASK FOR CREDENTIALS + TEST
    #-----------------------------------------------

    # Ask for credentials for the task
    $usr = "$( [System.Environment]::MachineName )\$( [Environment]::UserName )"
    $username = Read-Host "Please enter username, if you want to another one than [$( $usr )]?"
    if ( [string]::IsNullOrEmpty($username) ) {
        $username = $usr
    }

    # Get the users credentials and ask for password
    $cred = Get-Credential -Message "Please enter the password for '$( $username )'" -UserName $username 

    # Try to start another powershell session with the credentials
    $loginSuccessful = $false
    $j = Start-Job -ScriptBlock $scriptBlock -Credential $cred
    while($j.State -eq "Running") {
        write-host "*" -NoNewLine
        Start-Sleep -Milliseconds 500
    }
    If ( $j.state -eq "Completed" ) {
        $loginSuccessful = $true
        Write-Log "The login with the provided credentials was successful"
        $result = Receive-Job -Job $j
    } else {
        Write-Log "The login with the provided credentials failed - Please try with other ones"
        Receive-Job -Job $j # let the exception be listed here
    }


    #-----------------------------------------------
    # COPY SCRIPT TO %LOCALAPPDATA%
    #-----------------------------------------------

    # TODO [ ] Copy the script to [System.Environment]::GetEnvironmentVariable("LocalAppData") and replace it, when neccessary. Create subfolders for this job
    # "%USERPROFILE%\AppData\Local\Temp"
    # Use $result for this

    #-----------------------------------------------
    # CREATE A TASK
    #-----------------------------------------------

    if ( $loginSuccessful ) {

        # Settings for the task
        $actionName = "Apteco Download Deutsche Post Print Mailing Automation Reports"
        $taskPath = "\Apteco\"
        $timeToStart = "06:00:00" # The time is automatically transformed into UTC, with  "06:00:00Z" it can be defined directly in UTC
        $existingTasks = Get-ScheduledTask -TaskPath $taskPath

        $createTask = $false
        if ( $existingTasks.TaskName -contains $actionName ) {
            $replaceTask = Read-Host "Do you want to replace the existing task [y/n]?"
            if ( $replaceTask -eq "y" ) {
                $createTask = $true
                Unregister-ScheduledTask -TaskName $actionName
            }
        } else {
            $createTask = $true
        }
        
        if ( $createTask ) {

            $stAction = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NonInteractive -NoLogo -NoProfile -File "C:\MyScript.ps1"'
            $stTrigger = New-ScheduledTaskTrigger -Daily -At $timeToStart
            $stSettings = New-ScheduledTaskSettingsSet
            $st = New-ScheduledTask -Action $stAction -Trigger $stTrigger -Settings $stSettings
            Register-ScheduledTask -TaskName $actionName -InputObject $st -TaskPath $taskPath -User $cred.UserName -Password $cred.GetNetworkCredential().Password
            
        }
    }

}