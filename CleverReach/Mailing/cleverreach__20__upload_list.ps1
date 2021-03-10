
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
        
        # Send from PeopleStage
        TransactionType = "Replace"
        Password = "b"
        MessageName = ""
        EmailFieldName = "email"
        Path = "D:\Apteco\Publish\GV\system\Deliveries\PowerShell_6299985  1-to-1 Einladung dmexco_ceb0f74c-bc52-4a2f-9816-455a13689fd8.txt"
        ReplyToEmail = ""
        Username = "a"
        ReplyToSMS = ""
        UrnFieldName = "Con Acc Id"
        ListName = "6299985 / 1-to-1 Einladung dmexco"
        CommunicationKeyFieldName = "Communication Key"
        SmsFieldName = ""

        # Integration parameters
        scriptPath = "D:\Scripts\CleverReach\Mailing"
        deactivate = "true"

    }
}

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
$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "CLVRUPLOAD"
$processId = [guid]::NewGuid()

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
        #[System.Net.SecurityProtocolType]::Tls13,
        #,[System.Net.SecurityProtocolType]::Ssl3
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
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}

# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

Add-Type -AssemblyName System.Data

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}
<#
# Load all exe files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.exe") 
$libExecutables | ForEach {
    "... $( $_.FullName )"
    
}
# Load dll files in subfolder
$libExecutables = Get-ChildItem -Path ".\$( $libSubfolder )" -Recurse -Include @("*.dll") 
$libExecutables | ForEach {
    "Loading $( $_.FullName )"
    [Reflection.Assembly]::LoadFile($_.FullName) 
}
#>

################################################
#
# LOG INPUT PARAMETERS
#
################################################

# Start the log
Write-Log -message "----------------------------------------------------"
Write-Log -message "$( $modulename )"
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}



################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

$uploadsFolder = $settings.upload.uploadsFolder

$foldersToCheck = @(
    $uploadsFolder
    ".\$( $libSubfolder )"
)

$foldersToCheck | ForEach {
    $checkFolder = $_
    if ( !(Test-Path -Path $checkFolder) ) {
        Write-Log -message "Upload $( $checkFolder ) does not exist. Creating the folder now!"
        New-Item -Path "$( $checkFolder )" -ItemType Directory
    }
}


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$auth = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
$header = @{
    "Authorization" = $auth
}


#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

# TODO [ ] implement loading bigger files later

# Get file item
$file = Get-Item -Path $params.Path
$filename = $file.Name -replace $file.Extension

# Load data from file
$dataCsv = @()
$dataCsv += import-csv -Path $file.FullName -Delimiter "`t" -Encoding UTF8


#-----------------------------------------------
# CREATE GROUP IF NEEDED
#-----------------------------------------------

# If lists contains a concat character (id+name), use the list id
# if no concat character is present, take the whole string as name for a new list and search for it... if not present -> new list!
# if no list is present, just take the current date and time

# If listname is valid -> contains an id, concatenation character and and a name -> use the id

#-----------------------------------------------
# CREATE GROUP IF NEEDED
#-----------------------------------------------

# TODO [ ] IT NEEDS TO CHECK THE EQUALITY OF MESSAGE AND LIST FIRST

# If lists contains a concat character (id+name), use the list id
# if no concat character is present, take the whole string as name for a new list and search for it... if not present -> new list!
# if no list is present, just take the current date and time

# If listname is valid -> contains an id, concatenation character and and a name -> use the id

# Listname is the same as the message means nothing was entered -> check the name
# Or MessageName is empty means "Upload only" from PeopleStage  and then it is worth to check, too

$timestamp = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
if ($params.ListName -ne $params.MessageName -or $params.MessageName -eq "") {

    # Download all groups first
    $object = "groups"    
    $endpoint = "$( $apiRoot )$( $object )"
    $groups = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType

    # Try to parse the group name and search for that group, but it could also be a messagename
    try {
    
        $createNewGroup = $false # No need for the group creation now
        $group = [List]::new($params.ListName)
        $matchingGroups = @( $groups | where { $_.id -eq $group.listId } ) # put an array around because when the return is one object, it will become a pscustomobject
        
        switch ( $matchingGroups.Count ) {
            # No match -> new group
            0 { 
                $createNewGroup = $true                
                $listName = $timestamp #"$( $group.listName ) | $( $timestamp )"
                Write-Log -message "No matched group -> create a new one"
            }
            
            # One match -> use that one!
            1 { 
                $createNewGroup = $false # No need for the group creation now
                $listName = $matchingGroups.name
                $groupId = $matchingGroups.id
                Write-Log -message "Matched one group -> use that one"
                Write-Log -message "Ready to use group with id $( $groupId )"
            }
        }

    } catch {

        # Parsing was not successful, check how many matches are available
        $matchingGroups = @( $groups | where { $_.name -eq $params.ListName } ) # put an array around because when the return is one object, it will become a pscustomobject

        switch ( $matchingGroups.Count ) {

            # No match -> new group
            0 { 
                $createNewGroup = $true                
                $listName = $params.ListName
                Write-Log -message "No matched group -> create a new one"
            }
            
            # One match -> use that one!
            1 { 
                $createNewGroup = $false # No need for the group creation now
                $listName = $matchingGroups.name
                $groupId = $matchingGroups.id
                Write-Log -message "Matched one group -> use that one"
                Write-Log -message "Ready to use group with id $( $groupId )"
            }

            # More than one match -> throw exception
            Default {
                $createNewGroup = $false # No need for the group creation now
                Write-Log -message "More than one match -> throw exception"
                throw [System.IO.InvalidDataException] "More than two groups with that name. Please choose a unique list."              
            }

        }

    }

# String is empty, create a generic group name
} else {
    $createNewGroup = $true
    $listName = $timestamp
    Write-Log -message "Create a new group with a timestamp"
}


