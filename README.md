# AptecoCustomChannels

Custom Channels made for usage in the Apteco Marketing Suite

## Dummy Template / Getting started

To start with your very own first custom channel to use in Apteco PeopleStage, you can use the dummy template without external dependencies. It is pure PowerShell (>=5.1). You can find it here: [Dummy/](Dummy)

## Current Status

Legend:
* The icons mean if functionalities are Available/Implemented
* :heavy_check_mark: = "done"
* :x: = "not implemented"
* :question: = "not checked yet"

### Email

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Flexmail|ImportRecipients|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:question:/:x:Broadcast|[Flexmail Integration Guideline](Flexmail)
Mailingwork|Standard|REST
Mailingwork|Campaign|REST
CleverReach||REST
EpiServer Campaign|Closed Loop Smart Campaigns|SOAP
EpiServer Campaign|Marketing Automation/<br/>Transactional Mailings|SOAP


### Print

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Deutsche Post|TriggerDialog|REST
Optilyz|S3|AWS-S3/REST
Optilyz|REST|REST


### Mobile

Integration|API|Type|Functionalities|Link
-|-|-|-|-
Syniverse|SMS|REST
Syniverse|Number Verification|REST
Syniverse|Wallets|REST

### Database

Integration|API|Type|Functionalities|Link
-|-|-|-|-
MSSQL / SQL Server||
sqlite||



## Requirements

* An Apteco server with an FastStats Service
* Make sure PS Version 5.1 is installed at Minimum
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
  
