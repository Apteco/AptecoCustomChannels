#See https://mailchimp.com/developer/marketing/guides/quick-start/
param([hashtable] $params)

$server = $params['Username'];
$apiKey = $params['Password'];
$messageName = $params['MessageName'];
$debugFile = $params['DebugFile'];
$scriptRoot = $params['ScriptRoot'];
$templatesFolderName = "Templates"

if ([string]::IsNullOrEmpty($scriptRoot)) {
	$scriptRoot = $PSScriptRoot
}

. "$scriptRoot\common.ps1"

Write-Debug $debugFile "Called previewMessage script with parameters" $params

#Get the folder id for the "Templates" folder, which is where to the predefined templates should have been created
$templatesFolderId = Get-CampaignFolderIdForName $templatesFolderName
Write-Debug $debugFile "Found campaign folder with id ${templatesFolderId} for name ${templatesFolderName}"

#Get the id of the template campaign to preview
$campaignId  = Get-CampaignIdForNameInFolder $templatesFolderId $messageName
Write-Debug $debugFile "Found campaign with id ${campaignId} for name ${messageName} in folder with id ${templatesFolderId}"

if ([string]::IsNullOrEmpty($campaignId)) {
	return null
}

#Get the details of the template campaign
$detailsResults = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${campaignId}" -Headers @{ "Authorization" = "Bearer: $apiKey" }
Write-Debug $debugFile "Campaign Details for campaign ${campaignId}" $detailsResults

#Get the HTML to return as a preview for the template campaign
$contentResults = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/campaigns/${campaignId}/content" -Headers @{ "Authorization" = "Bearer: $apiKey" }
Write-Debug $debugFile "Campaign Content for campaign ${campaignId}" $contentResults

#Create the map of information to return
$previewDetails = [Hashtable]@{
    "Type" = "Email"
    "FromAddress"=$detailsResults.settings.reply_to
    "FromName"=$detailsResults.settings.from_name
    "Html"=$contentResults.html
    "ReplyTo"=$detailsResults.settings.reply_to
    "Subject"=$detailsResults.settings.subject_line
    "Text"=""
}

Write-Debug $debugFile "Returning details" $previewDetails
return $previewDetails
