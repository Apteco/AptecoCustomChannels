SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[Messages](
	[id] [int] IDENTITY(1,1) NOT NULL,
	[service] [varchar](50) NULL,
	[Urn] [varchar](50) NULL,
	[BroadcastTransactionID] [varchar](50) NULL,
	[MessageID] [varchar](50) NULL,
	[CommunicationKey] [varchar](50) NULL,
	[created_at] [datetime] NOT NULL,
	[failurecode] [varchar](50) NULL,
	[state] [varchar](50) NULL,
	[to] [varchar](50) NULL,
 CONSTRAINT [PK_Messages] PRIMARY KEY CLUSTERED 
(
	[id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[Messages] ADD  CONSTRAINT [DF_Messages_created_at]  DEFAULT (getdate()) FOR [created_at]
GO


