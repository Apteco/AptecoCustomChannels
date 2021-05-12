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
	    scriptPath= "C:\Users\Florian\Documents\GitHub\AptecoCustomChannels\alphapictures"
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
$moduleName = "ALPICGM"
$processId = [guid]::NewGuid()

# Load settings
# TODO [ ] put settings into file
#$settings = Get-Content -Path "$( $scriptPath )\$( $settingsFilename )" -Encoding UTF8 -Raw | ConvertFrom-Json
$settings = @{
    
    base = "https://v4.alphapicture.com/"
    
    changeTLS = $true
    nameConcatChar = " | "
    logfile = ".\alpha.log"

    login = @{
    }

    upload = @{
        defaultUseWatermark = $false
    }

    download = @{
        waitSecondsLoop = 10
    }

    preview = @{
        "Type" = "Email" #Email|Sms
        #"FromAddress"="info@apteco.de"
        #"FromName"="Apteco"
        "ReplyTo"="info@apteco.de"
        #"Subject"="Test-Subject"
    }

}


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
# PREPARE ALPHAPICTURES OBJECT
#-----------------------------------------------

#$stringSecure = ConvertTo-SecureString -String ( Get-SecureToPlaintext $settings.login.password ) -AsPlainText -Force
# TODO [ ] create secured password
$stringSecure = ConvertTo-SecureString -String $settings.login.password -AsPlainText -Force
$cred = [pscredential]::new( $settings.login.account, $stringSecure )

# Create alphapictures object
$alpha = [AlphaPictures]::new($cred,$settings.base)


#-----------------------------------------------
# GET MOTIFS
#-----------------------------------------------

$motifs = $alpha.getMotifs()


#-----------------------------------------------
# BUILD MAILING OBJECTS
#-----------------------------------------------

#$messages = $motifs | Select @{name="id";expression={ $_.id }}, @{name="name";expression={ $_.toString() }}

# Use alternatives as one motif has multiple ones
$messages = $motifs.alternatives | Select @{name="id";expression={ "$( $_.motif.id )#$( $_.id ) " }}, @{name="name";expression={ $_.toString() }}


################################################
#
# RETURN
#
################################################

# real messages
return $messages

