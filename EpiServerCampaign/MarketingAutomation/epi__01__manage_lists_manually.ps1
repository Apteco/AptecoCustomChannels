
################################################
#
# NOTES
#
################################################

<#

https://world.episerver.com/documentation/developer-guides/campaign/SOAP-API/introduction-to-the-soap-api/webservice-overview/
WSDL: https://api.campaign.episerver.net/soap11/RpcSession?wsdl

TODO  [ ] add more logging in the different operations

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
$moduleName = "MANAGELISTS"


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
#$guid = ([guid]::NewGuid()).Guid


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
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t$( $moduleName )" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile

# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    $params.Keys | ForEach {
        $param = $_
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
    }
}

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
$recipientListFile = "$( $settings.mailings.recipientListFile )"
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
    "remove"="remove a recipient list from the list"
    "nothing"="nothing"
}

$operation = $operations | Out-GridView -PassThru | Select -First 1

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChosen the operation ""$( $operation.Key )""" >> $logfile


#-----------------------------------------------
# DO THE OPERATION
#-----------------------------------------------

$newLists = @()
switch ( $operation.Key ) {

    <#
    Select one or multiple lists and they get copied and will be created empty and added to your recipient lists. You will also get prompted for a new name
    #>
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

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCopying the list ""$( $recipientList.id )"" with name ""$( $originalrecipientListName )"" to new ID ""$( $newID )"" with name ""$( $newName )""" >> $logfile
 

        }

        # load recipient lists again after copying
        $recipientLists = Get-EpiRecipientLists 

        $newLists = $recipientLists | where { $_.id -in $newIDs } | select id, 'ID-Feld'
        
        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tCreated the new lists $( $newLists.id -join ',' )" >> $logfile

    }

    <#
    Just load all lists and add them to the recipient lists file
    #>
    "add" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 

        # Promp the user to select the ones to add
        $newLists = $recipientLists | Out-GridView -PassThru | select id, 'ID-Feld'

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tAdding the lists $( $newLists.id -join ',' )" >> $logfile

    }

    <#
    Just load all lists, select the ones you want to rename online and in your recipient lists and you will be prompted for that. 
    #>
    "rename" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 

        # Promp the user to select the ones to rename
        $changeNames = $recipientLists | Out-GridView -PassThru

        # Ask for every single list in the selection
        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.id
            $recipientListName = $_.Name

            # set the name of the new list
            $newName = Read-Host -Prompt "New name for list '$( $recipientListID )' - '$( $recipientListName )'"
            Invoke-Epi -webservice "RecipientList" -method "setName" -param @(@{value=$recipientListID;datatype="long"},@{value=$newName;datatype="String"}) -useSessionId $true

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the name online for List $( $recipientListID ) from ""$( $recipientListName )"" to ""$( $newName )""" >> $logfile

        }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the names online for lists $( $changeNames.id -join ',' )" >> $logfile

    }

    <#
    Just show all lists from online
    #>
    "show" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 
        
        # Show them
        $recipientLists | Out-GridView 

    }

    <#
    Remove lists from the local json file
    #>
    "remove" {
        
        # Load all lists
        $recipientLists = Get-EpiRecipientLists 
        
        # Show them
        $removeLists = $recipientLists | where { $_.id -in $existingRecipientLists.id } | Out-GridView -PassThru

        $existingRecipientLists = $existingRecipientLists | where { $_.id -notin $removeLists.id }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tRemoved the lists locally $( $removeLists.id -join ',' )" >> $logfile

    }

    <#
    Add a description to a bunch of lists online, you will be asked about the new description
    #>
    "addDescription" {

        # Load all lists    
        $recipientLists = Get-EpiRecipientLists 

        # Select the ones to rename
        $changeNames = $recipientLists | Out-GridView -PassThru

        # Change each description
        $changeNames | ForEach {
            
            # create new recipient list
            $recipientListID = $_.ID
            $recipientListName = $_.Name
            $recipientListDescription = $_.Description

            # set the name of the new list
            $newDescription = Read-Host -Prompt "New description for list '$( $recipientListID )' - '$( $recipientListName )' - '$( $recipientListDescription )'"
            Invoke-Epi -webservice "RecipientList" -method "setDescription" -param @(@{value=$recipientListID;datatype="long"},@{value=$newDescription;datatype="String"}) -useSessionId $true

            # Log the result
            "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the description online for List $( $recipientListID ) from ""$( $recipientListDescription )"" to ""$( $newDescription )""" >> $logfile

        }

        # Log the result
        "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tChanged the descriptions online for lists $( $changeNames.id -join ',' )" >> $logfile


    }


}


#-----------------------------------------------
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#-----------------------------------------------

if ( $operation.Key -in $("add","copy","remove") ) { 

    # pack everything together
    $recipientListsForExport = [array]$existingRecipientLists + [array]$newLists

    # create json object
    $json = $recipientListsForExport | ConvertTo-Json -Depth 8 # -compress

    # print settings to console
    $json

    # save settings to file
    $json | Set-Content -path "$( $recipientListFile )" -Encoding UTF8

    # Log the result
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tSaved the new recipient file ""$( $recipientListFile )""" >> $logfile


}

