################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)


################################################
#
# NOTES
#
################################################



################################################
#
# SCRIPT ROOT
#
################################################

<#
# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
#>
$scriptPath = "$( $params.scriptPath )" #"C:\FastStats\scripts\flexmail"
Set-Location -Path $scriptPath


################################################
#
# SETTINGS
#
################################################

# General settings
$functionsSubfolder = "functions"
$settingsFilename = "settings.json"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

$logfile = $settings.logfile


################################################
#
# FUNCTIONS
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tPREVIEW" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}



################################################
#
# PROGRAM
#
################################################

$messages = Invoke-Flexmail -method "GetMessages" -param @{"metaDataOnly"="true"}
$message = $params.MessageName -split $settings.messageNameConcatChar
$messageUrl = ( $messages | where { $_.messageId -eq $message[0] } ).messageWebLink

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tLoading preview for $( $message[0] ) with link $( $messageUrl )" >> $logfile
$html = Invoke-RestMethod -Method Get -Uri $messageUrl -Verbose


################################################
#
# RETURN
#
################################################

[Hashtable]$return = @{
    "Type" = $settings.previewSettings.Type
    "FromAddress"=$settings.previewSettings.FromAddress
    "FromName"=$settings.previewSettings.FromName
    "Html"=$html
    "ReplyTo"=$settings.previewSettings.ReplyTo
    "Subject"=$settings.previewSettings.Subject
    "Text"="Lorem Ipsum"
}

return $return
