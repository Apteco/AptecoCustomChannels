param([hashtable] $params)

$server = $params['Username'];
$apiKey = $params['Password'];
$debugFile = $params['DebugFile'];
$scriptRoot = $params['ScriptRoot'];

if ([string]::IsNullOrEmpty($scriptRoot)) {
	$scriptRoot = $PSScriptRoot
}

. "$scriptRoot\common.ps1"

Write-Debug $debugFile "Called test script with parameters" $params

#Call the Mailchimp ping endpoint to check that the given credentials are correct
#See https://mailchimp.com/developer/marketing/guides/quick-start/
$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/ping" -Headers @{ "Authorization" = "Bearer: $apiKey" }
Write-Debug $debugFile "Ping results" $results
return 0