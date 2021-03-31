
################################################
#
# NOTES
#
################################################

<#

THIS IS ONLY A DRAFT AND NOT TESTED YET

#>

# Load broadcasts to update
$loadBroadcastsStatement = @"

SELECT * FROM [dbo].[BroadcastsDetail] WHERE [BroadcastId] IN (
        
/* Only broadcasts that have a wave id and been sent through the custom channel */
SELECT BroadcastId FROM [dbo].[BroadcastsDetail] WHERE [ActionType] = 'Prepared'
    AND [Status] = 'Completed'
    AND [Parameters] LIKE '%CustomProvider=#PROVIDER#%'
    AND (
    [BroadcasterTransactionId] IS NOT NULL
    OR [BroadcasterTransactionId] != '0'
    )

INTERSECT

/* Only broadcasts that don't have a mailing id and been sent through the custom channel */
SELECT BroadcastId FROM [dbo].[BroadcastsDetail] WHERE [ActionType] = 'Delivered'
    AND [Status] = 'Completed'
    AND [Parameters] LIKE '%CustomProvider=#PROVIDER#%'
    AND (
    [BroadcasterTransactionId] IS NULL
    OR [BroadcasterTransactionId] = '0'
    )

)
AND [ActionType] = 'Prepared'
"@


Invoke-SqlServer -query "" -instance "localhost" -database "rs_db" -executeNonQuery







# Update the PowerShell to ELAINE to make use of the existing FERGE download
#$updateBroadcasts2SQL = Get-Content -Path "$( $updateBroadcasts2SQLFile )" -Encoding UTF8
$updateBroadcastsStatement = @"
UPDATE [dbo].[Broadcasts]
SET Broadcaster = 'Elaine'
WHERE Broadcaster = 'PowerShell' and Id = '#BROADCASTID#'
"@

$updateBroadcasts2SQL = $updateBroadcasts2SQL -replace "#BROADCASTID#", $broadcastId


Invoke-SqlServer -query "" -instance "localhost" -database "rs_db" -executeNonQuery
