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
	    scriptPath= "C:\Apteco\Integration\MSSQL"
	    MessageName = "1 | Novize"
	    ListName = "1 | Novize"
        Password = "def"
		Username = "abc"
		database="dev"
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
$settingsFilename = "settings.json"

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$logfile = $settings.logfile


################################################
#
# FUNCTIONS
#
################################################

Add-Type -AssemblyName System.Data

Get-ChildItem -Path ".\$( $functionsSubfolder )" | ForEach {
    . $_.FullName
}


################################################
#
# LOG INPUT PARAMETERS
#
################################################


"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t----------------------------------------------------" >> $logfile
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tBROADCAST" >> $logfile
"$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`tGot a file with these arguments: $( [Environment]::GetCommandLineArgs() )" >> $logfile
$params.Keys | ForEach {
    $param = $_
    "$( [datetime]::Now.ToString("yyyyMMddHHmmss") )`t $( $param ): $( $params[$param] )" >> $logfile
}


################################################
#
# FINISH
#
################################################

# log 
"$( [datetime]::UtcNow.ToString("yyyyMMddHHmmss") )`tDone with Broadcast!" >> $logfile


#-----------------------------------------------
# RETURN VALUES TO PEOPLESTAGE
#-----------------------------------------------

# TODO [ ] implement this part

<#
$recipients = $changedLevel | where { $_.ReturnValueFromDatabase -eq 0} | Select Urn

[Hashtable]$return = @{
    "Recipients"=$recipients
    "TransactionId"=$updateId
}

$return
#>