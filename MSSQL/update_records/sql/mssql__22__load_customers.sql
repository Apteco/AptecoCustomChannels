/* Declare variables */
declare @campaign int
declare @run int
declare @step int

/* Set variables for this run */
set @campaign = #CAMPAIGN#
set @run = #RUN#
set @step = #STEP#

/* Get all communications for that specific run independent of card and customer */

SELECT comms.*
 ,cls.*
FROM (
 SELECT x.CustomerId AS Urn
  ,c.CampaignId
  ,c.Run
  ,c.CommunicationKey
 FROM [dbo].[FS_Build_Communications] c
 INNER JOIN [dbo].[UrnDefinition] u ON u.Id = c.UrnDefinitionId
 INNER JOIN [customerbase].[dbo].[cards] x ON x.CardId = cast(c.Urn AS [int])
 WHERE c.CampaignId = @campaign
  AND c.Run = @run
  AND c.StepId = @step
  AND c.IsControlForDelivery = 0
  AND u.XRefType = 'TransactionXRef'
 
 UNION ALL
 
 SELECT c.Urn
  ,c.CampaignId
  ,c.Run
  ,c.CommunicationKey
 FROM [dbo].[FS_Build_Communications] c
 INNER JOIN [dbo].[UrnDefinition] u ON u.Id = c.UrnDefinitionId
 WHERE c.CampaignId = @campaign
  AND c.Run = @run
  AND c.StepId = @step
  AND c.IsControlForDelivery = 0
  AND u.XRefType = 'AgentXRef'
 ) comms
INNER JOIN [customerbase].[crmdb].[customers] cls ON cls.Id = cast(comms.Urn AS [int])
WHERE cls.Id in (#CUSTOMERURN#)