# Create a new group (if needed)
if ( $createNewGroup ) {
    $object = "groups"
    $endpoint = "$( $apiRoot )$( $object ).json"
    $body = @{"name" = "$( $listName )" } # $processId.guid
    $bodyJson = $body | ConvertTo-Json
    $newGroup = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
    $groupId = $newGroup.id
}


#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$requiredFields = @(,$params.EmailFieldName)
$reservedFields = @("tags")

Write-Log -message "Required fields $( $requiredFields -join ", " )"
Write-Log -message "Reserved fields $( $reservedFields -join ", " )"

# Load online attributes

$object = "attributes"
$endpoint = "$( $apiRoot )$( $object ).json"
$globalAttributes = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header  -Verbose -ContentType $contentType
$localAttributes = Invoke-RestMethod -Method Get -Uri "$( $endpoint )?group_id=$( $groupId )" -Headers $header  -Verbose -ContentType $contentType
$attributes = $globalAttributes + $localAttributes

Write-Log -message "Loaded global attributes $( $globalAttributes.name -join ", " )"
Write-Log -message "Loaded local attributes $( $localAttributes.name -join ", " )"

# TODO [x] Implement re-using a group (with deactivation of receivers and comparation of local fields)

$attributesNames = $attributes | where { $_.name -notin $requiredFields }
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty | where { $_.Name -notin $reservedFields }
Write-Log -message "Loaded csv attributes $( $csvAttributesNames.Name -join ", " )"

# Check if email field is present

$equalWithRequirements = Compare-Object  -ReferenceObject $csvAttributesNames.Name -DifferenceObject $requiredFields -IncludeEqual -PassThru | where { $_.SideIndicator -eq "==" }

if ( $equalWithRequirements.count -eq $requiredFields.Count ) {
    # Required fields are all included

} else {
    # Required fields not equal -> error!
    throw [System.IO.InvalidDataException] "No email field present!"  
}

# Compare columns
# TODO [ ] Now the csv column headers are checked against the description of the cleverreach attributes and not the (technical name). Maybe put this comparation in here, too. E.g. description "Communication Key" get the name "communication_key"
$differences = Compare-Object -ReferenceObject $attributesNames.description -DifferenceObject ( $csvAttributesNames  | where { $_.name -notin $requiredFields } ).name -IncludeEqual #-Property Name 
$colsEqual = $differences | where { $_.SideIndicator -eq "==" } 
$colsInAttrButNotCsv = $differences | where { $_.SideIndicator -eq "<=" } 
$colsInCsvButNotAttr = $differences | where { $_.SideIndicator -eq "=>" }


#-----------------------------------------------
# CREATE LOCAL ATTRIBUTES
#-----------------------------------------------

$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $groupId )/attributes"
$newAttributes = @()
$colsInCsvButNotAttr | ForEach {

    $newAttributeName = $_.InputObject

    $body = @{
        "name" = $newAttributeName
        "type" = "text"                     # text|number|gender|date
        "description" = $newAttributeName   # optional 
        #"preview_value" = "real name"       # optional
        #"default_value" = "Bruce Wayne"     # optional
    }
    $bodyJson = $body | ConvertTo-Json

    $newAttributes += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 

}



#-----------------------------------------------
# DEACTIVATE ALL RECEIVERS FIRST IF NEEDED
#-----------------------------------------------

# TODO [ ] Documentation of the integration parameter "deactivate=true"

