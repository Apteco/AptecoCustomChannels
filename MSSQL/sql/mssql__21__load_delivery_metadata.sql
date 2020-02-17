  SELECT 
	Deliveries.CampaignId AS ID
   ,NULL AS GUID
   ,Deliveries.CampaignDesc AS Name
   ,NULL AS Deactivated
   ,NULL AS Deleted
   ,DeliveryCommands.Run AS Run
   ,DeliveryCommands.DateAdded AS TIMESTAMP
   ,Deliveries.MessageId
   ,Deliveries.MessageDesc
   ,Deliveries.DeliveryStepId
  FROM (
   SELECT [Id]
    ,[DateAdded]
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/ExternalId/IdType)[1]', 'nvarchar(50)') AS ExternalIdType
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/ExternalId/Id)[1]', 'nvarchar(50)') AS ExternalId
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/DeliveryKey)[1]', 'uniqueidentifier') AS DeliveryKey
    ,[Command].value('(/DeliveryCommand/BroadcastActionDetails/Run)[1]', 'bigint') AS Run
	/*,[Command].value('(/DeliveryCommand/BroadcastActionDetails/StepId)[1]', 'bigint') AS StepId*/
    ,[Status]
   FROM [ps_handel].[dbo].[vDeliveryCommands]
   WHERE [Command].value('(/DeliveryCommand/BroadcastActionDetails/FilePath)[1]', 'varchar(max)') LIKE '%#FILE#'
   ) AS DeliveryCommands
  INNER JOIN [ps_handel].[dbo].[FS_Decode_Deliveries] AS Deliveries ON Deliveries.DeliveryStepId = DeliveryCommands.ExternalId



