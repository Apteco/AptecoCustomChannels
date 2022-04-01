/* Drop temporary table if exists */
DROP TABLE IF EXISTS #RabattCodes#RABATTGUID#


/* Create a temporary table for the current Rabatt */
CREATE TABLE #RabattCodes#RABATTGUID#
(
  MappedId int
 ,ExternalAttributeCode int
 ,DaysValid int
 ,LimitRedeem int
 )


/* Declare variables for the filter*/
DECLARE @campaign AS INT
DECLARE @run AS INT
DECLARE @step AS INT

/* Set variables for this run */
set @campaign = #CAMPAIGN#
set @run = #RUN#
set @step = #STEP#

/* Declare the variables for the loop */
DECLARE @IterationLoopTable table (ID int)
DECLARE @IterationLoop int
DECLARE @TotalLoop int
DECLARE @PageNumber AS INT
DECLARE @RowspPage AS INT

/* Set the start variables */ 
SET @PageNumber = 1
SET @RowspPage = #ROWSPERPAGE#
SET @TotalLoop = 0



/* Declare namespace for xml querying */
;WITH XMLNAMESPACES (
	'http://www.peoplestage.net/Apteco.CLMClient.DataTier.XmlSerialisation' as ps
)

INSERT INTO #RabattCodes#RABATTGUID# 
SELECT MappedId, ExternalAttributeCode, DaysValid, LimitRedeem
FROM (

	/* Pick out the relevant IDs for allocated treatments */
	SELECT
		 MappedId
		,REVERSE(LEFT(REVERSE(MappedText), CHARINDEX(' ', REVERSE(MappedText)) - 1)) AS MappedGuid
		/* , * */
	FROM (

		/* Get all IDs for the Campaign´s Elements */
		SELECT
		T1.Fields.value('local-name(..)','nvarchar(200)') as MappedCategory
		, T1.Fields.value('@id', 'int') as MappedId
		, T1.Fields.value('@p', 'nvarchar(200)') as MappedText
		/*, T1.Fields.query('.') as q
		, CampaignXmlSource.* */
		FROM (

			/* Get latest Campaign XML */
			SELECT cast(Decompress([CompressedDefinition]) AS [xml]) AS ElementXml, *
            FROM [Custom].[vModelElementLatest] as ModelElement
			WHERE ModelElement.SchemaIdType = 'ProcessId' and ModelElement.ElementType = 'Campaign'
			/* filter for the campaign here */
			and ModelElement.SchemaId = @campaign


		) AS CampaignXmlSource
		CROSS APPLY CampaignXmlSource.ElementXml.nodes('//ps:P') AS T1(Fields)

	) AS CampaignElements
	WHERE
	CampaignElements.MappedCategory = 'TreatmentLibraryItemIdMap'

) AS CampaignAttributes

