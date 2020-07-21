# AptecoCustomChannels

Custom Channels made for usage in the Apteco Marketing Suite

## Dummy Template / Getting started

To start with your very own first custom channel to use in Apteco PeopleStage, you can use the dummy template without external dependencies. It is pure PowerShell (>=5.1). You can find it here: [Dummy](Dummy/)

## Current Status

Legend:
* The icons mean if functionalities are Available/Implemented
* :heavy_check_mark: = "done"
* :o: = "partially implemented"
* :x: = "not implemented"
* :question: = "not checked yet"

### Email

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Flexmail|ImportRecipients|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:question:/:x:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[Flexmail Integration Guideline](Flexmail)
Mailingwork|Standard|REST
Mailingwork|Campaign|REST
CleverReach|REST API v3|REST
EpiServer Campaign|Closed Loop Smart Campaigns|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:o:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:question:/:x:Broadcast<br/>:heavy_check_mark:/:x: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[EpiServer SC Integration Guideline](EpiServerCampaign/SmartCampaigns)
EpiServer Campaign|Marketing Automation/<br/>Transactional Mailings|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:x:SendTest<br/>:heavy_check_mark:/:x:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:o: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[EpiServer MA Integration Guideline](EpiServerCampaign/MarketingAutomation)
Arvato Systems|elettershop|REST/SFTP||Only on request



### Print

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Deutsche Post|TriggerDialog|REST|:heavy_check_mark:/:o:Upload<br/>:heavy_check_mark:/:o:Broadcast|[TriggerDialog Integration Guideline](TriggerDialog)
Bertelsmann|Campaign Automation|||Only on request
Optilyz|S3|AWS-S3/REST
Optilyz|REST|REST


### Mobile

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Syniverse|SMS|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:question:/:x:PreviewMessage<br/>:question:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:question:/:x: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[Syniverse SMS Integration Guideline](Syniverse/SyniverseSMS)
Syniverse|Number Verification|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark: Mobile Results Download|[Syniverse Mobile Validation Integration Guideline](Syniverse/SyniverseValidation)
Syniverse|Wallets|REST

### Database

Integration|API|Type|Functionalities|Link
-|-|-|-|-
MSSQL / SQL Server|Local<br/>Domain<br/>PrivateCloud|PowerShell/.NET<br/>Bulk|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark: Data Results Download|[MSSQL Integration Guideline](MSSQL)
sqlite|Local<br/>Network<br/>In-Memory|PowerShell/.NET/sqliteCLI|

### File Transfer
Integration|API|Type|Functionalities|Link
-|-|-|-|-
WinSCP|SFTP<br/>FTP<br/>S3<br/>WebDAV<br/>SCP (SSH)|WinSCP .NET assembly|:x:/:x:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:o:/:o: Data Results Download|[WinSCP Integration Guideline](WinSCP)


## Requirements

* An Apteco server with a FastStats Service and 2019-Q3 release or newer. There were some improvements in the 2019-Q4 release.
* Make sure PS Version 5.1 is installed at Minimum (PowerShell Core >=6 is not tested yet)
  * You can see it in Powershell if you type in ```$PSVersionTable```
  * If PSVersion < 5.1, then install this one: https://www.microsoft.com/en-us/download/details.aspx?id=54616
  * And restart the machine

## Description

The custom channels can trigger those functionalities

1.	GetMessagesScript: used to return an array of string pairs of <id>,<name> of the messages
2.	GetListsScript: used to return an array of string pairs of <id>,<name> of the lists
3.	TestScript: used to test if the broadcaster api is available
4.	SendTestEmailScript: used to send a test send to the broadcaster, given a recipient
5.	PreviewMessageScript: used to return a html view of the message given a recipient and content values
6.	UploadScript: used to upload a list to the broadcaster, given a tab delimited file
7.	BroadcastScript: used to send a list a message
  
