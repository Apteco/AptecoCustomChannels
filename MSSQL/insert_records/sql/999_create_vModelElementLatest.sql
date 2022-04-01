USE [ps_handel]
GO

CREATE SCHEMA [Custom]
GO

/****** Object:  View [Custom].[vModelElementLatest]    Script Date: 01.04.2022 14:32:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


CREATE OR ALTER view [Custom].[vModelElementLatest] as

select ModelElement.* from dbo.fModelLatestVersionToElement() LatestElement
inner join [dbo].[ModelElement] ModelElement on ModelElement.Id = LatestElement.ElementId and ModelElement.Revision = LatestElement.ElementRevision
GO


