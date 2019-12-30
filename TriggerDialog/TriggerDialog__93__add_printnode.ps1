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

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
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
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

$logfile = $settings.logfile

# TODO [ ] maybe put this into the settings
$namespaces = [hashtable]@{
        "ns2"="urn:pep-dpdhl-com:triggerdialog/campaign/v_10"
}

################################################
#
# FUNCTIONS AND ASSEMBLIES
#
################################################

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}

Add-Type -AssemblyName System.Security


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCREATE CAMPAIGN" >> $logfile


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# CREATE PAYLOAD
#-----------------------------------------------

$payload = $settings.defaultPayload.PsObject.Copy()
$payload.iat = Get-Unixtime
$payload.exp = ( (Get-Unixtime) + 3600 )

#-----------------------------------------------
# CREATE JWT 
#-----------------------------------------------

$jwt = Create-JWT -headers $settings.headers -payload $payload -secret ( Get-SecureToPlaintext -String $settings.login.secret )


#-----------------------------------------------
# PREPARE THE CAMPAIGN CREATION
#-----------------------------------------------

$resource = "campaign/printNode"
$service = "addCampaignPrintNode"
$addPrintNodeUri = "$( $settings.base )/triggerdialog/$( $resource )/$( $service )?jwt=$( $jwt )"
$contentType = "application/xml" # text/xml, application/xml, application/json

$createCampaignRequest = @{
    #"masApiVersion" = "1.0.0" # not mandatory
    "masId" = $settings.defaultPayload.masId # long
    "masCampaignID" = 12345 # TODO [ ] How to access existing campaigns?
    "masClientID" = $settings.defaultPayload.masClientId # string 60
    "printNode" = @{
        "printNodeID" = "abc" # string 32
        "description" = "def" # string 30, not allowed < > ? " : | \ / *
    }
}

$addPrintnodeBody = Out-HashTableToXml -InputObject $createCampaignRequest -Root "ns2:addCampaignPrintNodeRequest" -namespaces $namespaces -Path ".\last_request.xml"


#-----------------------------------------------
# ADD THE PRINTNODE
#-----------------------------------------------

$newNode = Invoke-RestMethod -Method Post -Uri $addPrintNodeUri -ContentType $contentType -Body $addPrintnodeBody -Verbose
