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

# TODO [ ] CHECK USE OF api_userParseText ( string $text = '' , int $p_id ) 

#>

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

# Lookup a specific error code
#($errorCodes | gm -MemberType NoteProperty | where { $_.Name -eq "-18"  }).Definition.split("=")[1]


#-----------------------------------------------
# ELAINE VERSION
#-----------------------------------------------
<#
This call should be made at the beginning of every script to be sure the version is filled (and the connection could be made)
#>

$function = "api_getElaineVersion"
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?p1=false&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}

#$res = Invoke-RestMethod -Uri $url -Method get -Verbose -Headers $headers -ContentType $contentType
$elaineVersion = Invoke-RestMethod @restParams

# Use this function to check if a mininum version is needed to call the function
Check-ELAINE-Version -minVersion "6.2.2"


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
$mailingsMethod1 = Invoke-RestMethod @restParams
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
Transactional Mailings and Automation Mails (subscribe, unsubscribe, etc.) have the status "actionmail", the normal mailings have "ready"
#>

$function = "api_getMessageInfo"
$jsonInput = @(
    ""      # message_name : string
    "actionmail" # message_status : on_hold|actionmail|ready|clearing|not_started|finished|processing|paused|aborted|failed|queued|scheduled|pending|sampling|deleted -> an empty string means all status
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$mailingsMethod2 = Invoke-RestMethod @restParams
#$mailingsMethod2 | Out-GridView


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
# GET ALL GROUPS DETAILS METHOD 1 - VIA SINGLE CALLS
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
# EXIT
#-----------------------------------------------

exit 0


################################################
#
# EXECUTE EVERY PART BELOW SELECTIVELY IF NEEDED
#
################################################


#-----------------------------------------------
# GET ALL GROUPS DETAILS METHOD 2 - VIA BULK
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
# GET USER ID BY HASH
#-----------------------------------------------

$function = "api_getUserId"
$jsonInput = @(
    "florian.von.bracht@apteco.de"      # array $data
    ""      # array $keys = array() 
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$userByHash = Invoke-RestMethod @restParams
$userByHash
# TODO [ ] Needs testing


#-----------------------------------------------
# GET USER ID BY EMAIL
#-----------------------------------------------

$function = "api_getUserIdByEmail"
$jsonInput = @(
    "testuser@example.tld"      # string email
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$userByEmail = Invoke-RestMethod @restParams
$userByEmail


#-----------------------------------------------
# GET USER DETAILS
#-----------------------------------------------

$function = "api_getUser"
$jsonInput = @(
    [int]$userByEmail      # int $elaine_id
    0 # int $group
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$userDetails = Invoke-RestMethod @restParams
$userDetails


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
# ARTICLE DETAILS
#-----------------------------------------------

$function = "api_getArticleDetails"
$jsonInput = @(
    0      # int $part_id 
) 
$restParams = $defaultRestParams + @{
    Uri = "$( $apiRoot )$( $function )?json=$( Format-ELAINE-Parameter $jsonInput )&response=$( $settings.defaultResponseFormat )"
    Method = "Get"
}
$articleDetail = Invoke-RestMethod @restParams
$articleDetail | Out-GridView

# TODO [ ] Needs testing


#-----------------------------------------------
# GET IMPORT STATUS
#-----------------------------------------------

$function = "api_getImportStatus"
$jsonInput = @(
    ""      # string $filename
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$importStatus = Invoke-RestMethod @restParams
$importStatus

# TODO [ ] Needs testing


#-----------------------------------------------
# SEND SINGLE
#-----------------------------------------------
<#
Send a message to a known user in ELAINE
Recipients on black and bounce lists are automatically excluded
BULK: Only possible for one mailing id and abortOnError will be ignored -> Either the whole call will be send out or not
#>

$function = "api_sendSingle"
$jsonInput = @(
    ""      # int $nl_id                        Mailing
    ""      # int $p_id                         User
    ""      # int $ev_id                        Group
    ""      # int $priority : null
    ""      # int $variant_position : null      Variant, e.g. with language templates
    ""      # string $type : normal
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$send = Invoke-RestMethod @restParams
$send

# TODO [ ] Needs testing


#-----------------------------------------------
# SEND SINGLE TRANSACTIONAL
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
Recipients on black and bounce lists are NOT automatically excluded, but this can be controlled via the blacklist parameter
BULK: Additionally to the non-bulk mode, the bulk mechanism uses the bounce list; Only possible for one mailing id and abortOnError will be ignored -> Either the whole call will be send out or not
#>

# Choose the right parameters
$selectedMailing = $mailingsMethod2 | Out-GridView -PassThru
#$selectedGroup = $groupDetailsFiltered | Out-GridView -PassThru
$selectedGroup = [System.Collections.ArrayList]@("")
$variant = "" # TODO [ ] check if you can read the variants of a mailing

# Create the upload data object
$dataArr = [ordered]@{
    "content" = [ordered]@{
        "c_urn"             = "414596"
        "c_email"          = "test@example.tld"
        #"t_subject"        = "Test-Betreff"
        #"t_sendername"     = "Apteco GmbH"
        #"t_sender"         = "info@apteco.de"
        #"t_replyto" $       = "antwort@example.tld"
        #"t_cc"             = "cc_empfaenger@example.tld"
        #"t_bcc"            = "bcc_empfaenger@example.tld"
        #"t_attachment"     = @()
        #"t_textcontent"    = "Text-Inhalt"
        #"t_htmlcontent"    = "HTML-Inhalt"
        #"t_xxx"            = "Hello World"
    }
    #"priority" = 99                 # 99 is default value, 100 is for emergency mails           
    #"override" = $false             # overwrite array data with profile data
    #"update_profile" = $false       # update existing contacts with array data
    #"msgid" = [guid]::NewGuid()     # External message id / for identifying
    #"notify_url" = ""              # notification url if bounced, e.g. like "http://notifiysystem.de?email=[c_email]"
}

$function = "api_sendSingleTransaction"
$jsonInput = @(
    $dataArr      # array $data = null                    Recipient data
    [int]$selectedMailing[0].nl_id       # int $nl_id                            Mailing
    #"" #$selectedGroup[0].ev_id         # int $ev_id                            Group is optional
    #"" # $variant      # int $variant_position : null
    #$false      # boolean|integer $blacklist : true     false means the blacklist will be ignored, a group id can also be passed and then used as an exclusion list
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )"# ?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$send = Invoke-RestMethod @restParams
$send 

# TODO [x] Needs testing
# TODO [ ] Add BULK and Single lookup the the settings creation or make id dependent on the version


#-----------------------------------------------
# GET TRANSACTIONAL MAILING STATUS
#-----------------------------------------------

$function = "api_getTransactionMailStatus"
$jsonInput = @(
    [int]$send      # int $id
    $false          # bool $is_msgid -> true if the id is an external message id

) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$transactionalStatus = Invoke-RestMethod @restParams
$transactionalStatus

# status can be "sent" or "queued"
# TODO [x] Needs testing


#-----------------------------------------------
# RENDER MAILING
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
#>

$function = "api_mailingRender"
$jsonInput = @(
    ""      # int $elaine_id
    ""      # int $mailing_id
    ""      # array $userdata = array() 
    ""      # int $group
    ""      # bool $preview = false
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$render = Invoke-RestMethod @restParams
$render

# TODO [ ] Needs testing


#-----------------------------------------------
# TEST SEND
#-----------------------------------------------
<#
Upload an array in the api call and send email directly
#>

$function = "api_mailingTestsend"
$jsonInput = @(
    ""      # int $nl_id
    ""      # int $ev_id
) 
$restParams = $defaultRestParamsPost + @{
    Uri = "$( $apiRoot )$( $function )?&response=$( $settings.defaultResponseFormat )"
    Body = "json=$( Format-ELAINE-Parameter $jsonInput )"
}
$testsend = Invoke-RestMethod @restParams
$testsend

# TODO [ ] Needs testing






