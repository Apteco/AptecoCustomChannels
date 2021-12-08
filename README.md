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
<br/>**Email**|
Agnitas EMM||REST/SFTP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:SendTest<br/>:heavy_check_mark:/:o:PreviewMessage<br/>:heavy_check_mark:/:o:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:heavy_check_mark:Trigger FERGE|Currently in the dev-branch
Bertelsmann eLettershop||REST/SFTP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:heavy_check_mark:Trigger FERGE|Code is private
CleverReach|Mailings<br/>Tags<br/>THEA|REST API v3|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:o:SendTest<br/>:heavy_check_mark:/:o:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:o:Broadcast<br/>:heavy_check_mark:/:o: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[CleverReach Mailing Integration Guideline](CleverReach/Mailing)<br/>[CleverReach Tagging Integration Guideline](CleverReach/Tagging)
ELAINE|Transactional|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:o:SendTest<br/>:heavy_check_mark:/:o:PreviewMessage<br/>:heavy_check_mark:/:o:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:o: Response Download<br/>:heavy_check_mark:/:o:Trigger FERGE|[ELAINE Transactional Mailing Integration Guideline](ELAINE/Transactional)
Flexmail|ImportRecipients|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:question:/:x:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[Flexmail Integration Guideline](Flexmail)
Inxmail|Professional|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:heavy_check_mark:Trigger FERGE|Currently in the dev-branch
Optimizely Campaign|Closed Loop Smart Campaigns|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:o:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:question:/:x:Broadcast<br/>:heavy_check_mark:/:x: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[EpiServer SC Integration Guideline](OptimizelyCampaign/SmartCampaigns)
Optimizely Campaign|Marketing Automation/<br/>Transactional Mailings|SOAP|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:x:SendTest<br/>:heavy_check_mark:/:x:PreviewMessage<br/>:x:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:o: Response Download<br/>:heavy_check_mark:/:x:Trigger FERGE|[EpiServer MA Integration Guideline](OptimizelyCampaign/MarketingAutomation)
<br/>**Print**|
Deutsche Post|TriggerDialog|REST|:heavy_check_mark:/:o:Upload<br/>:heavy_check_mark:/:o:Broadcast|[TriggerDialog Integration Guideline](TriggerDialog)
Bertelsmann|Campaign Automation|||Only on request
Optilyz|S3|AWS-S3/REST|:heavy_check_mark:/:heavy_check_mark:ChooseAutomation<br/>:heavy_check_mark:/:heavy_check_mark:Upload|[Optilyz Integration Guideline](Optilyz/AWS)
Optilyz|REST|REST|:heavy_check_mark:/:heavy_check_mark:ChooseAutomation<br/>:heavy_check_mark:/:heavy_check_mark:Upload|[Optilyz Integration Guideline](Optilyz/REST)
<br/>**Mobile**|
Syniverse|SMS<br/>WhatsApp Business API|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:question:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:question:/:heavy_check_mark:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:heavy_check_mark:/:heavy_check_mark: Response Download<br/>:heavy_check_mark:/:o:Trigger FERGE<br/>:heavy_check_mark:/:heavy_check_mark: Webhooks Support|[Syniverse Mobile Integration Guideline](Syniverse/SyniverseSMS)
Syniverse|Number Verification|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark: Mobile Results Download|[Syniverse Mobile Validation Integration Guideline](Syniverse/SyniverseValidation)
Syniverse|Wallet Download|REST|:heavy_check_mark:/:heavy_check_mark: Webhooks Trigger<br/>:heavy_check_mark:/:heavy_check_mark: Regular Batch Download|[Syniverse Wallet Download Integration Guideline](Syniverse/SyniverseWalletDownload)
Syniverse|Wallet Notification|REST|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:x:/:x:SendTest<br/>:heavy_check_mark:/:heavy_check_mark:PreviewMessage<br/>:question:/:x:PreviewMessagePersonalised<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark:Broadcast<br/>:question:/:x: Response Download<br/>:question:/:x:Trigger FERGE|[Syniverse Wallet Notification Integration Guideline](Syniverse/SyniverseWalletNotification)
Syniverse|Wallet Update|REST|:heavy_check_mark:/:heavy_check_mark: Update wallets|[Syniverse Wallet Update Integration Guideline](Syniverse/SyniverseWalletUpdate)
<br/>**Database**|
MSSQL / SQL Server|Local<br/>Domain<br/>PrivateCloud|PowerShell/.NET<br/>Bulk|:heavy_check_mark:/:heavy_check_mark:GetMessages<br/>:heavy_check_mark:/:heavy_check_mark:Upload<br/>:heavy_check_mark:/:heavy_check_mark: Data Results Download|[MSSQL Integration Guideline](MSSQL)
sqlite|Local<br/>Network<br/>In-Memory|PowerShell/.NET/sqliteCLI|
<br/>**File Transfer**|
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
  
# Troubleshooting

* If the files created from PeopleStage and used by the "upload" scripts have the extension `.converted` then the output encoding in the PeopleStage Channel Editor should be changed to another encoding.
* If some umlauts are not used correctly, then the script is maybe saved in the wrong encoding. It should be UTF-8.

# Cloning and get Updates from this Repository

* You can download the whole repository as a zip file, clone it via GitHub Desktop or use a command line interface. All possibilities are shown here:<br/>![grafik](https://user-images.githubusercontent.com/14135678/99143550-9b58c700-265e-11eb-91cb-dcc3001e26b0.png)
* I can recommend the last two options because then you can "pull" updated code from time to time and can benefit from new features or bugfixes.
