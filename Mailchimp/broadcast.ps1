#See https://mailchimp.com/developer/marketing/guides/quick-start/
param([hashtable] $params)

$server = $params['Username'];
$apiKey = $params['Password'];
$messageName = $params['MessageName'];
$listName = $params['ListName'];
$transactionId = $params['TransactionId'];
$debugFile = $params['DebugFile'];
$scriptRoot = $params['ScriptRoot'];
$templatesFolderName = "Templates"

if ([string]::IsNullOrEmpty($scriptRoot)) {
	$scriptRoot = $PSScriptRoot
}

. "$scriptRoot\common.ps1"


Write-Debug $debugFile "Called broadcast script with parameters" $params

#For free accounts, Mailchimp only allows one list/audience - so just reuse this and set the given listname as a tag
$firstList = Get-FirstList
$listId = $firstList.id

#Get the id of the segment created by upload.ps1
$segmentId  = Get-SegmentIdForName $listId $listName
Write-Debug $debugFile "Found segment with id ${segmentId} for name ${listName}"

#Get the folder id for the "Templates" folder, which is where to the predefined templates should have been created
$templatesFolderId = Get-CampaignFolderIdForName $templatesFolderName
Write-Debug $debugFile "Found campaign folder with id ${templatesFolderId} for name ${templatesFolderName}"

#Get the id of the template campaign to use as a basis for this broadcast
$campaignId = Get-CampaignIdForNameInFolder $templatesFolderId $messageName
Write-Debug $debugFile "Found campaign with id ${campaignId} for name ${messageName} in folder with id ${templatesFolderId}"

#Copy the template campaign and store its new id.
$replicateCampaignResult = Invoke-RestMethod -UseBasicParsing -Method 'Post' -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${campaignId}/actions/replicate" -Headers @{ "Authorization" = "Bearer: $apiKey" }
$newCampaignId = $replicateCampaignResult.id
Write-Debug $debugFile "Created new campaign with id ${newCampaignId} by duplicating campaign ${campaignId}"

#Create the structure that defines the list segment to send this new campaign to.
$segmentOpts = [hashtable]@{
	"saved_segment_id" = $segmentId
	"match" = "all"
}

$recipients = [hashtable]@{
	"list_id" = $listId
	"segment_opts" = $segmentOpts
}

$updateCampaignBody = [hashtable]@{
	"recipients" = $recipients
}
$updateCampaignBodyJson = $updateCampaignBody | ConvertTo-Json

#Update the new campaign to use the specified list segment
Write-Debug $debugFile "Patching update campaign details" $updateCampaignBodyJson
$createdCampaignResult = Invoke-RestMethod -UseBasicParsing -Method 'Patch' -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${newCampaignId}" -Headers @{ "Authorization" = "Bearer: $apiKey" } -Body $updateCampaignBodyJson
Write-Debug $debugFile "Updated campaign id ${newCampaignId} to use segment ${segmentId} from list ${listId}"

#Trigger the campaign to run now
Invoke-WebRequest -UseBasicParsing -Method 'Post' -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${newCampaignId}/actions/send" -Headers @{ "Authorization" = "Bearer: $apiKey" }
Write-Debug $debugFile "Triggered send for campaign id ${newCampaignId}"

$broadcastResults = [hashtable]@{
	"Recipients" = 0
	"RecipientsRejected" = 0
	"TransactionId" = "${transactionId}"
}
return $broadcastResults
