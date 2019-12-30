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
# NOTES
#
################################################



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

# Please note this path is relative to the $scriptPath
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

$return = [Hashtable]@{
    "Type" = $settings.previewSettings.Type
    "FromAddress"=$settings.previewSettings.FromAddress
    "FromName"=$settings.previewSettings.FromName
    "Html"=$html
    "ReplyTo"=$settings.previewSettings.ReplyTo
    "Subject"=$settings.previewSettings.Subject
    "Text"="Lorem Ipsum"
}

return $return
