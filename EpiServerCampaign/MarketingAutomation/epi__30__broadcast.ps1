<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

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
$params = [hashtable]@{
    "MessageName"="285809826812 / Copy - Shop Clients / Copy of shop clients"
    "Path"="C:\FastStats\Publish\Handel\system\Deliveries\PowerShell_Wallet Push ENG_ae44d595-8019-4602-9187-9bd6ef1ebf1e.txt"
    "SmsFieldName" = "WalletUrl"
}
#>

################################################
#
# NOTES
#
################################################


# TODO [x] bring in a possibility to duplicate a list -> in a separate powershell file


################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
<#
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}
#>
$scriptPath = "D:\Apteco\Scripts\episerver_marketing_automation"
Set-Location -Path $scriptPath

################################################
#
# SETTINGS
#
################################################


# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json

$excludedAttributes = @("Opt-in Source","Opt-in Date","Created","Modified")
$maxWriteCount = 2
$logfile = $settings.logfile


# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

################################################
#
# FUNCTIONS
#
################################################

# load all functions
. ".\epi__00__functions.ps1"


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
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

