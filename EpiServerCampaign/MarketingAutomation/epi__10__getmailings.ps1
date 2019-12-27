<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

#>

################################################
#
# PARAMS
#
################################################

param(

)

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
<#
# Load scriptpath
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

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = [System.Net.SecurityProtocolType]'Tls12'
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

$guid = ([guid]::NewGuid()).Guid

################################################
#
# FUNCTIONS
#
################################################

# load all functions
. ".\epi__00__functions.ps1"


################################################
#
# PROGRAM
#
################################################



#-----------------------------------------------
# SESSION
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

$recipientLists | Select @{name="id";expression={ $_.ID }}, @{name="name";expression={ "$( $_.ID )$( $settings.nameConcatChar )$( $_.Name )$( $settings.nameConcatChar )$( $_.Description )" }}





