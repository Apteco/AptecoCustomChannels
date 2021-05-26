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
# APPROVED SWITCH
#-----------------------------------------------

$approved = $true

#-----------------------------------------------
# INPUT PARAMETERS, IF DEBUG IS TRUE
#-----------------------------------------------

if ( $debug ) {
    $params = [hashtable]@{
	    scriptPath= "C:\Users\NLethaus\Documents\2021\InxmailFlorian\Inxmail"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://apidocs.inxmail.com/xpro/rest/v1/

#>

################################################
#
# SCRIPT ROOT
#
################################################

# if debug is on a local path by the person that is debugging will load
# else it will use the param (input) path
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
#$libSubfolder = "lib"
$settingsFilename = "settings.json"
$moduleName = "INXGETMAILINGS"

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
$logfile = $settings.logfile
################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

# Load all PowerShell Code
"Loading..."
Get-ChildItem -Path ".\$( $functionsSubfolder )" -Recurse -Include @("*.ps1") | ForEach-Object {
    . $_.FullName
    "... $( $_.FullName )"
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
$auth = "$( Get-SecureToPlaintext -String $settings.login.authenticationHeader )"
$header = @{
    "Authorization" = $auth
}


#-----------------------------------------------
# GET MAILINGS (ALL)
#-----------------------------------------------
# Beginning the log
Write-Log -message "Downloading all mailings"

# Precooked variables for the loop
$i = 0
$p = 5
$messages = $null

if($approved -eq $false){
    
    $totalNumOfMailings = 0
    $numOfMailings = 0
    $object = "mailings"
    
    do{
        # This is the url that is being called as a URL in the browser
        $endpoint = "$( $apiRoot )$( $object )?afterId=$( $i )&pageSize=$( $p )"

        <#
            This contains now all the mailing Information till $p

            https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-mailing-collection
        #>
        $mailings = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType

        # Counting the number of mailings found for the log
        $numOfMailings = $mailings._embedded."inx:mailings".count
        $totalNumOfMailings += $numOfMailings

        Write-Log -message "Found $( $numOfMailings ) mailings"

        # From $mailings we now extract the information we want and adding all mailing-parts to $messages
        $messages += $mailings._embedded."inx:mailings" | Select-Object @{
        # First Coloumn Name we chose as "id" and the expression is the actual value in the hashtable
            name="id";expression={ $_.id }
        }, @{
        # Second Coloumn Name we chose as "name" and the expression returns the id, a / (slash) and the name
            name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )$( $_.name )" }
    }

    $i = $i + $p

    }until($numOfMailings -lt $p)
}


#-----------------------------------------------
# GET MAILINGS (APPROVED)
#-----------------------------------------------

if($approved -eq $true){
    
    $totalNumOfMailingsApproved = 0
    $numOfMailingsApproved = 0  
    $object = "regular-mailings"

    do{
        # This is the url that is being called as a URL in the browser
        $endpoint = "$( $apiRoot )$( $object )?afterId=$( $i )&pageSize=$( $p )&mailingStates=APPROVED"
        <#
            Only retrieving those mailings which have the status APPROVED

            https://apidocs.inxmail.com/xpro/rest/v1/#retrieve-regular-mailing-collection
        #>
        $mailingsApproved = Invoke-RestMethod -Method Get -Uri $endpoint -Header $header -ContentType "application/hal+json" -Verbose

        $numOfMailingsApproved = $mailings._embedded."inx:regular-mailings".count
        $totalNumOfMailingsApproved += $numOfMailingsApproved

        Write-Log -message "Found $( $numOfMailingsApproved ) APPROVED mailings"

        # From $mailings we now extract the information we want and adding all mailing-parts to $messages
        $messages += $mailingsApproved._embedded."inx:regular-mailings" | Select-Object @{
        # First Coloumn Name we chose as "id" and the expression is the actual value in the hashtable
            name="id";expression={ $_.id }
        }, @{
        # Second Coloumn Name we chose as "name" and the expression returns the id, a / (slash) and the name
            name="name";expression={ "$( $_.id )$( $settings.nameConcatChar )$( $_.name )" }
    }

    # Increasing the counter variable $i by $p (how many mails loaded at once)
    $i = $i + $p

    }until($numOfMailingsApproved -lt $p)
}

# Finally we log the $totalNumberOfMailings
Write-Log -message "Found $( $totalNumOfMailings ) mailings"
Write-Log -message "Found $( $totalNumOfMailingsApproved ) APPROVED mailings"


################################################
#
# RETURN
#
################################################

return $messages

