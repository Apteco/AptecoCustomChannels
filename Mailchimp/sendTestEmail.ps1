#See https://mailchimp.com/developer/marketing/guides/quick-start/
param([hashtable] $params)

$server = $params['Username'];
$apiKey = $params['Password'];
$messageName = $params['MessageName'];
$testRecipients = $params['TestRecipients'];
$debugFile = $params['DebugFile'];
$scriptRoot = $params['ScriptRoot'];
$templatesFolderName = "Templates"

if ([string]::IsNullOrEmpty($scriptRoot)) {
	$scriptRoot = $PSScriptRoot
}

. "$scriptRoot\common.ps1"

Write-Debug $debugFile "Called sendTestEmail script with parameters" $params

Write-Debug $debugFile "Got test recipients to send to" $testRecipients

#Get the folder id for the "Templates" folder, which is where to the predefined templates should have been created
$templatesFolderId = Get-CampaignFolderIdForName $templatesFolderName
Write-Debug $debugFile "Found campaign folder with id ${templatesFolderId} for name ${templatesFolderName}"

#Get the id of the template campaign to send as a test
$campaignId  = Get-CampaignIdForNameInFolder $templatesFolderId $messageName
Write-Debug $debugFile "Found campaign with id ${campaignId} for name ${messageName} in folder with id ${templatesFolderId}"

if ([string]::IsNullOrEmpty($campaignId)) {
	return null
}

#Create a list of recipient email addresses
$testRecipientsObj = ConvertFrom-Json $testRecipients
$testEmails = [System.Collections.ArrayList]@()
Foreach($testRecipient in $testRecipientsObj) {
	$testEmails.Add($testRecipient.Email)
}

#Trigger a test send of the campaign
$body = [hashtable]@{
	"send_type" = "html"
	"test_emails" = $testEmails
}
$bodyJson = $body | ConvertTo-Json

Write-Debug $debugFile "Sending email test details for campaign ${campaignId}" $bodyJson
$results = Invoke-RestMethod -UseBasicParsing -Method 'Post' -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${campaignId}/actions/test" -Headers @{ "Authorization" = "Bearer: $apiKey" } -Body $bodyJson