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
	    scriptPath= "C:\FastStats\scripts\episervercampaign"
	    abc= "def"
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
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        ,[System.Net.SecurityProtocolType]::Ssl3
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# more settings
$logfile = $settings.logfile
$guid = ([guid]::NewGuid()).Guid


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
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGETMAILINGS" >> $logfile
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


#-----------------------------------------------
# GET CURRENT SESSION OR CREATE A NEW ONE
#-----------------------------------------------

Get-EpiSession


#-----------------------------------------------
# RECIPIENT LISTS
#-----------------------------------------------

# TODO [ ] maybe replace this by a fixed list of recipient list IDs

$recipientListIDs = ( Get-Content -Path "$( $scriptPath )\$( $settings.recipientListFile )" -Encoding UTF8 -Raw | ConvertFrom-Json ).id

$recipientLists = @()
$recipientListIDs | Select -Unique | ForEach {

    $recipientListID = $_

    # create new object
    $recipientList = New-Object PSCustomObject
    $recipientList | Add-Member -MemberType NoteProperty -Name "ID" -Value $recipientListID

    # ask for name
    $recipientListName = Invoke-Epi -webservice "RecipientList" -method "getName" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true
    $recipientList | Add-Member -MemberType NoteProperty -Name "Name" -Value $recipientListName

    # ask for description
    $recipientListDescription = Invoke-Epi -webservice "RecipientList" -method "getDescription" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true
    $recipientList | Add-Member -MemberType NoteProperty -Name "Description" -Value $recipientListDescription

    $recipientLists += $recipientList

}


#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS DETAILS
#-----------------------------------------------

$messages = $recipientLists | Select @{name="id";expression={ $_.ID }}, @{name="name";expression={ "$( $_.ID )$( $settings.nameConcatChar )$( $_.Name )$( $settings.nameConcatChar )$( $_.Description )" }}


################################################
#
# RETURN
#
################################################

# real messages
return $messages


