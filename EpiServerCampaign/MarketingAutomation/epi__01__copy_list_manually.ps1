<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

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

# - [ ] TODO Remove scriptPath here and set the path through the settings dialogue

################################################
#
# SETTINGS
#
################################################


# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json
$changeTLSEncryption = $true

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
# LOAD EXISTING RECIPIENT LISTS
#-----------------------------------------------

# get lists, if they are existing
$recipientListFile = "$( $scriptPath )\$( $settings.recipientListFile )"
If ( Test-Path -Path $recipientListFile ) {
    $existingRecipientLists = Get-Content -Path $recipientListFile -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    $existingRecipientLists = @()
}




#-----------------------------------------------
# WHAT TO DO?
#-----------------------------------------------

# operations
$operations = @{
    "copy"="copy/duplicate an existing recipient list in episerver"
    "add"="add a list to be used in PeopleStage"
    "rename"="change the name of an existing list"
    "addDescription"="adds a description to the list name"
    "show"="just show all lists"
    "nothing"="nothing"
}

$operation = $operations | Out-GridView -PassThru


#-----------------------------------------------
# DO THE OPERATION
#-----------------------------------------------

$newLists = @()
switch ( $operation.Key ) {

    "copy" {
    
        #-----------------------------------------------
        # LOAD ALL LISTS AND CREATE NEW ONES
        #-----------------------------------------------

        $recipientLists = Get-EpiRecipientLists 

        $recipientListsForCopy = $recipientLists | Out-GridView -PassThru

        $newIDs = @()
        $recipientListsForCopy | ForEach {
            
            # create new recipient list
            $recipientList = $_
            $newID = Invoke-Epi -webservice "RecipientList" -method "copy" -param @(@{value=$recipientList.id;datatype="long"}) -useSessionId $true
            $newIDs += $newID

            # get the name of the original list
            $originalrecipientListName = Invoke-Epi -webservice "RecipientList" -method "getName" -param @(@{value=$recipientList.id;datatype="long"}) -useSessionId $true

            # set the name of the new list
            $newName = Read-Host -Prompt "New name for copy of '$( $originalrecipientListName )'"
            Invoke-Epi -webservice "RecipientList" -method "setName" -param @(@{value=$newID;datatype="long"},@{value=$newName;datatype="String"}) -useSessionId $true

        }

        # load recipient lists again after copying
        $recipientLists = Get-EpiRecipientLists 

        $newLists = $recipientLists | where { $_.id -in $newIDs } | select id, 'ID-Feld'

    }

    "add" {
        
        #-----------------------------------------------
        # LOAD ALL LISTS
        #-----------------------------------------------

        $recipientLists = Get-EpiRecipientLists 

        $newLists = $recipientLists | Out-GridView -PassThru | select id, 'ID-Feld'



    }

    "rename" {
        
        #-----------------------------------------------
        # LOAD ALL LISTS
        #-----------------------------------------------

        $recipientLists = Get-EpiRecipientLists 

        $changeNames = $recipientLists | Out-GridView -PassThru

        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.id
            $recipientListName = $_.Name

            # set the name of the new list
            $newName = Read-Host -Prompt "New name for list '$( $recipientListID )' - '$( $recipientListName )'"
            Invoke-Epi -webservice "RecipientList" -method "setName" -param @(@{value=$recipientListID;datatype="long"},@{value=$newName;datatype="String"}) -useSessionId $true


        }

    }

    "show" {
    
        $recipientLists = Get-EpiRecipientLists 

        $newIDs = $recipientLists | Out-GridView 

    }

    "addDescription" {
    
        $recipientLists = Get-EpiRecipientLists 

        $changeNames = $recipientLists | Out-GridView -PassThru

        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.ID
            $recipientListName = $_.Name
            $recipientListDescription = $_.Description

            # set the name of the new list
            $newDescription = Read-Host -Prompt "New name for list '$( $recipientListID )' - '$( $recipientListName )' - '$( $recipientListDescription )'"
            Invoke-Epi -webservice "RecipientList" -method "setDescription" -param @(@{value=$recipientListID;datatype="long"},@{value=$newDescription;datatype="String"}) -useSessionId $true


        }

    }


}


#-----------------------------------------------
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#-----------------------------------------------

if ( $operation.Key -in $("add","copy") ) { 

    # pack everything together
    $recipientListsForExport = $existingRecipientLists + $newLists

    # create json object
    $json = $recipientListsForExport | ConvertTo-Json -Depth 8 # -compress

    # print settings to console
    $json

    # save settings to file
    $json | Set-Content -path "$( $scriptPath )\$( $settings.recipientListFile )" -Encoding UTF8

}

Exit 0
