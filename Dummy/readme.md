# Prerequisites

* Make sure PS Version 5.1 is installed at Minimum
  * You can see it in Powershell if you type in ```$PSVersionTable```
  * If PSVersion < 5.1, then install this one: https://www.microsoft.com/en-us/download/details.aspx?id=54616
  * And restart the machine

# Setup

1. Create a folder somewhere where you can put in the example scripts from this gist
1. Put the scripts in there you want to use
1. Open the PeopleStage Channel Editor
  * Create a new E-Mail Channel
  * Use "PowerShell" as Broadcaster
  * Select you email address variable
  * Go to the parameters tab
  * Add the scripts you want to use like "GetMessagesScript" and refer to something like "C:\FastStats\scripts\esp\custom\get-messages.ps1"
1. Create a campaign, refresh your library, use your new channel and the messages should directly show up

# Description

1.	GetMessagesScript: used to return an array of string pairs of <id>,<name> of the messages
2.	GetListsScript: used to return an array of string pairs of <id>,<name> of the lists
3.	TestScript: used to test if the broadcaster api is available
4.	SendTestEmailScript: used to send a test send to the broadcaster, given a recipient
5.	PreviewMessageScript: used to return a html view of the message given a recipient and content values
6.	UploadScript: used to upload a list to the broadcaster, given a tab delimited file
7.	BroadcastScript: used to send a list a message
 
# Hints

* The Upload script has to send back an object, otherwise the broadcast script won't be executed
* The integration parameters in the channel editor can consume a value like:

```
abc=def;xyz=123
```
Where this results in the input parameter of the powershell as two parameters: abc with the value def and xzy with the value 123
* If you want to throw exceptions during the upload or broadcast, use a line like this in PowerShell

```PowerShell
throw [System.IO.InvalidDataException] "No parameters!"  
```
![2019-12-18 00_42_47-Apteco PeopleStage - Handel](https://user-images.githubusercontent.com/14135678/71043688-4eefc900-2127-11ea-8249-8919fdd346e8.png)

* When an exception was thrown in the broadcast script and you use the option "repeat" the whole process, the upload and the broadcast will be repeated, even when the upload was successful. 

* The upload and broadcast return object create these entries in the broadcastsdetail and are only successful if they have delivered back a hashtable object:

![2019-12-18 00_47_47-demonstration apteco-faststats de - Remotedesktopverbindung](https://user-images.githubusercontent.com/14135678/71043782-a9892500-2127-11ea-8232-4c5224c4fb17.png)

* If all retries are set to "0" (in channel editor and in the delivery agent in the FastStats Configurator), an upload/broadcast will be retried 3x times, so 4x times in total.
