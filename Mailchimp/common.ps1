<#
.SYNOPSIS
If a debug file path is specified, output debug information to it

.PARAMETER debugFilePath
The path of a file to write the debug output to, or null/empty if no debug output should be written

.PARAMETER message
A message to be output to the debug file

.PARAMETER obj
An object to be serialised as JSON to the debug file along with the message, or null if not wanted

.EXAMPLE
Write-Debug 'C:\temp\debug.txt' 'Hello, World!' $myObjectToSerialise
#>
function Write-Debug ([string] $debugFilePath, [string] $message, [object] $obj)
{
	if (-Not [string]::IsNullOrEmpty($debugFile)) {
		$timestamp = Get-date
		Write-Output "${timestamp}: $message" | Out-File -FilePath $debugFile -Append 
		if ($obj) {
			if ($obj -is [Hashtable] -And ([Hashtable]$obj).ContainsKey("Password")) {
				$obj = $obj.Clone()
				$obj["Password"] = "***Redacted***"
			}
			ConvertTo-Json -InputObject $obj | Out-File -FilePath $debugFile -Append 
		}
	}
}

<#
.SYNOPSIS
Look up a campaign's id from it's name in the given campaign folder

.PARAMETER campaignFolderId
The id of the campaign folder to search in 

.PARAMETER campaignName
The name of the campaign to find

.EXAMPLE
$campaignId = Get-CampaignIdForNameInFolder 'folder-001' 'My Campaign'
#>
function Get-CampaignIdForNameInFolder ([string] $campaignFolderId, [string] $campaignName)
{
	$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/campaigns?count=1000" -Headers @{ "Authorization" = "Bearer: $apiKey" }
	$campaigns = $results.campaigns
	Foreach($campaign in $campaigns) {
		$id = $campaign.id;
		$name = $campaign.settings.title;
		If ($name -eq $campaignName) {
			return $id
		}
	}
	return null
}

<#
.SYNOPSIS
Look up a campaign folder's id from the given name

.PARAMETER campaignFolderName
The name of the campaign folder to find

.EXAMPLE
$campaignFolderId = Get-CampaignFolderIdForName 'My Campaign Folder'
#>
function Get-CampaignFolderIdForName ([string] $campaignFolderName)
{
	$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/campaign-folders?count=1000" -Headers @{ "Authorization" = "Bearer: $apiKey" }
	$folders = $results.folders
	Foreach($folder in $folders) {
		$id = $folder.id;
		$name = $folder.name;
		If ($name -eq $campaignFolderName) {
			return $id
		}
	}
	return null
}

<#
.SYNOPSIS
Look up a segment's id from the given name for the given list

.PARAMETER listId
The id of the list to find the segment in

.PARAMETER segmentName
The name of the segmenbt to find

.EXAMPLE
$segmentId = Get-SegmentIdForName 'list-001' 'My Segment'
#>
function Get-SegmentIdForName ([string] $listId, [string] $segmentName)
{
	$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/lists/${listId}/segments?count=1000" -Headers @{ "Authorization" = "Bearer: $apiKey" }
	$segments = $results.segments
	Foreach($segment in $segments) {
		$id = $segment.id;
		$name = $segment.name;
		If ($name -eq $segmentName) {
			return $id
		}
	}
	return null
}

<#
.SYNOPSIS
Look up a list's id from the given name

.PARAMETER listName
The name of the list 

.EXAMPLE
$listId = Get-ListIdForName 'My List'
#>
function Get-ListIdForName ([string] $listName)
{
	$results = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/lists?count=1000" -Headers @{ "Authorization" = "Bearer: $apiKey" }
	$lists = $results.lists
	Foreach($list in $lists) {
		$id = $list.id;
		$name = $list.name;
		If ($name -eq $listName) {
			return $id
		}
	}
	return null
}

<#
.SYNOPSIS
Get the first available list in this account

.EXAMPLE
$list = Get-FirstList
#>
function Get-FirstList()
{
	$firstListResults = Invoke-RestMethod -UseBasicParsing -Uri "https://${server}.api.mailchimp.com/3.0/lists" -Headers @{ "Authorization" = "Bearer: $apiKey" }
	$firstList = $firstListResults.lists
	return $firstList
}