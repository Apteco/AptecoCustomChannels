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
    }
}

################################################
#
# NOTES
#
################################################

<#

https://github.com/Syniverse/QuickStart-BatchNumberLookup-Python/blob/master/ABA-example-external.py

FILEUPLOAD UP TO 2 GB allowed

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
$moduleName = "SYNSMSREPORT"
$processId = [guid]::NewGuid()
$timestamp = [datetime]::Now.ToString("yyyyMMddHHmmss")

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

# append a suffix, if in debug mode
if ( $debug ) {
    $logfile = "$( $logfile ).debug"
}


################################################
#
# FUNCTIONS & ASSEMBLIES
#
################################################

#Add-Type -AssemblyName System.Data #, System.Web  #, System.Text.Encoding

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
Write-Log -message "$( $moduleName )"
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
        Write-Log -message "    $( $param )= ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################


#-----------------------------------------------
# PREPARE HEADERS
#-----------------------------------------------

$headers = @{
    "Authorization"= "Bearer $( Get-SecureToPlaintext -String $settings.authentication.accessToken )"
}

$contentType = "application/json; charset=utf-8"


#-----------------------------------------------
# DEBUG SWITCH
#-----------------------------------------------


# types: SMS, MMS, PSH, FB
$results = [System.Collections.ArrayList]@()
$limit = 100
$offset = 0

# The result includes 50 entries per call
Do {
    
    $url = "$( $settings.base )scg-external-api/api/v1/messaging/messages?offset=$( $offset )&type=SMS&limit=$( $limit )&sort=created_date"# &created_date=[2020-05-31T22:00:00.000Z,2021-06-11T14:31:59.000Z]"

    try {

        $paramsPost = [Hashtable]@{
            Uri = $url
            Method = "Get"
            Headers = $headers
            Verbose = $true
            ContentType = $contentType
        }

        "$( $paramsPost.uri )"

        $res = Invoke-RestMethod @paramsPost
        $results.AddRange($res.list)

    } catch {

        $e = ParseErrorForResponseBody -err $_
        Write-Log -message $e

    }

    $offset += $res.limit


} until ( $offset -ge $res.total )




#Write-Log -message "Just forwarding parameters to broadcast"

$results | select *, @{name="fragments_count";expression={ $_.fragments_info.count }} | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`n",' ' } | Out-File ".\$( $timestamp )_$( $processId.Guid )_messages.csv" -Encoding utf8
$results | select id -ExpandProperty fragments_info | ConvertTo-Csv -NoTypeInformation -Delimiter "`t" | % { $_ -replace "`n",' ' } | Out-File ".\$( $timestamp )_$( $processId.Guid )_fragments.csv" -Encoding utf8