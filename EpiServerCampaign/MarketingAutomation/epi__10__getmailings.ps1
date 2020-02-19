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
	    Password= "def"
        scriptPath = "C:\FastStats\scripts\episerver\marketingautomation"
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

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

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
$moduleName = "GETMAILINGS"
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
$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

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
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
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

<#
#-----------------------------------------------
# RECIPIENT LISTS
#-----------------------------------------------

$recipientListIDs = ( Get-Content -Path "$( $settings.mailings.recipientListFile )" -Encoding UTF8 -Raw | ConvertFrom-Json ).id

$recipientLists = @()
$recipientListIDs | Select-Object -Unique | ForEach-Object {

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

$messages = $recipientLists | Select-Object @{name="id";expression={ $_.ID }},
                                            @{name="name";expression={ "$( $_.ID )$( $settings.nameConcatChar )$( $_.Name )$( if ($_.Description -ne '') { $settings.nameConcatChar } )$( $_.Description )" }}

#>

#-----------------------------------------------
# RECIPIENT LISTS
#-----------------------------------------------

$statusToFilter = $settings.mailings.status

# Get all transactional mailings
$transactionalMailings = Invoke-Epi -webservice "Mailing" -method "getIdsInStatus" -param @("event", $statusToFilter) -useSessionId $true

# Create all combinations of transactional mailings and the connected recipient lists
$transactionalCombinations = [array]@()
$transactionalMailings | ForEach-Object {
    
    $mailingId = $_

    # Get name for the mailing
    $mailingName = Invoke-Epi -webservice "Mailing" -method "getName" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true

    # Get 1..n recipient lists per transactional mailing
    $mailingRecipientLists = Invoke-Epi -webservice "Mailing" -method "getRecipientListIds" -param @(@{value=$mailingId;datatype="long"}) -useSessionId $true

    # Load recipient lists metadata
    $mailingRecipientLists | ForEach-Object {
        
        $recipientListId = $_

        # ask for name
        $recipientListName = Invoke-Epi -webservice "RecipientList" -method "getName" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true

        # ask for description
        $recipientListDescription = Invoke-Epi -webservice "RecipientList" -method "getDescription" -param @(@{value=$recipientListID;datatype="long"}) -useSessionId $true

        # Bring everything together
        $transactionalCombinations += [PSCustomObject]@{
            Id = $mailingId
            Name = $mailingName
            ListId = $recipientListId
            ListName = $recipientListName
            ListDescription = $recipientListDescription
        }

    }

}


#-----------------------------------------------
# GET MAILINGS DETAILS
#-----------------------------------------------

$messages = $transactionalCombinations | Select-Object @{name="id";expression={ $_.ListId }},
                                            @{name="name";expression={ "$( $_.Id )$( $settings.nameConcatChar )$( $_.ListId )$( $settings.nameConcatChar )$( $_.Name )$( $settings.nameConcatChar )$( $_.ListName )" }}



################################################
#
# RETURN
#
################################################

# real messages
return $messages


