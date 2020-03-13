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
        scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns"
        TestRecipient= '{"Email":"florian.von.bracht@apteco.de","Sms":null,"Personalisation":{"voucher_1":"voucher no 1","voucher_2":"voucher no 2","voucher_3":"voucher no 3","Kunden ID":"Kunden ID","title":"title","name":"name","surname":"surname","language":"language","Communication Key":"e48c3fd3-7317-4637-aeac-4fa1505273ac"}}'
        MessageName= "275324762694 / Test: Smart Campaign Mailing"
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

<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

TODO [ ] implement more logging

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
$settingsFilename = "settings.json"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
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

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
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
# SMART CAMPAIGN ID
#-----------------------------------------------

# cut out the smart campaign id or mailing id
$messageName = $params.MessageName
$smartCampaignID = $messageName -split $settings.nameConcatChar | select -First 1


#-----------------------------------------------
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# HTML CONTENT
#-----------------------------------------------

$splits = Invoke-Epi -webservice "SplitMailing" -method "getSplitChildIds" -param @(@{value=$smartCampaignID;datatype="long"}) -useSessionId $true



$htmlArr = @()
$splits | ForEach-Object {
    
    $split = $_
    $html = Invoke-Epi -webservice "Mailing" -method "getContent" -param @(@{value=$split;datatype="long"},"text/html") -useSessionId $true
    $htmlArr += $html

}

# TODO [ ] remove the Epi Markup to show clean html


################################################
#
# RETURN
#
################################################

# TODO [ ] implement subject and more of these things rather than using default values

$return = [Hashtable]@{
    "Type" = $settings.previewSettings.Type
    "FromAddress"=$settings.previewSettings.FromAddress
    "FromName"=$settings.previewSettings.FromName
    "Html"= $htmlArr -join "<p>&nbsp;</p>"
    "ReplyTo"=$settings.previewSettings.ReplyTo
    "Subject"=$settings.previewSettings.Subject
    "Text"="Lorem Ipsum"
}

return $return