if ( !$createNewGroup -and $params.deactivate -eq "true") {

    $groupsUrl = "$( $settings.base )groups.json"
    $detailLevel = 0
    $page = 0
    $upload = @()
    do {

        $url = "$( $groupsUrl )/$( $groupId )/receivers?pagesize=$( $settings.upload.rowsPerUpload )&page=$( $page )&detail=$( $detailLevel )&type=active" # active|inactive
        $result = Invoke-RestMethod -Method Get -Uri $url -Headers $header -Verbose

        if ( $result.Count -gt 0 ) {

            #-----------------------------------------------
            # CREATE UPSERT OBJECT
            #-----------------------------------------------


            $uploadObject = @()
            For ($i = 0 ; $i -lt $result.count ; $i++ ) {

                $uploadEntry = [PSCustomObject]@{
                    email = $result[$i].email
                    deactivated = 1
                }

                $uploadObject += $uploadEntry

            }


            #-----------------------------------------------
            # UPSERT DATA INTO GROUP
            #-----------------------------------------------

            $object = "groups"
            $endpoint = "$( $groupsUrl )/$( $groupId )/receivers/upsertplus"
            $bodyJson = $uploadObject | ConvertTo-Json

            $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 

            Write-Log -message "Deactivated $( $upload.count ) 'contacts' in total"

        }

    } while ( $result.Count -eq $settings.pageLimitGet )
    
    Write-Log -message "Done with deactivating $( $upload.count ) 'contacts' in group '$( $groupId )'"
}


#-----------------------------------------------
# TRANSFORM UPLOAD DATA
#-----------------------------------------------

# TODO [ ] put this into another type of loop to build a max. no of records per batch

# to set receivers active, do something like:
<#
{ "postdata":[
    {"id"="5","deactivated"="0"},{"id"="119","deactivated"="0"}
]}
#>

# Filenames
$tempFolder = "$( $settings.upload.uploadsFolder )\$( $processId.guid )"
New-Item -ItemType Directory -Path $tempFolder
Write-Log -message "Creating files in $( $tempFolder )"

$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $groupId )/receivers/upsertplus"
$globalAtts = $globalAttributes | where { $_.name -in $csvAttributesNames.Name }
$uploadObject = @()
# TODO [ ] implement the upload in chunks rather than mod like for ELAINE transactional implementation
For ($i = 0 ; $i -lt $dataCsv.count ; $i++ ) {
    
    $currentRecord = $dataCsv[$i]

    $uploadEntry = [PSCustomObject]@{
        email = $currentRecord.email
        deactivated = 0
        global_attributes = [PSCustomObject]@{}
        attributes = [PSCustomObject]@{}
        tags = @() # e.g. @("-Test.*") for removing all tags that begin with Test.
    }

    # Global attributes
    $globalAtts | ForEach {
        $attrName = $_.name
        $uploadEntry.global_attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $currentRecord.$attrName
    }

    # Existing local attributes, try technical name first, otherwise description of field
    @( $newAttributes + $localAttributes ) | ForEach {
        $attrName = $_.name
        $attrDesc = $_.description
        if ( $currentRecord.$attrName -ne $null ) {
            $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $currentRecord.$attrName
        } else {
            $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $currentRecord.$attrDesc
        }
    }

    # Tags
    <#
    In the array of tags, prepend a "-" to the tag you want to be removed.
    To remove all tags with a specific origin, simply specify "*" instead of any tag name.
    #>
    if ( $currentRecord.tags.length -gt 0 ) {
        $uploadEntry.tags += ( $currentRecord.tags -split "," )
    }

    $uploadObject += $uploadEntry

    #-----------------------------------------------
    # UPSERT DATA INTO GROUP
    #-----------------------------------------------

    # Batch upload every n records or at the end
    #if ( $i % $settings.upload.rowsPerUpload -or ($i - 1) -eq $dataCsv.count) {
    if ( ($i + 1) % $settings.upload.rowsPerUpload -eq 0 -or ($i + 1) -eq $dataCsv.count ) {

        $bodyJson = $uploadObject | ConvertTo-Json
        $bodyJson | Set-Content -path "$( $tempFolder )\$( $i ).json" -Encoding UTF8
        $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
        $uploadObject = @()
    }

}

Write-Log -message "UpsertPlus for $( $upload.count ) records"


#-----------------------------------------------
# UPSERT DATA INTO GROUP
#-----------------------------------------------
<#
$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $groupId )/receivers/upsertplus"
$bodyJson = $uploadObject | ConvertTo-Json
$upload = @()
$upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
#>

################################################
#
# RETURN VALUES TO PEOPLESTAGE AND BROADCAST
#
################################################

# count the number of successful upload rows
$recipients = $upload.count

# put in the source id as the listname
$transactionId = $processId

# return object
$return = [Hashtable]@{

    # Needed for PeopleStage
    "Recipients"=$recipients
    "TransactionId"=$transactionId

    # Needed for broadcast script
    "GroupId"=$groupId    

}

# return the results
$return

