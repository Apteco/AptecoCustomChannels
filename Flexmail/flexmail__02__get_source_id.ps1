
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
	    scriptPath = "D:\Scripts\Flexmail"
        settingsFile = "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\Flexmail\settings.json"
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

Dieses Skript ruft die SourcesID´s ab, welche für den Workflownamen in Flexmail benötigt werden.

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
$moduleName = "FLXSRC"
$processId = [guid]::NewGuid()

if ( $params.settingsFile -ne $null ) {
    # Load settings file from parameters
    $settings = Get-Content -Path "$( $params.settingsFile )" -Encoding UTF8 -Raw | ConvertFrom-Json
} else {
    # Load default settings
    $settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
}

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

#Add-Type -AssemblyName System.Data

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
Write-Log -message "Got a file with these arguments:"
[Environment]::GetCommandLineArgs() | ForEach {
    Write-Log -message "    $( $_ -replace "`r|`n",'' )"
}
# Check if params object exists
if (Get-Variable "params" -Scope Global -ErrorAction SilentlyContinue) {
    $paramsExisting = $true
} else {
    $paramsExisting = $false
}

# Log the params, if existing
if ( $paramsExisting ) {
    Write-Log -message "Got these params object:"
    $params.Keys | ForEach-Object {
        $param = $_
        Write-Log -message "    ""$( $param )"" = ""$( $params[$param] )"""
    }
}


################################################
#
# PROGRAM
#
################################################

#-----------------------------------------------
# LOAD WITH SOAP
#-----------------------------------------------
<#
$sourcesReturn = Invoke-Flexmail -method "GetSources" -responseNode "sources" #| where campaignType -eq Workflow
#>


#-----------------------------------------------
# PREPARE FLEXMAIL REST API
#-----------------------------------------------

Create-Flexmail-Parameters


#-----------------------------------------------
# LOAD WITH REST
#-----------------------------------------------

$limit = 500
$offset = 0
$sourcesReturn = [System.Collections.ArrayList]@()
Do {
    $url = "$( $apiRoot )/sources?limit=$( $limit )&offset=$( $offset )"
    $sourcesResponse = Invoke-RestMethod -Uri $url -Method Get -Headers $script:headers -Verbose -ContentType $contentType
    $offset += $limit
    $sourcesReturn.AddRange( $sourcesResponse )
} while ( $sourcesResponse.count -eq $limit )


#-----------------------------------------------
# BUILD SOURCE OBJECTS
#-----------------------------------------------

$sourcesList = [System.Collections.ArrayList]@()
$sourcesReturn | foreach {

    # Load data
    $source = $_
    #$id = Get-StringHash -inputString $template.url -hashName "MD5" #-uppercase

    # Create mailing objects
    $sourcesList.Add(
        [Source]@{
            sourceId=$source.Id
            sourceName=$source.Name
        }
    )

}

Write-Log -message "Got back $( $sourcesList.count ) sources"


#-----------------------------------------------
# WRAP UP
#-----------------------------------------------

$sources = $sourcesList | Select @{name="id";expression={ $_.sourceId }}, @{name="name";expression={ $_.toString() }} | Sort id



################################################
#
# RETURN
#
################################################

return $sources
