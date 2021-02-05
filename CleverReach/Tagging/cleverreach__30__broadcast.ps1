
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
<<<<<<< HEAD:CleverReach/Mailing/cleverreach__20__upload_list.ps1
	    EmailFieldName= "email"
	    TransactionType= "Replace"
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\CleverReach"
	    MessageName= "-Test.Tag001" # just add - to remove a tag like -test.tag or -test.*
	    SmsFieldName= ""
	    Path= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\CleverReach\CleverReach_Bewertung Post Stay_b33c83bc-d396-422c-abb8-f766826cb4e9.txt"
	    UrnFieldName= "Urn"
	    ListName= "CR Tag Test" # TODO [ ] if PeopleStage will offer lists as dropdown, we need to re-check this "text only" parameter
	    CommunicationKeyFieldName= "Communication Key"
=======
    <#
        # PeopleStage Native Parameters
        MessageName = "GV.Test"
        Username = "a"
        Password = "b"
        ListName = "1128248 / AptecoTestGruppe2020"
        
        # Parameters handed over from Upload
        CustomProvider = "CLVRUPLOAD"
        ProcessId = "decc7ca6-2459-4050-bd0f-45169d6a51c3"
        UrnFieldName = "Con Acc Id"
        TransactionId = "decc7ca6-2459-4050-bd0f-45169d6a51c3"        
        Path = "D:\Apteco\Publish\GV\system\Deliveries\PowerShell_1128248  AptecoTestGruppe2020_e36faf87-bd78-401a-8a0a-777f57d28ef2.txt"
        EmailFieldName = "email"

        # PeopleStage Integration Parameters
        uploadType = "batch"
        scriptPath = "D:\Scripts\CleverReach\Tagging"
        #>
        ProcessId = "787a49fe-af48-4096-befb-603544570a10"
        MessageName = "GV.Partner"
        Username = "a"
        TransactionId = "787a49fe-af48-4096-befb-603544570a10"
        CustomProvider = "CLVRUPLOAD"
        UrnFieldName = "Con Acc Id"
        Password = "b"
        ListName = "GV.Partner"
        uploadType = "batch"
        Path = "D:\Apteco\Publish\GV\system\Deliveries\PowerShell_GV.Partner_103c4e7d-1105-4c74-993e-059c3e7e09dd.txt"
        EmailFieldName = "email"
        scriptPath = "D:\Scripts\CleverReach\Tagging"

>>>>>>> dev-cr:CleverReach/Tagging/cleverreach__30__broadcast.ps1
    }
}


################################################
#
# NOTES
#
################################################

<#
TOTO [ ] Documentation about 
uploadType = "single" # single|batch -> single is important when you want to trigger thea automations dependent on a new tag


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
$moduleName = "CLVRBROADCAST"
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
# AUTHENTICATION
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"
$auth = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
$header = @{
    "Authorization" = $auth
}

Write-Log -message "Setting authentication"


#-----------------------------------------------
# LOAD DATA
#-----------------------------------------------

# TODO [ ] implement loading bigger files later, see https://github.com/Apteco/HelperScripts/blob/master/functions/Files/Split-File.ps1


# Get file item
$file = Get-Item -Path $params.Path
$filename = $file.Name -replace $file.Extension

Write-Log -message "Loading data from $( $file.fullname )"

# Load data from file
$dataCsv = @()
$dataCsv += import-csv -Path $file.FullName -Delimiter "`t" -Encoding UTF8

Write-Log -message "Loaded $( $dataCsv.count ) records"


#-----------------------------------------------
# CREATE GROUP IF NEEDED
#-----------------------------------------------

# If lists contains a concat character (id+name), use the list id
# if no concat character is present, take the whole string as name for a new list and search for it... if not present -> new list!
# if no list is present, just take the current date and time

# If listname is valid -> contains an id, concatenation character and and a name -> use the id
try {
    
    $createNewGroup = $false # No need for the group creation now
    $group = [List]::new($params.ListName)
    $listName = $group.listName
    $groupId = $group.listId
    Write-Log -message "Ready to use group with id $( $groupId )"


} catch {

    # Listname is the same as the message means nothing was entered -> check the name
    if ($params.ListName -ne $params.MessageName) {

        # Try to search for that group and select the first matching entry or throw exception
        $object = "groups"    
        $endpoint = "$( $apiRoot )$( $object )"
        $groups = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType
        
        # Check how many matches are available
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

            }

            # More than one match -> throw exception
            Default {
                $createNewGroup = $false # No need for the group creation now
                Write-Log -message "More than one match -> throw exception"
                throw [System.IO.InvalidDataException] "More than two groups with that name. Please choose a unique list."              
            }
        }

    # String is empty, create a generic group name
    } else {
        $createNewGroup = $true
        $listName = [datetime]::Now.ToString("yyyyMMdd_HHmmss")
        Write-Log -message "Create a new group with a timestamp"
    }

}

