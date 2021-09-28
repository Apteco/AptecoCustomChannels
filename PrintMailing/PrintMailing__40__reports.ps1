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
$modulename = "TRREPORT"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"



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
<#
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
    $reportDetail.AddRange($reports)

    <#
    $reportCsv = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/recipientreport/detail?campaignId=$( $campaign.id )&customerId=$( $customerId )&reportDate=2021-03-03" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson
    $csvData = $reportCsv | ConvertFrom-Csv -Delimiter $settings.report.delimiter
    if ( $csvData.count -gt 0 ) {
        [void]$reportDetail.AddRange(( $csvData ))
    }
    #>

#}
#>


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

    # Load main file source code
    $c = Get-Content -Path "D:\Scripts\TriggerDialog\PrintMailing__40__reports.ps1" -encoding UTF8

    # Load all functions as sourcecode
    $sources = [hashtable]@{}
    Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
        $sourceCode = Get-Content -Path $_.FullName -Encoding UTF8
        $sources.Add( $_.Name, $sourceCode )
    }

    # Fill the input object for the script creation
    $inputObject = [hashtable]@{
        sourceCode = $c
        processId = $processId
        functions = $sources
    }

    # Get the local app data folder of the user executing the scheduled task
    $scriptBlock = [Scriptblock]{
        
        # Loading data of current user
        $targetFolder = [System.Environment]::GetEnvironmentVariables()['LOCALAPPDATA']
        
        $inputObj = $input.Clone()

        # Writing the main source code file
        $newFolder = New-Item -Path "$( $targetFolder )\Apteco\ScheduledTasks\PrintMailing_$( $inputObj.processId )" -ItemType Directory
        $targetFile = "$( $newFolder.FullName )\PrintMailing__ReportDownload.ps1"
        $inputObj.sourceCode | Set-Content -Path $targetFile -Encoding UTF8

        # Writing the functions source code
        $newFunctionsFolder = New-Item -Path "$( $newFolder.FullName )\Functions" -ItemType Directory
        $inputObj.functions.Keys | ForEach { # | Get-Member -MemberType NoteProperty | where { $_.Name -like "function#*" }
            $key = $_
            $inputObj.functions.$key | Set-Content -Path "$( $newFunctionsFolder.FullName )\$( $key )" -Encoding UTF8
        }

        # Return
        $targetFile # give this value back to the calling parent process

    }


    #-----------------------------------------------
    # ASK FOR CREDENTIALS + TEST + WRITE FILE TO LOCALAPPDATA
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
    $j = Start-Job -ScriptBlock $scriptBlock -Credential $cred -InputObject $inputObject
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