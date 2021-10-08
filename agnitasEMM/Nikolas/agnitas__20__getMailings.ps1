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
	    scriptPath= "C:\Users\NLethaus\Documents\GitHub\Agnitas-EMM"
    }
}


################################################
#
# NOTES
#
################################################

<#

https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings

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

$script:moduleName = "AGNITAS-GET-MAILINGS"

# Load general settings
. ".\bin\general_settings.ps1"

# Load settings
. ".\bin\load_settings.ps1"

# Load network settings
. ".\bin\load_networksettings.ps1"

# Load prepartation ($cred)
. ".\bin\preparation.ps1"

# Load functions
. ".\bin\load_functions.ps1"

# Start logging
. ".\bin\startup_logging.ps1"


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

$messages = [System.Collections.ArrayList]@()
$messages = $null

#-----------------------------------------------
# GET MAILINGS (ALL)
#-----------------------------------------------
# Beginning the log
Write-Log -message "Downloading all mailings"


$endpoint = "$( $apiRoot )/mailing"
try {
    <#
    https://emm.agnitas.de/manual/en/pdf/EMM_Restful_Documentation.html#api-Mailing-getMailings
    #>
    $invoke = Invoke-RestMethod -Method Get -Uri $endpoint -Headers $header -Verbose -ContentType $contentType
    

}
catch {
    Write-Host "ERROR - StatusCode:" $_.Exception.Response.StatusCode.value__ 
    Write-Host "ERROR - StatusDescription:" $_.Exception.Response.StatusDescription
}
  
# Return only the mailings which have type = normal
$return = New-Object System.Collections.Generic.List[System.Object]
foreach($mailing in $invoke){
    if($mailing.type -eq "NORMAL"){
       $return.Add($mailing)
    }
} 

################################################
#
# RETURN
#
################################################

return $return

