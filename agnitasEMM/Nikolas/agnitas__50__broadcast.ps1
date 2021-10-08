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
	    scriptPath= "C:\Users\NLethaus\Documents\GitHub\Agnitas-EMM"
        Path = "C:\Users\NLethaus\Documents\GitHub\Agnitas-EMM\data\DatenPeopleStage.txt"
        MessageName = "777645 / Kopie von Skate" 

    }
}


################################################
#
# NOTES
#
################################################

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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
$script:moduleName = "AGNITAS-BROADCAST"

# Load general settings
. ".\bin\general_settings.ps1"

# Load settings
. ".\bin\load_settings.ps1"

# Load network settings
. ".\bin\load_networksettings.ps1"

# Load prepartation
. ".\bin\preparation.ps1"

# Load functions
. ".\bin\load_functions.ps1"

# Start logging
. ".\bin\startup_logging.ps1"

################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json;" # charset=utf-8"
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}



#-----------------------------------------------
# STEP 1: Copy Mailing - SOAP
#-----------------------------------------------
$namespace = "http://agnitas.com/ws/schemas"
$mailing = [Mailing]::new($params.MessageName)


$param = @{
    mailingId = [Hashtable]@{
        type = "int"
        value = [int]$mailing.mailingId
    }
    nameOfCopy = [Hashtable]@{
        type = "string"
        value = "$( $mailing.mailingName )-Copy-$( $timestamp )"
    }
    descriptionOfCopy = [Hashtable]@{
        type = "string"
        value = "Beschreibung der Kopie"
    }
}

# ! CopyMailing returns the mailingId of the copied mailing
$copyMailing = Invoke-Agnitas -method "CopyMailing" -param $param -verboseCall -namespace $namespace #-wsse $wsse -noresponse 


#---------------------------------------------------------------------
# STEP 2: Get copied Mailing - SOAP
#---------------------------------------------------------------------
$mailingId = [int]$copyMailing.copyId.value
$namespace = "http://agnitas.org/ws/schemas"

$param = @{
    mailingID = [Hashtable]@{
        type = "int"
        value = $mailingId
    }
}

$getMailing = Invoke-Agnitas -method "GetMailing" -param $param -verboseCall -namespace $namespace #-wsse $wsse -noresponse 

#--------------------------------------------------------------------------
# STEP 3: Update Mailing - Connect TargertList with copied mailing - SOAP
#--------------------------------------------------------------------------
$param = [ordered]@{
    mailingID = [Hashtable]@{
        type = "int"
        value = [int]$getMailing.mailingID
    }
    shortname = [Hashtable]@{
        type = "string"
        value = $getMailing.shortname
    }
    description = [Hashtable]@{
        type = "string"
        value = $getMailing.description
    }
    mailinglistID = [Hashtable]@{
        type = "int"
        value = [int]$getMailing.mailinglistID
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
        value = $getMailing.mailingType
    }
    subject = [Hashtable]@{
        type = "string"
        value = $getMailing.subject
    }
    senderName = [Hashtable]@{
        type = "string"
        value = $getMailing.senderName
    }
    senderAddress = [Hashtable]@{
        type = "string"
        value = $getMailing.senderAddress
    }
    replyToName = [Hashtable]@{
        type = "string"
        value = $getMailing.replyToName
    }
    replyToAddress = [Hashtable]@{
        type = "string"
        value = $getMailing.replyToAddress
    }
    charset = [Hashtable]@{
        type = "string"
        value = $getMailing.charset
    }
    linefeed = [Hashtable]@{
        type = "int"
        value = [int]$getMailing.linefeed
    }
    format = [Hashtable]@{
        type = "string"
        value = "offline-html"
    }
    onePixel = [Hashtable]@{
        type = "string"
        value = $getMailing.onePixel
    }

}

$updateMailing = Invoke-Agnitas -method "UpdateMailing" -param $param -verboseCall -namespace "http://agnitas.org/ws/schemas" #-wsse $wsse -noresponse 

#-----------------------------------------------
# STEP 4: Send Mailing - REST
#-----------------------------------------------
$mailingId = $getMailing.mailingID

#$send_date = (Get-Date).AddSeconds(10).ToString("yyyy-MM-ddTHH:mm:ssZ")  #example Format = 2017-07-21T17:32:28Z


$endpoint = "$( $apiRoot )/send/$( $mailingId )"

$body = @{
    send_type = "W"
    #send_date = $send_date
}
   
$bodyJson = $body | ConvertTo-Json

<#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Send-sendMailingIdPost
#>
$sendMailing = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $header -ContentType $contentType -Body $bodyjson -Verbose



################################################
#
# RETURN
#
################################################

return $sendMailing

