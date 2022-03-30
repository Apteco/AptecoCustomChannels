

SELECT *
FROM (
	SELECT *
		,row_number() OVER (
			PARTITION BY CreativeTemplateId ORDER BY Revision DESC
			) AS prio
	FROM [dbo].[CreativeTemplate]
	) ct
WHERE ct.prio = '1'
	AND MessageContentType = 'SMS'
ORDER BY CreatedOn

