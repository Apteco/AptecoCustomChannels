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

if ( $debug ) {
    $params = [hashtable]@{
        "scriptPath" = "D:\Scripts\ELAINE\Transactional"
        "TestRecipient"= '{"Email":"florian.von.bracht@apteco.de","Sms":null,"Personalisation":{"voucher_1":"voucher no 1","voucher_2":"voucher no 2","voucher_3":"voucher no 3","Kunden ID":"Kunden ID","title":"title","name":"name","surname":"surname","language":"language","Communication Key":"e48c3fd3-7317-4637-aeac-4fa1505273ac"}}'
        "MessageName"= "1875 / Apteco PeopleStage Training Automation"
        "ListName"= "" #1935 / FERGETestInitialList-20210120-100246
        "Password"= "def"
        "Username"= "abc"  
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
$moduleName = "ELNPREVIEW"
$processId = [guid]::NewGuid()

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

# more settings
$logfile = $settings.logfile
#$guid = ([guid]::NewGuid()).Guid # TODO [ ] use this guid for a specific identifier of this job in the logfiles

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS
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
        Write-Log -message "$( $param ): $( $params[$param] )"
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# PREPARE CALLING ELAINE
#-----------------------------------------------

Create-ELAINE-Parameters


#-----------------------------------------------
# PARSE MAILING AND LOAD DETAILS
#-----------------------------------------------

<#

mailingId mailingName
--------- -----------
1875      Apteco PeopleStage Training Automation

#>
$mailing = [Mailing]::New($params.MessageName)

# Load details from ELAINE to check if it still exists
$mailingDetails = Invoke-ELAINE -function "api_getDetails" -parameters @("Mailing",[int]$mailing.mailingId)
if ( $mailingDetails.status_data.is_transactionmail ) {
    Write-Log -message "Mailing is confirmed as a transactional mailing"
} else {
    Write-Log -message "Mailing is no transactional mailing"
    throw [System.IO.InvalidDataException] "Mailing is no transactional mailing"
}


#-----------------------------------------------
# PARSE GROUP AND LOAD DETAILS
#-----------------------------------------------
<#
# TODO [ ] Activate group dependent features
$group = [Group]::New($params.ListName)

# Load details from ELAINE to check if it still exists
$groupDetails = Invoke-ELAINE -function "api_getDetails" -parameters @("Group",[int]$group.groupId)
#>


#-----------------------------------------------
# LOAD FIELDS
#-----------------------------------------------

# TODO [ ] Loading only C fields or think of group dependent fields, too?
$fields = Invoke-ELAINE -function "api_getDatafields"
#$fields | Out-GridView

<#
# Load group fields
# TODO [ ] Activate group dependent features
$fields += Invoke-ELAINE -function "api_getDatafields" -parameters @([int]$group.groupId)
#>

Write-Log -message "Loaded fields $( $fields.f_name -join ", " )"


#-----------------------------------------------
# LOAD INPUT DATA
#-----------------------------------------------

$testrecipient = $params.TestRecipient | ConvertFrom-Json


#-----------------------------------------------
# LOAD ELAINE ID BY EMAIL
#-----------------------------------------------

$jsonInput = @(
    $testrecipient.Email      # array $data
) 
$userId = Invoke-ELAINE -function "api_getUserIdByEmail" -method Post -parameters $jsonInput


#-----------------------------------------------
# LOAD ELAINE ID BY EMAIL HASH
#-----------------------------------------------
<#
# TODO [ ] Not sure which HASH Method is used here
$hash = Get-StringHash -inputString "florian.von.bracht@apteco.de" -hashName "SHA256" #-uppercase $true
$jsonInput = @(
    $hash      # array $data
) 
$userId = Invoke-ELAINE -function "api_getUserIdByHash" -method Post -parameters $jsonInput
#>


#-----------------------------------------------
# LOAD ELAINE ID BY EXTERNAL ID
#-----------------------------------------------
<#
$jsonInput = @(
    "9999999"      # int $ext_id
) 
$userId = Invoke-ELAINE -function "api_getUserIdByExtID" -method Post -parameters $jsonInput
$userId
#>


#-----------------------------------------------
# LOAD ELAINE ID BY FIELD - e.g. URN
#-----------------------------------------------
<#
$jsonInput = @(
    $settings.upload.urnColumn      # string $name
    "9999999"      # string $value
) 
$userId = Invoke-ELAINE -function "api_getUserIdByProfilefield" -method Post -parameters $jsonInput
$userId
#>


#-----------------------------------------------
# GET USER DETAILS
#-----------------------------------------------

$jsonInput = @(
    $userId      # int $elaine_id
    ""      # int $group # TODO [ ] implement group dependency
) 
$userDetails = Invoke-ELAINE -function "api_getUser" -method Post -parameters $jsonInput


#-----------------------------------------------
# RENDER EMAIL
#-----------------------------------------------

# TODO [ ] implement group usage
$jsonInput = @(
    $userDetails.p_id      # int $elaine_id # TODO [ ] Check if this can be left out
    $mailingDetails.nl_id      # int $mailing_id
    ""      # array $userdata = array() optional
    ""      # int $group optional
    $false      # bool $preview = false
) 

$render = Invoke-ELAINE -function "api_mailingRender" -method Post -parameters $jsonInput


################################################
#
# RETURN
#
################################################

# TODO [ ] implement subject and more of these things rather than using default values

$return = [Hashtable]@{
    "Type" = $settings.preview.Type
    "FromAddress" = $render.headers.from
    "FromName" = $render.headers.fromname
    "Html" = $render.bodies.html #$htmlArr -join "<p>&nbsp;</p>"
    "ReplyTo" = $render.headers.replyto
    "Subject" = $render.headers.subject
    "Text" = $render.bodies.text
}

return $return






