# Create settings

* Open `optilyz__00__create_settings.ps1` and have a look at the following tokens
  * <username>

# Prepare ELAINE

* To use a mailing for transactional mailing, go to the menu point `Mehr -> Als Automation-Message verwenden`<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/104565568-bd65ca00-564c-11eb-9896-4706103b0be4.png)<br/>
* And then confirm it with `Als Transaktions-Message verwenden`<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/104565891-411fb680-564d-11eb-9670-09cd5aa62e74.png)

# Prepare the database

If you want to save the results into the response database (useful for the response laterhand), then it is useful to write the transactional messages direclty in there

This is an example statement to create it, replace the database name at the top:

```SQL
USE [RS_Handel]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[ELAINETransactional](
	[Urn] [nvarchar](255) NULL,
	[Email] [nvarchar](255) NULL,
	[SendId] [int] NULL,
	[CommunicationKey] [uniqueidentifier] NULL,
	[BroadcastTransactionId] [uniqueidentifier] NULL,
	[MailingId] [int] NULL,
	[LastStatus] [nvarchar](50) NULL,
	[Timestamp] [datetime] NULL
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[ELAINETransactional] ADD  CONSTRAINT [DF_ELAINETransactional_Timestamp]  DEFAULT (getdate()) FOR [Timestamp]
GO
```

# Upload

* Required Fields are always URN and email and will be automatically matched with ELAINE fields
* Matched fields are uploaded as c_fields
* Non-Matched fields are made lowercase, replace space with underscore and used as t-field. So `Nach name` will result in `t_nach_name`

# Reponses

* To match the response data with the broadcasts, trigger by Apteco, you can use the following statement:

```SQL
update 

SELECT et.*
	,bd.BroadcastId
FROM [dbo].[ELAINETransactional] et
INNER JOIN [dbo].[BroadcastsDetail] bd ON try_cast(bd.BroadcasterTransactionId AS UNIQUEIDENTIFIER) = et.BroadcastTransactionId
ORDER BY TIMESTAMP
```