<#
# If lists contains a concat character (id+name), use the list id
# if no concat character is present, take the whole string as name for a new list and search for it... if not present -> new list!
# if no list is present, just take the current date and time
$listItems = $params.ListName -split $settings.nameConcatChar
$createNewGroup = $true
if ( $listItems[1].count -gt 0 ) {

    $listName = $listItems[0]
    $groupId = $listName
    $createNewGroup = $false

    Write-Log -message "Loaded group with id $( $groupId ), no need for new group"

} elseif ( $listItems[0].count -gt 0 ) {
    
    $listNameTxt = $listItems[0]

    # Try to search for that group
    $object = "groups"    
    $endpoint = "$( $apiRoot )$( $object )"
    $groups = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType "application/json; charset=utf-8"
    
    Write-Log -message "Loaded $( $groups.count ) from CleverReach first to compare names"

    $matchGroups = ( $groups | where { $_.name -eq $listNameTxt } | sort stamp -Descending | Select -first 1 ).id

    if ( $matchGroups.count -ne "" ) {
        $listName = $matchGroups
        $groupId = $listName
        $createNewGroup = $false
        Write-Log -message "Found a group with name $( $listName ) that resolved into the id $( $groupId ) -> No need for a new group"
    } else {
        $listName = $listNameTxt
        Write-Log -message "Found no group with name $( $listName ) and will create a new one"
    }


} else {

    $listName = [datetime]::Now.ToString("yyyyMMdd HHmmss")
    Write-Log -message "Will create a new group with date as name: $( $listname )"

}
#>
# Create a new group (if needed)
if ( $createNewGroup ) {
    $object = "groups"
    $endpoint = "$( $apiRoot )$( $object ).json"
    $body = @{"name" = "$( $listName )" } # $processId.guid
    $bodyJson = $body | ConvertTo-Json
    $newGroup = Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
    $groupId = $newGroup.id
    Write-Log -message "Created a new group with id $( $groupId )"
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
#$differences = Compare-Object -ReferenceObject $attributesNames.name -DifferenceObject ( $csvAttributesNames  | where { $_.name -notin $requiredFields } ).name -IncludeEqual #-Property Name 
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

Write-Log -message "Created new local attributes in CleverReach: $( $newAttributes.name -join ", " )"


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
$tags = ,$params.MessageName -split ","
$upload = @()
$uploadObject = @()
For ($i = 0 ; $i -lt $dataCsv.count ; $i++ ) {

    $uploadEntry = [PSCustomObject]@{
        email = $dataCsv[$i].email
        global_attributes = [PSCustomObject]@{}
        attributes = [PSCustomObject]@{}
    }

    # Global attributes
    $globalAtts | ForEach {
        $attrName = $_.name # using description now rather than name, because the comparison is made on descriptions
        $attrDescription = $_.description
        $uploadEntry.global_attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrDescription
    }

    # New local attributes
    $newAttributes | ForEach {
        $attrName = $_.name # using description now rather than name, because the comparison is made on descriptions
        $attrDescription = $_.description
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrDescription
    }

    # Existing local attributes
    $localAttributes | ForEach {
        $attrName = $_.name # using description now rather than name, because the comparison is made on descriptions
        $attrDescription = $_.description
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrDescription
    }

<<<<<<< HEAD:CleverReach/Mailing/cleverreach__20__upload_list.ps1
    $uploadObject += $uploadEntry
=======
    # Tags
    <#
    In the array of tags, prepend a "-" to the tag you want to be removed.
    To remove all tags with a specific origin, simply specify "*" instead of any tag name.
    #>
    $uploadEntry.tags = $tags

    <#
        #$props = Get-Member -InputObject $dataCsv[$i] -MemberType NoteProperty | where { $_.Name -ne "email" }
    ForEach($prop in $props) {
        $propName = $prop.Name
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $prop.Name -Value $dataCsv[$i].$propName
    }
    #>

    #$uploadObject += $uploadEntry
>>>>>>> dev-cr:CleverReach/Tagging/cleverreach__30__broadcast.ps1
    
    #-----------------------------------------------
    # UPSERT DATA INTO GROUP
    #-----------------------------------------------

    # Single upload
    if ( $params.uploadType -eq "single" ) {
        $bodyJson = $uploadEntry | ConvertTo-Json
        $bodyJson | Set-Content -path "$( $tempFolder )\$( $i ).json" -Encoding UTF8
        $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
        #$bodyJson | Set-Content -path "$( $scriptPath )\archive\$( $processId ).json" -Encoding UTF8

    # Batch upload every n records or at the end
    } else {

        $uploadObject += $uploadEntry

        #if ( $i % $settings.upload.rowsPerUpload -eq 0 -or ($i - 1) -eq $dataCsv.count) {
        if ( ($i + 1) % $settings.upload.rowsPerUpload -eq 0 -or ($i + 1) -eq $dataCsv.count ) {

<<<<<<< HEAD:CleverReach/Mailing/cleverreach__20__upload_list.ps1
$object = "groups"
$endpoint = "$( $apiRoot )$( $object ).json/$( $groupId )/receivers/upsertplus"
$bodyJson = $uploadObject | ConvertTo-Json
$upload = @()
$upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
=======
            $bodyJson = $uploadObject | ConvertTo-Json
            $bodyJson | Set-Content -path "$( $tempFolder )\$( $i ).json" -Encoding UTF8
            $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
            $uploadObject = @()
        }
    }

}

Write-Log -message "Use the tags: $( $tags -join ", " )"

# TODO [ ] Check this entry
Write-Log -message "UpsertPlus for $( $upload.count ) records"
>>>>>>> dev-cr:CleverReach/Tagging/cleverreach__30__broadcast.ps1


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
    "Recipients"=$recipients
    "TransactionId"=$transactionId
<<<<<<< HEAD:CleverReach/Mailing/cleverreach__20__upload_list.ps1
    "GroupId"=$groupId    
=======
    "CustomProvider"=$moduleName
    "ProcessId" = $processId
>>>>>>> dev-cr:CleverReach/Tagging/cleverreach__30__broadcast.ps1
}

# return the results
$return
