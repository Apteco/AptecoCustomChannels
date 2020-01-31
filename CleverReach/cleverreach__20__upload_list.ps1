
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
	    EmailFieldName= "Email"
	    TransactionType= "Replace"
	    Password= "def"
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns"
	    MessageName= "275324762694 / Test: Smart Campaign Mailing"
	    abc= "def"
	    SmsFieldName= ""
	    Path= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\_dev\EpiServerCampaign\SmartCampaigns\Optivo_Test Apteco_66ce38fd-191a-48b9-885f-eca1bac20803.txt"
	    ReplyToEmail= ""
	    Username= "abc"
	    ReplyToSMS= ""
	    UrnFieldName= "Urn"
	    ListName= "252060"
	    CommunicationKeyFieldName= "Communication Key"
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

TODO [ ] implement more logging

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
$excludedAttributes = $settings.excludedAttributes
$maxWriteCount = 2 # TODO [ ] set this to $settings.rowsPerUpload
$uploadsFolder = $settings.uploadsFolder

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Add assemblies
#Add-Type -AssemblyName System.Data #, System.Text.Encoding

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################

"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tUPLOAD" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}


################################################
#
# PREPARATION & CHECKS
#
################################################

#-----------------------------------------------
# CHECK RESULTS FOLDER
#-----------------------------------------------

if ( !(Test-Path -Path $uploadsFolder) ) {
    New-Item -Path "$( $uploadsFolder )" -ItemType Directory
}


################################################
#
# PROGRAM
#
################################################


<#

if there is no list in the parameters (same name as the message) means an datelist upload, which will create a new list and being filled -> there is a clean script available to delete old lists
if there is a list in the parameters, all receivers are getting deactivated first, then an upsert is taken place, and then the mailing will be released

#>

$uploadMethod = "datelist" # datelist|samegroup


#-----------------------------------------------
# AUTHENTICATION
#-----------------------------------------------

$auth = "Bearer $( Get-SecureToPlaintext -String $settings.login.accesstoken )"
$header = @{
    "Authorization" = $auth
}

$apiRoot = $settings.base



switch ( $uploadMethod ) {

    "datelist" {

        #-----------------------------------------------
        # CREATE NEW LIST WITH TIMESTAMP
        #-----------------------------------------------

        # do something

    }

    "samegroup" {

        #-----------------------------------------------
        # GET GROUP
        #-----------------------------------------------

        $object = "groups"
        $endpoint = "$( $apiRoot )$( $object ).json"
        $res = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header



        #-----------------------------------------------
        # LOAD ACTIVE RECEIVERS AND DEACTIVATE THEM
        #-----------------------------------------------

        $pagesize = 2
        $groups | ForEach { 
            
            $group = $_

            # load stats for active receivers per list -> stats or not refreshed within seconds!
            #$endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/stats"
            #$stats = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header

            # load active receivers
            $receivers = @()
            $page = 0
            Do {
                $endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/receivers?pagesize=$( $pagesize )&detail=0&page=$( $page )"        
                $receivers += Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header
                $page += 1
            } while ( $receivers.Count -eq $pagesize )

            # deactivate receivers
            $pages = [math]::Ceiling( $receivers.Count / $pagesize )    
            if ( $pages -gt 0 ) {
                $update = @()
                0..( $pages - 1 ) | ForEach {
                    $page = $_
                    $skip = $page * $pagesize 
                    $postData = $receivers | select id, @{name="deactivated";expression={ "0" }} -First $pagesize -Skip $skip
                    $body = @{"postdata"=$postData} | ConvertTo-Json
                    $endpoint = "$( $apiRoot )$( $object ).json/$( $group.id )/receivers/update"
                    $update += Invoke-RestMethod -Method Put -Uri $endpoint -Headers $header -Body $body
                }
                $update
            }

            # check again, if there is someone active left
            

        }


    }

}




<#
#-----------------------------------------------
# ATTRIBUTES
#-----------------------------------------------

$listAttributesRaw = Invoke-Epi -webservice "RecipientList" -method "getAttributeNames" -param @(@{value=$settings.masterListId;datatype="long"},@{value="en";datatype="String"}) -useSessionId $true
$listAttributes = $listAttributesRaw | where { $_ -notin $excludedAttributes }


#-----------------------------------------------
# DATA MAPPING
#-----------------------------------------------

#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tStart to create a new file" >> $logfile
$fileItem = Get-Item -Path $params.Path

$exportId = Split-File -inputPath $fileItem.FullName -header $true -writeHeader $true -inputDelimiter "`t" -outputDelimiter "`t" -outputColumns $listAttributes -writeCount $maxWriteCount -outputDoubleQuotes $false -outputPath $uploadsFolder

#"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tDone with export id $( $exportId )!" >> $logfile
#>



#-----------------------------------------------
# IMPORT RECIPIENTS
#-----------------------------------------------

$importResults = 0
Get-ChildItem -Path "$( $uploadsFolder )\$( $exportId )" | ForEach {

    $f = $_
    
    $csv = Get-Content -Path "$( $f.FullName )" -Encoding UTF8 
    
    # do something with the data
    # to set receivers active, do something like:
    <#
    { "postdata":[
        {"id"="5","deactivated"="0"},{"id"="119","deactivated"="0"}
    ]}
    #>

    # call cleverreach
    # use upsert
    # POST /v3/groups.json/{group_id}/receivers/upsert
    
} 


################################################
#
# RETURN VALUES TO PEOPLESTAGE
#
################################################

# count the number of successful upload rows
$recipients = $importResults

# put in the source id as the listname
$transactionId = $waveId

# return object
$return = [Hashtable]@{
    "Recipients"=$recipients
    "TransactionId"=$transactionId
}

# return the results
$return

