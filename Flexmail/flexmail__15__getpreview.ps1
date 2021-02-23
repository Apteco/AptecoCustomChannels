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
        scriptPath= "C:\FastStats\scripts\flexmail"
        TestRecipient= '{"Email":"florian.von.bracht@apteco.de","Sms":null,"Personalisation":{"voucher_1":"voucher no 1","voucher_2":"voucher no 2","voucher_3":"voucher no 3","Kunden ID":"Kunden ID","title":"title","name":"name","surname":"surname","language":"language","Communication Key":"e48c3fd3-7317-4637-aeac-4fa1505273ac"}}'
        MessageName= "1631416 | Testmail_2"
        abc= "def"
        ListName= ""
        Password= "def"
        Username= "abc"  
    }
}


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
$moduleName         = "FLEXMAILPREVIEW"
$processId = [guid]::NewGuid()

if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}

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
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data

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

################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# LOAD WORKFLOWS
#-----------------------------------------------

$Workflows = Invoke-Flexmail -method "GetCampaigns" | where campaignType -eq Workflow
Write-Log -message "Loaded $( $Workflows.count ) workflows from flexmail"  



#-----------------------------------------------
# IDENTIFY TEMPLATE
#-----------------------------------------------

$messages = Invoke-Flexmail -method "GetMessages" -responseNode "MessageTypeItems" -param @{"metaDataOnly"="true"}
Write-Log -message "Loaded $( $messages.count ) messages / templates from flexmail"


# Extract the workflow
$workflow = [FlxWorkflow]::new($params.MessageName)
#$message = $params.MessageName -split $settings.messageNameConcatChar
$messageid = ( $Workflows | where { $_.campaignId -eq $workflow.workflowId } ).campaignMessageId
$messageDetails = ( $messages | where { $_.messageId -eq $messageid } )

#-----------------------------------------------
# HTML CONTENT
#-----------------------------------------------

Write-Log -message "Loading preview for $( $messageid ) with link $(($messageDetails.messageWebLink).Replace("http:","https:"))"
Write-Log -message "PreLoaded html sourcecode with $( ($messageDetails.messageWebLink).Length ) characters"

$html = Invoke-RestMethod -Method Get -Uri($messageDetails.messageWebLink).Replace("http:","https:") -Verbose -UseBasicParsing
Write-Log -message "Loaded html sourcecode with $( $html.Length ) characters"


################################################
#
# RETURN
#
################################################

$return = [Hashtable]@{
    "Type" = $settings.previewSettings.Type
    "FromAddress"=$settings.previewSettings.FromAddress
    "FromName"=$settings.previewSettings.FromName
    "Html"=$html
    "ReplyTo"=$settings.previewSettings.ReplyTo
    "Subject"=$settings.previewSettings.Subject
    "Text"="Testing"
}

$return