INNER JOIN (

	/* Get all external attributes matching the Rabatt folder in the [ExternalAttributeDefinition]*/
	SELECT
		 UsedExternalAttributes.LibraryItemReference
		/*,UsedExternalAttributes.ExternalAttributeId*/
		,UsedExternalAttributes.ExternalAttributeCode
		,UsedExternalAttributes.DaysValid
		,UsedExternalAttributes.LimitRedeem
	FROM (

		/* Get all external attributes */
		SELECT
			/* T2.Attributes.query('.'), T1.AllocationDetail.query('.') */
			T2.Attributes.value('./ps:LibraryItemReference[1]/ps:Id[1]','nvarchar(36)') as LibraryItemReference
			/* ,T1.Fields.query('./ps:ResultDetailsList/ps:ResultDetails/ps:Name[1]').value('.', 'nvarchar(50)') AS FieldName*/
			,T2.Attributes.value('(.//ps:DataSourceStringAttributeValue/@ExternalAttributeId)[1]', 'int') AS ExternalAttributeId 
			,T2.Attributes.value('(.//ps:DataSourceStringAttributeValue/@SelectedCode)[1]', 'int') AS ExternalAttributeCode
			,isnull(T2.Attributes.value('(.//ps:NumericStringAttributeValue[1]/@Value)[1]', 'int'), #DEFAULTVALIDDAYS#) AS DaysValid
			,isnull(T2.Attributes.value('(.//ps:NumericStringAttributeValue[2]/@Value)[1]', 'int'), #DEFAULTDAYSREDEEM#) AS LimitRedeem
		FROM (

			/* Get latest Allocations XML */
			SELECT cast(Decompress(ModelElement.[CompressedDefinition]) AS [xml]) AS ElementXml
			FROM [Custom].[vModelElementLatest] AS ModelElement
			WHERE ElementType = 'Allocation' AND ModelElement.OwningElementId IN (

				/* Get the campaign id */
				SELECT Id FROM [Custom].[vModelElementLatest] AS CampaignGuid
				WHERE CampaignGuid.SchemaIdType = 'ProcessId' AND CampaignGuid.ElementType = 'Campaign'
				/* filter for the campaign here */
				AND CampaignGuid.SchemaId = @campaign

			) 

		) AS AllocationsXml
		CROSS APPLY AllocationsXml.ElementXml.nodes('//ps:AllocationDetail') AS T1(AllocationDetail) /* Get all attributes */
		CROSS APPLY T1.AllocationDetail.nodes('.//ps:TextResult') AS T2(Attributes) /* Get single parts of attributes */

	) AS UsedExternalAttributes
	INNER JOIN [dbo].[ExternalAttributeDefinition] DefinedExternalAttributes ON DefinedExternalAttributes.Id = UsedExternalAttributes.ExternalAttributeId
	WHERE DefinedExternalAttributes.[Folder] = 'RABATT'

) AS RABATT on RABATT.LibraryItemReference = CampaignAttributes.MappedGuid



/* Now load the data for the CRM-DB in batches */

WHILE ( @IterationLoop > 0 OR @IterationLoop IS NULL)
BEGIN 

	/* EMPTY THE VARIABLE FOR THE ITERATION */
	DELETE FROM @IterationLoopTable
	SET @IterationLoop = 0
	
    /* INSERT VALUES */
	INSERT INTO [customerbase].[PeopleStage].[tblCustomer]
    /* OUTPUT RESULT IDs in TABLE VARIABLE */
	OUTPUT INSERTED.Urn INTO @IterationLoopTable
	/* SELECT FOR THE INSERT */
	SELECT Cast(Communications.Urn AS [int]) AS Urn
	 ,Attributes.CommunicationKey
	 ,RABATT.ExternalAttributeCode AS Rabatt
	 ,Communications.CampaignId AS Campaign
	 ,Communications.Run
	 ,Rabatt.DaysValid
	 ,Rabatt.LimitRedeem
	FROM [dbo].[FS_Build_Attributes] Attributes
	INNER JOIN (


 	/* Get all communications for that specific run */
 	SELECT x.CustomerId AS Urn
	       ,c.CampaignId
	       ,c.Run
	       ,c.CommunicationKey
	       FROM [dbo].[FS_Build_Communications] as c
	 INNER JOIN [dbo].[UrnDefinition] u ON u.Id = c.UrnDefinitionId
	 INNER JOIN [customerbase].[crmdb].[tbl_x_Customer_Card] x ON x.CardId = cast(c.Urn AS [int])
	 WHERE c.CampaignId = @campaign
	   AND c.Run = @run
	   AND c.StepId = @step
	   AND c.IsControlForDelivery = 0
	   AND u.XRefType = 'TransactionXRef'
    ORDER BY c.Id
	           OFFSET ((@PageNumber - 1) * @RowspPage) ROWS
	           FETCH NEXT @RowspPage ROWS ONLY
 
	 UNION ALL
 
	 SELECT c.Urn
	       ,c.CampaignId
	       ,c.Run
	       ,c.CommunicationKey
	 FROM [dbo].[FS_Build_Communications]  AS c
	 INNER JOIN [dbo].[UrnDefinition] u ON u.Id = c.UrnDefinitionId
	 WHERE c.CampaignId = @campaign
	  AND c.Run = @run
	  AND c.StepId = @step
	  AND c.IsControlForDelivery = 0
	  AND u.XRefType = 'AgentXRef'
      ORDER BY c.Id
	           OFFSET ((@PageNumber - 1) * @RowspPage) ROWS
	           FETCH NEXT @RowspPage ROWS ONLY


	 ) AS Communications ON Communications.CommunicationKey = Attributes.CommunicationKey
	INNER JOIN vTreatmentAllocationDefinition AS TreatmentAllocation ON TreatmentAllocation.Id = Attributes.AttributeId
	INNER JOIN #RabattCodes#RABATTGUID# AS Rabatt ON Rabatt.MappedId = TreatmentAllocation.TreatmentLibraryItemInstanceId

	/* PUT NO OF ROWS FOR THIS ITERATION IN TOTAL COUNT */
	SET @IterationLoop = ( select count(*) from @IterationLoopTable )
	SET @TotalLoop = @TotalLoop + @IterationLoop
	SET @PageNumber = @PageNumber + 1

END
/* END LOOP */


/* Drop temporary table if exists */
DROP TABLE IF EXISTS #RabattCodes#RABATTGUID#


/* CHECK VARIABLES */
/* SELECT @IterationLoop */
/* SELECT @PageNumber */
SELECT @TotalLoop
