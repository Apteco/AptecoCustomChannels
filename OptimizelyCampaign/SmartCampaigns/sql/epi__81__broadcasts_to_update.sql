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