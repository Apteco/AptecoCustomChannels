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

# TODO [ ] check input parameter

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\ELAINE\Transactional"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://docs.artegic.com/display/APIDE/Funktionsreferenz

# Good examples of possible formats to call the ELAINE API
$function = "api_getMailingsByStatus"
$uri = "$( $apiRoot )$( $function )?p1=ready&response=$( $settings.defaultResponseFormat )" # Possibility 1 - query parameters
$uri = "$( $apiRoot )$( $function )/ready?&response=$( $settings.defaultResponseFormat )"   # Possibility 2 - url path

# Preparation for the possibility 3 - serialised json
$jsonInput = @(
    "ready"
) 
$json = ConvertTo-Json $jsonInput -Compress # `$json | convertto-json` does not work properly with single elements
$jsonEscaped = [uri]::EscapeDataString($json)
$uri = "$( $apiRoot )$( $function )?json=$( $jsonEscaped )&response=$( $settings.defaultResponseFormat )"   # Possibility 3 - serialised json

# Prepare the API call
$restParams = @{
    Uri = $uri 
    Headers = $headers
    Verbose = $true
    Method = "Get"
    ContentType = $contentType
}

# Do the call
$mailings = Invoke-RestMethod @restParams

# Show the results
$mailings | Out-GridView

#>



<#
# The json format allows mostly calls per GET and POST
# POST should always be used when sensitive data like an email address is involved
# e.g. the function api_getDetails does not work with POST

# Example for GET
$function = "api_getGroups"
$jsonInput = @(
    ""      # user_id : filter only allowed groups for the user
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$groups = Invoke-RestMethod @restParams
$groups


# Example for POST
$function = "api_getGroups"
$jsonInput = @(
    ""      # user_id : filter only allowed groups for the user
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Post"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$groups = Invoke-RestMethod @restParams
$groups

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
$moduleName = "ELNTEST"
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
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

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
# AUTH
#-----------------------------------------------

# https://pallabpain.wordpress.com/2016/09/14/rest-api-call-with-basic-authentication-in-powershell/

# Step 2. Encode the pair to Base64 string
$encodedCredentials = [System.Convert]::ToBase64String([System.Text.Encoding]::ASCII.GetBytes("$( $settings.login.username ):$( Get-SecureToPlaintext $settings.login.token )"))
 
# Step 3. Form the header and add the Authorization attribute to it
$headers = @{ Authorization = "Basic $encodedCredentials" }


#-----------------------------------------------
# HEADER + CONTENTTYPE + BASICS
#-----------------------------------------------

$apiRoot = $settings.base
$contentType = "application/json; charset=utf-8"

$headers += @{

}

$defaultRestParams = @{
    Headers = $headers
    Verbose = $true
    ContentType = $contentType
}

$defaultRestParamsPost = @{
    Headers = $headers
    Verbose = $true
    Method = "Post"
    ContentType = "application/x-www-form-urlencoded"
}


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

$function = "api_getDatafields"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}

#$res = Invoke-RestMethod -Uri $url -Method get -Verbose -Headers $headers -ContentType $contentType
$fields = Invoke-RestMethod @restParams
#$fields | Out-GridView


#-----------------------------------------------
# ERROR CODES
#-----------------------------------------------

$function = "api_errorCodes"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$errorCodes = Invoke-RestMethod @restParams


#-----------------------------------------------
# BACKGROUND JOBS
#-----------------------------------------------

$function = "api_getBackgroundJobs"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$backgroundJobs = Invoke-RestMethod @restParams


#-----------------------------------------------
# DATA SOURCES
#-----------------------------------------------

$function = "api_getDatasources"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$dataSources = Invoke-RestMethod @restParams


#-----------------------------------------------
# ELAINE VERSION
#-----------------------------------------------

$function = "api_getElaineVersion"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?p1=false&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}

#$res = Invoke-RestMethod -Uri $url -Method get -Verbose -Headers $headers -ContentType $contentType
$version = Invoke-RestMethod @restParams


#-----------------------------------------------
# MAILINGS BY STATUS - METHOD 1
#-----------------------------------------------
<#
This one returns nl_id,nl_status,nl_failure_code,nl_start_time,nl_finish_time,nl_nr_of_mails,nl_sent_mails,nl_mails_failed,nl_send_limit
Possible status
on_hold|actionmail|ready|clearing|not_started|finished|processing|paused|aborted|failed|queued|scheduled|pending|sampling|deleted -> leerer string ist auch möglich für alle
#>

$function = "api_getMailingsByStatus"
$jsonInput = @(
    "ready" # message_status : on_hold|actionmail|ready|clearing|not_started|finished|processing|paused|aborted|failed|queued|scheduled|pending|sampling|deleted -> an empty string means all status
) 

