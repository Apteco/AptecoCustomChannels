#See https://mailchimp.com/developer/marketing/guides/quick-start/
param([hashtable] $params)

$server = $params['Username'];
$apiKey = $params['Password'];
$debugFile = $params['DebugFile'];
$scriptRoot = $params['ScriptRoot'];
$templatesFolderName = "Templates"

if ([string]::IsNullOrEmpty($scriptRoot)) {
	$scriptRoot = $PSScriptRoot
}

. "$scriptRoot\common.ps1"

Write-Debug $debugFile "Called getTemplates script with parameters" $params

#Get the folder id for the "Templates" folder, which is where to the predefined templates should have been created
$templatesFolderId = Get-CampaignFolderIdForName $templatesFolderName
Write-Debug $debugFile "Found campaign folder with id ${templatesFolderId} for name ${templatesFolderName}"

#Get all the template campaigns in this folder
$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/campaigns?count=1000" -Headers @{ "Authorization" = "Bearer: $apiKey" }
Write-Debug $debugFile "Campaigns list" $results

$campaigns = $results.campaigns

#Create a list of objects containing campaign id and name to return
$templateDetails = [System.Collections.ArrayList]@()
Foreach($campaign in $campaigns) {
	$id = $campaign.id;
	$name = $campaign.settings.title;
	$folderId = $campaign.settings.folder_id;
	If ($folderId -eq $templatesFolderId) {
		$templateDetails += Select-Object @{n='id';e={$id}},@{n='name';e={$name}} -InputObject ''
	}
}
return $templateDetails;