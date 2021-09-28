
################################################
#
# NOTES
#
################################################

<#

Execute this script only with the user that will run the scheduled task for the response download

#>

################################################
#
# SCRIPT ROOT
#
################################################

# Load scriptpath
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript") {
    $scriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
} else {
    $scriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0])
}


Set-Location -Path $scriptPath


################################################
#
# CREATE ENCRYPTION KEYS
#
################################################

# create encryption keys
$cspParams = New-Object "System.Security.Cryptography.CspParameters"
$cspParams.KeyContainerName = "XML_ENC_RSA_KEY"
$rsaKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspParams)

################################################
#
# FILES
#
################################################

# TODO [ ] Implement file chooser

# settings
$inputfile = "<inputfile>" # the original file which will be replaced with the encrypted file
$outputfile = "<outputfile>" # the temporary file which should be used to be referenced on


################################################
#
# SETTINGS
#
################################################

$settings = @{
    keyContainerName = $cspParams.KeyContainerName
    keyName = "rsaKey"
    elementsToEncrypt = @("Password", "ConnectionString","PeopleStageConnectionString")
    keySize = 256
    inputConfig = $inputfile
    outputConfig = $outputfile
    logfile = "$( $scriptPath )\epi_response_encryption.log"
}


################################################
#
# PACK TOGETHER SETTINGS AND SAVE AS JSON
#
################################################

# create json object
$json = $settings | ConvertTo-Json -Depth 8 # -compress

# print settings to console
$json

# save settings to file
$json | Set-Content -path "$( $scriptPath )\settings.json" -Encoding UTF8