$restParams = $defaultRestParams + @{
    #Uri = "$( $apiRoot )$( $function )?p1=ready&response=$( $settings.defaultResponseFormat )" # Possibility 1 - query parameters
    #Uri = "$( $apiRoot )$( $function )/ready?&response=$( $settings.defaultResponseFormat )"   # Possibility 2 - url path
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$mailings = Invoke-RestMethod @restParams
#$mailings | Out-GridView

<#
# Show the results with 
$mailings | group nl_status | select count, name

# And get something like
Count Name
----- ----
 1411 finished
   18 failed
   28 on_hold
   42 ready
    1 aborted
    6 actionmail
    2 landingpage

#>


#-----------------------------------------------
# MAILINGS BY STATUS - METHOD 2
#-----------------------------------------------
<#
This one returns the nl_id, nl_name and nl_status
#>

$function = "api_getMessageInfo"
$jsonInput = @(
    ""      # message_name : string
    "ready" # message_status : on_hold|actionmail|ready|clearing|not_started|finished|processing|paused|aborted|failed|queued|scheduled|pending|sampling|deleted -> an empty string means all status
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$mailings = Invoke-RestMethod @restParams
#$mailings | Out-GridView



#-----------------------------------------------
# CONTENT OF A MAILING
#-----------------------------------------------

$selectedMailing = $mailings | Out-GridView -PassThru

$function = "api_getMailingContent"
$jsonInput = @(
    $selectedMailing.nl_id      # nl_id : id of mailling to get content
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$mailingsContent = Invoke-RestMethod @restParams
$mailingsContent


#-----------------------------------------------
# GET ALL GROUPS
#-----------------------------------------------

$function = "api_getGroups"
$jsonInput = @(
    ""      # user_id : filter only allowed groups for the user
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Post"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$groups = Invoke-RestMethod @restParams
$groups


#-----------------------------------------------
# GET ALL GROUPS DETAILS VIA SINGLE CALLS (FIRST 10)
#-----------------------------------------------

$function = "api_getDetails"
$groupsDetails = [System.Collections.ArrayList]@()
$groups | ForEach-Object {

    $groupId = $_
    $jsonInput = @(
        "Group"       # objectType : Datafield|Mailing|Group|Segment
        "$( $groupId )"      # objectID
    ) 
    $restParams = $defaultRestParams + @{
        Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
        Method = "Get"
       # Body = ""
    }
    $res = Invoke-RestMethod @restParams
    $groupsDetails.Add($res)
    
}
$groupDetailsFiltered = $groupsDetails | where { $_.ev_id -ne $null }
$groupDetailsFiltered.Count


#-----------------------------------------------
# GET ALL GROUPS DETAILS VIA BULK
#-----------------------------------------------

<#
Since ELAINE 6.2.2 you can bundle single api calls into a bulk call
#>

# TODO [ ] In this example, how to exclude groups where the details call is not successful?

# Create the single API calls
$bulkCalls = [System.Collections.ArrayList]@()
$groups | ForEach-Object {

    $groupId = $_
    $bulkCalls.Add([System.Collections.ArrayList]@(
        "Group"       # objectType : Datafield|Mailing|Group|Segment
        "$( $groupId )"      # objectID
    ))

}

# NOTE THERE IS A MAX OF 100 SINGLE CALLS PER BULK CALL SO BE AWARE OF LOOPING
# FOR TESTING USING A MAX OF 50

# Split everything in chunks if needed and execute
$function = "api_getDetails"
$batchsize = 10
$chunks =  [Math]::Ceiling( $bulkCalls.count / $batchsize )
$groupsDetails2 = [System.Collections.ArrayList]@()
for ( $i = 0 ; $i -lt $chunks ; $i++  ) {
            
    $start = $i*$batchsize
    $remaining = $bulkCalls.Count - $start
    if ($remaining -lt $batchsize) {
        $end = $remaining
    } else {
        $end = $batchsize
    }

    "$( $i ) : $( $start ) : $( $end )"

    $bulkParams = [System.Collections.ArrayList]@()
    $bulkParams.Add( $bulkCalls.GetRange($start, $end) )
    $bulkParams.Add($false) # abortOnError
    
    $restParams = $defaultRestParamsPost + @{
        Uri = "$( $apiRoot )bulk/$( $function )?&response=$( $settings.defaultResponseFormat )"
        Body = "json=$( Format-ELAINE-Parameter $bulkParams )"
    }

    $gt = Invoke-RestMethod @restParams 
    $gt | ft
    if ($gt -ne "" ) {
        $groupsDetails2.AddRange($gt)
    }
}

$groupsDetails2.Count
$groupsDetails2 | ft
$groupsDetails2 | Out-GridView


#-----------------------------------------------
# ARTICLE LIST
#-----------------------------------------------
<#
This one returns the nl_id, nl_name and nl_status
#>

$function = "api_getArticleList"
$jsonInput = @(
    0      # cat_id : Holds the id of the category to show, 0 means no category
    2      # show : 1 means just show parts that are shown in the frontend; 0 means get hidden parts, 2 means get shown and hidden parts
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$articles = Invoke-RestMethod @restParams
$articles | Out-GridView


#-----------------------------------------------
# ARTICLE FOLDERS
#-----------------------------------------------
<#
This one returns the nl_id, nl_name and nl_status
#>

$function = "api_getFolders"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$articlesFolder = Invoke-RestMethod @restParams
$articlesFolder | Out-GridView



exit 0
