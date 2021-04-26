# Preparation

## Scripts

* Download the scripts
* Open `sms__00__create_settings.ps1` and change the following tokes
  * Replace the connection string in variable `$mssqlConnectionString` with something like `Data Source=localhost;Initial Catalog=RS_Handel;Trusted_Connection=True;`
* Execute "validate__00__create_settings.ps1"
* Enter accesstoken

## SQL

If you want to save the results of the send SMS, you can use the webhooks mechanism of syniverse (needs to be requested at syniverse) or request the messages directly. This uses the response database of the system. Make sure you create a table like this on the Response Database

```MSSQL
/****** Object:  Table [dbo].[Messages]    Script Date: 26.04.2021 14:34:04 ******/
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
```


## PeopleStage

* Create the channel with the needed settings
* Create a SMS template
* Create a campaign and have fun