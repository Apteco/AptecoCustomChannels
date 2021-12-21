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
        "scriptPath" = "D:\Scripts\alphapictures"
        "TestRecipient" = '{"Email":"florian.von.bracht@apteco.de","Sms":null,"Personalisation":{"line#1":"Hello + %Vorname%","line#2":"Hello World","line#3":"Lorem Ipsum","Kunden ID":"Kunden ID","Anrede":"Anrede","Vorname":"Vorname","Nachname":"Nachname","Communication Key":"9377dd91-a9c2-4595-898a-0cda554bbe82"}}'
        "MessageName" = "542 | 1 | Passenger Boarding Bridge - 1 - "
        "ListName" = "542 | 1 | Passenger Boarding Bridge - 1 - "
        "Password" = "cd"
        "Username" = "ab"
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
$moduleName = "ALPICPREVIEW"
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
# TODO [ ] From PowerShell 7 upwards with Test-JSON we can check if a parameter is a json object and then escape it directly
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
Write-log -message "Loaded '$( $motifs.count )' motifs with '$( $motifs.alternatives.count )' alternatives in total"


#-----------------------------------------------
# CHOOSE THE SELECTED MOTIF ALTERNATIVE
#-----------------------------------------------

$chosenMotifAlternative = [MotifAlternative]::new($params.MessageName)
$motifAlternative = $motifs.alternatives | where { $_.motif.id -eq $chosenMotifAlternative.motif.id -and $_.id -eq $chosenMotifAlternative.id }
Write-log -message "Using the motif '$( $chosenMotifAlternative.motif.id )' - '$( $chosenMotifAlternative.motif.name )' with alternative '$( $chosenMotifAlternative.id )'"


#-----------------------------------------------
# RENDER THE PICTURE
#-----------------------------------------------

$testRecipient = ConvertFrom-Json -InputObject $params.TestRecipient
Write-log -message "Using the testrecipient with the json data '$( ConvertTo-Json -InputObject $testRecipient -Compress -Depth 20 )'"

# Render all lines
Write-log -message "Rendering the lines:"
$lines = [array]@()
$testRecipient.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -like "line#*" } | sort { $_.Name } | ForEach {
    $prop = $_.Name
    $line = $testRecipient.Personalisation.$prop
    # Replace all lines with remaining variables
    $testRecipient.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -notlike "line#*" } | ForEach {
        $token = $_.Name
        $value = $testRecipient.Personalisation.$token
        $line = $line.Replace("%$( $token )%", $value)
    }
    #$testRecipient.Personalisation.$prop
    Write-log -message "    '$( $line )'"
    $lines += $line
} 

$maxLines = ( $motifAlternative.raw.lines | Get-Member -MemberType NoteProperty | select name -Last 1 ).Name
If ( $lines.Count -eq 0 ) {
    $lines += "Max $( $maxLines ) lines. Use line#1, line#2, [...] in Content Step"
}
Write-log -message "There is a maximum of $( $maxLines ) lines in this motif"


$size = $motifAlternative.raw.original_rect -split ", ",4
$width = $size[2]
$height = $size[3]

# Check if sizes were given
$widthInput = @( $testRecipient.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -like "width#" } )
$heightInput = @( $testRecipient.Personalisation | Get-Member -MemberType NoteProperty | where { $_.Name -like "height#" } )

# Find the right size
if ( $widthInput.Count -gt 0 ) {

    # Use the width
    $propName = $widthInput[0].Name
    $inputwidth = $testRecipient.Personalisation.$propName
    $sizes = Calc-Imagesize -sourceWidth $width -sourceHeight $height -targetWidth $inputwidth

} elseif ( $heightInput.Count -gt 0 ) {

    # Use the height
    $propName = $heightInput[0].Name
    $inputheight = $testRecipient.Personalisation.$propName
    $sizes = Calc-Imagesize -sourceWidth $width -sourceHeight $height -targetHeight $inputheight
    
} else {
    
    # Use a default size
    $inputwidth = 1000
    $sizes = Calc-Imagesize -sourceWidth $width -sourceHeight $height -targetWidth $inputwidth
    
}


# Create the picture and load as base64 string
$picBase64 = $motifAlternative.createSinglePicture($lines, $sizes.width, $sizes.height, $true)
Write-log -message "Created the singe picture online"

# Embed the base64 string into html tag
$img = "<img alt=""$( $motifAlternative.motif.name )"" src=""data:image/jpeg;charset=utf-8;base64, $( $picBase64 )"" height=""$( $sizes.height )"" width=""$( $sizes.width )""/>"


#$picString | set-content -Path ".\image.jpg"
#$picBase64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($picString))


#$response = Invoke-WebRequest -Uri "https://www.apteco.de/themes/custom/buildtheme/assets/images/logos/apteco-logo.png" -UseBasicParsing
# From PS 6 onwards, use  bytestream instead: https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.management/set-content?view=powershell-7.2
#set-content -Value $response.content -Path ".\test.png" -Encoding Byte


#-----------------------------------------------
# EMBED HTML INTO BOILERPLATE
#-----------------------------------------------

Write-log -message "Embedding the picture in html code"
$htmlBoilerplate = @"
<!DOCTYPE html>
<!--[if lt IE 7]>      <html class="no-js lt-ie9 lt-ie8 lt-ie7"> <![endif]-->
<!--[if IE 7]>         <html class="no-js lt-ie9 lt-ie8"> <![endif]-->
<!--[if IE 8]>         <html class="no-js lt-ie9"> <![endif]-->
<!--[if gt IE 8]>      <html class="no-js"> <!--<![endif]-->
<html>
    <head>
        <meta charset="utf-8">
        <meta http-equiv="X-UA-Compatible" content="IE=edge">
        <title></title>
        <meta name="description" content="">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <link rel="stylesheet" href="">
    </head>
    <body>
        <!--[if lt IE 7]>
            <p class="browsehappy">You are using an <strong>outdated</strong> browser. Please <a href="#">upgrade your browser</a> to improve your experience.</p>
        <![endif]-->
        #BODY#
        <script src="" async defer></script>
    </body>
</html>
"@

$html = $htmlBoilerplate -replace "#BODY#",$img
#$html | set-content -path ".\test.html"


################################################
#
# RETURN
#
################################################

# TODO [ ] implement subject and more of these things rather than using default values
Write-log -message "Returning the preview html now"

$return = [Hashtable]@{
    "Type" = $settings.preview.Type
    "FromAddress" = $render.headers.from
    "FromName" = $render.headers.fromname
    "Html" = $html #$htmlArr -join "<p>&nbsp;</p>"
    "ReplyTo" = $render.headers.replyto
    "Subject" = $render.headers.subject
    "Text" = $render.bodies.text
}

return $return






