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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\agnitasEMM"
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

https://ws.agnitas.de/2.0/emmservices.wsdl
https://emm.agnitas.de/manual/de/pdf/webservice_pdf_de.pdf

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
# SETTINGS AND STARTUP
#
################################################

# General settings
$modulename = "EMMUPDATETARGETGROUP"

# Load other generic settings like process id, startup timestamp, ...
. ".\bin\general_settings.ps1"

# Setup the network security like SSL and TLS
. ".\bin\load_networksettings.ps1"

# Load functions and assemblies
. ".\bin\load_functions.ps1"

# Load the settings from the local json file
. ".\bin\load_settings.ps1"

# Setup the log and do the initial logging e.g. for input parameters
. ".\bin\startup_logging.ps1"

# Do the preparation
. ".\bin\preparation.ps1"


################################################
#
# PROCESS
#
################################################

#-----------------------------------------------
# GET MAILING
#-----------------------------------------------


$param = @{
    mailingID = [Hashtable]@{
        type = "int"
        value = 777526
    }
}

$mailing = Invoke-Agnitas -method "GetMailing" -param $param -namespace "http://agnitas.org/ws/schemas"

<#
{
  "@ns2": "http://agnitas.org/ws/schemas",
  "mailingID": "777526",
  "shortname": "Mailing fuer Zebras-Copy-2021-10-07--12-34-08",
  "description": "Beschreibung der Kopie",
  "mailinglistID": "32698",
  "targetIDList": {
    "targetID": "54368"
  },
  "mailingType": "regular",
  "subject": "Dies ist kein Zoo",
  "senderName": "Nikolas",
  "senderAddress": "nikolas.lethaus@apteco.de",
  "replyToName": "Nikolas",
  "replyToAddress": "nikolas.lethaus@apteco.de",
  "charset": "UTF-8",
  "linefeed": "0",
  "formats": {
    "format": "text"
  },
  "onePixel": "top",
  "autoUpdate": "false"
}
#>

#-----------------------------------------------
# UPDATE MAILING
#-----------------------------------------------

<#
<?xml version="1.0" encoding="UTF-8"?>
<SOAP-ENV:Envelope xmlns:SOAP-ENV="http://schemas.xmlsoap.org/soap/envelope/" xmlns:ns1="http://agnitas.org/ws/schemas">
    <SOAP-ENV:Header>
        <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
            <wsse:UsernameToken xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">
                <wsse:Username>apteco_ws</wsse:Username>
                <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest">6DF+QgMaiQMcoSzOjYtVbHXtqzo=</wsse:Password>
                <wsse:Nonce EncodingType="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-soap-message-security-1.0#Base64Binary">MjM0NzU1MjM3NjVhNTg1MTQ2Nzk2YTU5NTAzMzcwNDQ=</wsse:Nonce>
                <wsu:Created xmlns:wsu="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd">2021-10-07T13:32:58Z</wsu:Created>
            </wsse:UsernameToken>
        </wsse:Security>
    </SOAP-ENV:Header>
    <SOAP-ENV:Body>
        <ns1:UpdateMailingRequest>
            <ns1:mailingID>777526</ns1:mailingID>
            <ns1:shortname>Mailing fuer Zebras-Copy-2021-10-07--12-34-08</ns1:shortname>
            <ns1:description>Beschreibung der Kopie</ns1:description>
            <ns1:mailinglistID>32698</ns1:mailinglistID>
            <ns1:targetIDList>
                <ns1:targetID>54368</ns1:targetID>
            </ns1:targetIDList>
            <ns1:matchTargetGroups>all</ns1:matchTargetGroups>
            <ns1:mailingType>regular</ns1:mailingType>
            <ns1:subject>Dies ist kein Zoo</ns1:subject>
            <ns1:senderName>Nikolas</ns1:senderName>
            <ns1:senderAddress>nikolas.lethaus@apteco.de</ns1:senderAddress>
            <ns1:replyToName>Nikolas</ns1:replyToName>
            <ns1:replyToAddress>nikolas.lethaus@apteco.de</ns1:replyToAddress>
            <ns1:charset>UTF-8</ns1:charset>
            <ns1:linefeed>0</ns1:linefeed>
            <ns1:format>offline-html</ns1:format>
            <ns1:onePixel>top</ns1:onePixel>
        </ns1:UpdateMailingRequest>
    </SOAP-ENV:Body>
</SOAP-ENV:Envelope>

#>

$param = [ordered]@{
    mailingID = [Hashtable]@{
        type = "int"
        value = 777526
    }
    shortname = [Hashtable]@{
        type = "string"
        value = "Mailing fuer Zebras-Copy-2021-10-07--12-34-08"
    }
    description = [Hashtable]@{
        type = "string"
        value = "Beschreibung der Kopie"
    }
    mailinglistID = [Hashtable]@{
        type = "int"
        value = 32698
    }
    targetIDList = [Hashtable]@{
        type = "element"
        value = @(54368)
        subtype = "targetID"
    }
    matchTargetGroups = [Hashtable]@{
        type = "string"
        value = "all"
    }
    mailingType = [Hashtable]@{
        type = "string"
        value = "regular"
    }
    subject = [Hashtable]@{
        type = "string"
        value = "Dies ist kein Zoo"
    }
    senderName = [Hashtable]@{
        type = "string"
        value = "Nikolas"
    }
    senderAddress = [Hashtable]@{
        type = "string"
        value = "nikolas.lethaus@apteco.de"
    }
    replyToName = [Hashtable]@{
        type = "string"
        value = "Nikolas"
    }
    replyToAddress = [Hashtable]@{
        type = "string"
        value = "nikolas.lethaus@apteco.de"
    }
    charset = [Hashtable]@{
        type = "string"
        value = "UTF-8"
    }
    linefeed = [Hashtable]@{
        type = "int"
        value = 0
    }
    format = [Hashtable]@{
        type = "string"
        value = "offline-html"
    }
    onePixel = [Hashtable]@{
        type = "string"
        value = "top"
    }

}

Invoke-Agnitas -method "UpdateMailing" -param $param -namespace "http://agnitas.org/ws/schemas"
