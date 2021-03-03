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
	    scriptPath= "D:\Scripts\TriggerDialog\v2"
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

Good hints on PowerShell Classes and inheritance

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
$processId = [guid]::NewGuid()
$modulename = "TRGETMESSAGES"
$timestamp = [datetime]::Now

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json

# Allow only newer security protocols
# hints: https://www.frankysweb.de/powershell-es-konnte-kein-geschuetzter-ssltls-kanal-erstellt-werden/
if ( $settings.changeTLS ) {
    $AllProtocols = @(    
        [System.Net.SecurityProtocolType]::Tls12
    )
    [System.Net.ServicePointManager]::SecurityProtocol = $AllProtocols
}

# Log
$logfile = $settings.logfile

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}



################################################
#
# FUNCTIONS AND ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach {
    . $_.FullName
    "... $( $_.FullName )"
}

Add-Type -AssemblyName System.Security


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
# PROCESS
#
################################################


#-----------------------------------------------
# CREATE HEADERS
#-----------------------------------------------

[uint64]$currentTimestamp = Get-Unixtime -timestamp $timestamp

# It is important to use the charset=utf-8 to get the correct encoding back
$contentType = $settings.contentType
$headers = @{
    "accept" = $settings.contentType
}


#-----------------------------------------------
# CREATE SESSION
#-----------------------------------------------

Get-TriggerDialogSession
#$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret $settings.authentication.authenticationSecret
$jwtDecoded = Decode-JWT -token ( Get-SecureToPlaintext -String $Script:sessionId ) -secret ( Get-SecureToPlaintext $settings.authentication.authenticationSecret )

$headers.add("Authorization", "Bearer $( Get-SecureToPlaintext -String $Script:sessionId )")


#-----------------------------------------------
# CHOOSE CUSTOMER ACCOUNT
#-----------------------------------------------

# Choose first customer account first
$customerId = $settings.customerId


#-----------------------------------------------
# CREATE A SUBCLASS FOR MAILINGS
#-----------------------------------------------

# TODO [x] put the subclasses in other source files
# TODO [/] we need to filter on activated campaigns/mailings


#-----------------------------------------------
# READ CAMPAIGN DETAILS
#-----------------------------------------------

<#

   id createdOn                changedOn                version campaignType campaignName        actions        campaignState
   -- ---------                ---------                ------- ------------ ------------        -------        -------------
41126 2020-12-22T13:23:47.000Z 2021-03-03T12:33:50.000Z       6 LONG_TERM    2020-12-22_14:23:46 {}             @{id=120; label=Aktiv}
41125 2020-12-21T23:36:53.000Z                                1 LONG_TERM    2020-12-22_00:36:52 {EDIT, DELETE} @{id=110; label=Entwurf}
47959 2021-03-01T17:30:26.000Z 2021-03-01T17:33:16.000Z       6 LONG_TERM    2021-03-01_18:30:26 {}             @{id=120; label=Aktiv}
34362 2020-09-30T22:26:48.000Z 2021-03-01T13:20:26.000Z       8 LONG_TERM    Kampagne A          {}             @{id=120; label=Aktiv}

#>

# TODO [ ] implement paging for campaigns
$campaignDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/longtermcampaigns?customerId=$( $customerId )" -Verbose -Headers $headers -ContentType $contentType #-Body $bodyJson
<#

# ready to be edited
$campaignDetails.elements | where {$_.actions -contains "EDIT"}
$campaignDetails.elements | where {$_.campaignState.id -eq 110} # State "Entwurf"
$campaignDetails.elements | where {$_.campaignState.id -eq 120} # State "Aktiv"
$campaignDetails.elements | where {$_.campaignState.id -eq 125} # State "Paused"


# ready to delete
$campaignDetails.elements | where {$_.actions -contains "DELETE"}


#>

#-----------------------------------------------
# GET MAILINGS / CAMPAIGNS DETAILS
#-----------------------------------------------

<#

   id createdOn                changedOn                version campaignId variableDefVersion senderAddress mailingTemplateType                               addressMappingsConfirmed hasIndividualVariables
   -- ---------                ---------                ------- ---------- ------------------ ------------- -------------------                               ------------------------ ----------------------
29591 2020-10-01T13:32:02.000Z                                1      34363                  0                                                                                     True                  False
30449 2020-10-09T15:57:26.000Z 2021-03-01T12:57:36.000Z       8      34362                  4               @{mailingTemplateTypeId=230; editorType=ADVANCED}                     True                   True
36028 2020-12-21T21:53:45.000Z                                1      34372                  0                                                                                     True                  False
36064 2020-12-21T22:34:15.000Z                                1      41043                  0                                                                                     True                  False
36145 2020-12-21T23:36:53.000Z                                1      41125                  0                                                                                     True                  False
36146 2020-12-22T13:23:47.000Z 2021-03-03T12:33:17.000Z      18      41126                  8               @{mailingTemplateTypeId=110; editorType=BASIC}                        True                   True
42855 2021-03-01T17:30:27.000Z 2021-03-01T17:32:57.000Z       7      47959                  3               @{mailingTemplateTypeId=120; editorType=BASIC}                        True                   True

#>

# TODO [ ] implement paging for mailings
$mailingDetails = Invoke-RestMethod -Method Get -Uri "$( $settings.base )/mailings?customerId=$( $customerId )" -Headers $headers -ContentType $contentType -Verbose


#-----------------------------------------------
# BUILD MAILING OBJECTS
#-----------------------------------------------

$mailings = @()
$mailingDetails.elements | foreach {

    # Load data
    $mailing = $_
    $campaign = $campaignDetails.elements.where({ $_.id -eq $mailing.campaignId })

    # Show only if mailing has a corresponding campaign

    if ( $campaign.count -gt 0 ) {

        # Add an entry for each possible action
        if ( $campaign.actions.count -gt 0 ) { 
            $campaign.actions | ForEach {
                $action = $_
                $mailings += [TriggerDialogMailing]@{
                    mailingId=$mailing.id
                    campaignId=$campaign.id
                    campaignName=$campaign.campaignName
                    campaignState=$campaign.campaignState.label
                    campaignOperation=$action
                }
            }
        # Add entry without an action like campaigns in state paused or live
        } else {

            # Create mailing objects
            $mailings += [TriggerDialogMailing]@{
                mailingId=$mailing.id
                campaignId=$campaign.id
                campaignName=$campaign.campaignName
                campaignState=$campaign.campaignState.label
                campaignOperation="UPLOAD"
            }

            # Create mailing objects
            $mailings += [TriggerDialogMailing]@{
                mailingId=$mailing.id
                campaignId=$campaign.id
                campaignName=$campaign.campaignName
                campaignState=$campaign.campaignState.label
                campaignOperation="PAUSE"
            }
        }

    }


}

# Add an entry for a new campaign
$mailings += [TriggerDialogMailing]@{
    mailingId=0
    campaignId=0
    campaignName="New Campaign + Mailing"
    campaignState="New"
    campaignOperation="CREATE"
}

# Add an entry for all campaigns without a mailing
#$campaignDetails.elements | where { $_.id -notin $mailings.campaignId } | foreach {
#    $campaign = $_
#    $mailings += [TriggerDialogMailing]@{mailingId=0;campaignId=$campaign.id;campaignName="$( $campaign.campaignName ) - new Mailing"}
#}



$messages = $mailings | Select @{name="id";expression={ $_.mailingId }}, @{name="name";expression={ $_.toString() }}

################################################
#
# RETURN
#
################################################



# real messages
return $messages

