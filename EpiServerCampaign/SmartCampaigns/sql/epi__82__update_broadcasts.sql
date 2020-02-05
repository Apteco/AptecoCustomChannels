UPDATE [dbo].[BroadcastsDetail]
SET [BroadcasterTransactionId] = '#MAILINGID#', [RecipientsUploaded] = '#UPLOADED#', [RecipientsRejected] = '#REJECTED#', [RecipientsBroadcast] = '#BROADCAST#'
WHERE [ActionType] = 'Delivered'
        AND [BroadcastId] = '#BROADCASTID#'