<#

Reference: 
https://docs.microsoft.com/de-de/dotnet/standard/security/how-to-encrypt-xml-elements-with-symmetric-keys
https://social.msdn.microsoft.com/Forums/de-DE/a7732f36-ae89-471d-b5de-af84b2d14cca/problem-beim-entschlsseln-von-xml-elementen


#>


################################################
#
# PATH
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
# SETTINGS
#
################################################

# Load settings
$settings = Get-Content -Path "$( $scriptPath )\settings.json" -Encoding UTF8 -Raw | ConvertFrom-Json

# settings
$outputfile = $settings.inputConfig
$outputfile2 = $settings.outputConfig




################################################
#
# FUNCTIONS / ASSEMBLIES
#
################################################

# load assemblies
Add-Type -AssemblyName "System.Security"


################################################
#
# ENCRYPTION KEYS
#
################################################

# create encryption keys
$cspParams = New-Object "System.Security.Cryptography.CspParameters"
$cspParams.KeyContainerName = $settings.keyContainerName
$rsaKey = [System.Security.Cryptography.RSACryptoServiceProvider]::new($cspParams)
$keyName = $settings.keyName


################################################
#
# DECRYPT XML PARTS
#
################################################

# load xml file
$xml = New-Object "xml"
$xml.PreserveWhitespace
$xml.Load($outputfile)

# decrypt encrypted parts
$eXml = [System.Security.Cryptography.Xml.EncryptedXml]::new($xml)
$eXml.AddKeyNameMapping($keyName, $rsaKey)
$eXml.DecryptDocument();

# save xml file
$xml.Save("$( $outputfile2 )")


