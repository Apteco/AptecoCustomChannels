<#

Send (params)
  IntegrationParameters…
  Username
  Password
  ListName
  MessageName
  TestRecipient

Receive (Hashtable)
  Type (Email / Sms)
  FromAddress
  FromName
  Html
  ReplyTo
  Subject
  Text

#>


################################################
#
# INPUT
#
################################################

Param(
    [hashtable] $params
)

<#
#DEBUG
$params = [hashtable]@{
    TestRecipient= '{"Email":"test@apteco.de","Sms":null,"Personalisation":{"voucher_1":"voucher no 1","voucher_2":"voucher no 2","voucher_3":"voucher no 3","Kunden ID":"Kunden ID","Vorname":"Vorname","Nachname":"Nachname","Communication Key":"b1a674cf-89b8-4d29-ab3d-4abe7d5eaa57"}}'
    MessageName= "Message 3"
    abc= "def"
    ListName= ""
    Password= "b"
    Username= "a"
}
#>

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
$scriptPath = "C:\FastStats\scripts\esp\custom"
Set-Location -Path $scriptPath


################################################
#
# LOG INPUT PARAMETERS
#
################################################

$logfile = "$( $scriptPath )\preview-message.log"

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


$html = @"
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN">
<html>
  <head>
  <meta http-equiv="content-type" content="text/html; charset=utf-8">
  <meta name="generator" content="PSPad editor, www.pspad.com">
  <title></title>
  </head>
  <body>
  Hello world!
  </body>
</html>
"@

################################################
#
# RETURN
#
################################################

[Hashtable]$return = @{
    "Type" = "Email" #Email|Sms
    "FromAddress"="info@apteco.com"
    "FromName"="Apteco"
    "Html"=$html
    "ReplyTo"=""
    "Subject"="Test-Subject"
    "Text"="Lorem Ipsum"
}

return $return
