
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
        scriptPath= "D:\Scripts\CleverReach\Tagging"
	    MessageName= "-FreeTry.Login" # just add - to remove a tag like -test.tag or -test.*
        Username= "abc"
        ListName= "Free Try Automation"
        # Coming from Upload
        EmailFieldName= "Email"
        Path= "D:\Apteco\Publish\CleverReach\system\Deliveries\PowerShell_1122853  Free Try Automation_fea11774-c67e-4081-8506-55303b0318d1.txt"
        UrnFieldName= "RC Id"
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

# TODO [ ] implement loading bigger files later


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

Write-Log -message "Required fields $( $requiredFields -join ", " )"


# Load global attributes

$object = "attributes"
$endpoint = "$( $apiRoot )$( $object ).json"
$globalAttributes = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header  -Verbose -ContentType $contentType
$localAttributes = Invoke-RestMethod -Method Get -Uri "$( $endpoint )?group_id=$( $groupId )" -Headers $header  -Verbose -ContentType $contentType
$attributes = $globalAttributes + $localAttributes

Write-Log -message "Loaded global attributes $( $globalAttributes.name -join ", " )"
Write-Log -message "Loaded local attributes $( $localAttributes.name -join ", " )"


# TODO [ ] Implement re-using a group (with deactivation of receivers and comparation of local fields)

$attributesNames = $attributes | where { $_.name -notin $requiredFields }
$csvAttributesNames = Get-Member -InputObject $dataCsv[0] -MemberType NoteProperty 
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
$endpoint = "$( $apiRoot )$( $object ).json/$( $newGroup.id )/attributes"
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

$globalAtts = $globalAttributes | where { $_.name -in $csvAttributesNames.Name }
$tags = ,$params.MessageName -split ","
$upload = @()
$uploadObject = @()
For ($i = 0 ; $i -lt $dataCsv.count ; $i++ ) {

    $uploadEntry = [PSCustomObject]@{
        email = $dataCsv[$i].email
        global_attributes = [PSCustomObject]@{}
        attributes = [PSCustomObject]@{}
        tags = @() # e.g. @("-Test.*") for removing all tags that begin with Test.
    }

    # Global attributes
    $globalAtts | ForEach {
        $attrName = $_.name
        $uploadEntry.global_attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrName
    }

    # New local attributes
    $newAttributes | ForEach {
        $attrName = $_.name
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrName
    }

    # Existing local attributes
    $localAttributes | ForEach {
        $attrName = $_.name
        $uploadEntry.attributes | Add-Member -MemberType NoteProperty -Name $attrName -Value $dataCsv[$i].$attrName
    }

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
    
    #-----------------------------------------------
    # UPSERT DATA INTO GROUP
    #-----------------------------------------------

    $object = "groups"
    $endpoint = "$( $apiRoot )$( $object ).json/$( $groupId )/receivers/upsertplus"
    $bodyJson = $uploadEntry | ConvertTo-Json
    
    $upload += Invoke-RestMethod -Uri $endpoint -Method Post -Headers $header -Body $bodyJson -ContentType $contentType -Verbose 
    #$bodyJson | Set-Content -path "$( $scriptPath )\archive\$( $processId ).json" -Encoding UTF8

}

Write-Log -message "Use the tags: $( $tags -join ", " )"

Write-Log -message "UpsertPlus for $( $upload.count ) records"


################################################
#
# RETURN VALUES TO PEOPLESTAGE
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
    "CustomProvider"=$moduleName
    "ProcessId" = $processId
}

# return the results
$return
