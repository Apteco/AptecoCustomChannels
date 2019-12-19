# Getting Started

1. Download all the files in a directoy
1. Put those files somewhere on your Apteco server where the faststats service is running or where that directoy can be read

# Setup

## Scripts

1. Open the file "flexmail__00__create_settings.ps1" and change your settings, especially your Flexmail client id, which is in the login object, currently written as "<clientid>"
1. Run that file and you will be asked for the Flexmail token. This one will be encrypted and only accessible by the server that runs that script. A "settings.json" file will be created in that directory as well as a "aes.key" file.

## Channel Editor

1. Open up your channel editor, create a new channel and choose "PowerShell". Username and Password are only dummy values. Please ensure the email address is overridden by "emailAddress" ![2019-12-19 18_35_20-Clipboard](https://user-images.githubusercontent.com/14135678/71195612-30541400-2286-11ea-8d20-c78410ec4e0e.png)
1. Change all the linked directories here. The integration parameters are multiple additional parameters that can be send to the PowerShell scripts. ![2019-12-19 18_40_08-Channel-Editor](https://user-images.githubusercontent.com/14135678/71195846-a6f11180-2286-11ea-82d6-915c10e2b5ac.png)
1. Add more variables here. Please ensure you use the standard parameter names from Flexmail https://flexmail.be/en/api/manual/type/12-emailaddresstype ![2019-12-19 18_41_56-](https://user-images.githubusercontent.com/14135678/71195967-e7508f80-2286-11ea-9726-4f01303e0d0c.png)
1. More variables can be added on the fly in the content element in the campaign or the campaign attributes. You can also use custom fields to refer to. The script will automatically handle existing custom fields. At the moment there are only string based custom fields allowed (no nested arrays).

# First Campaign

1. Create a normal campaign and choose your mailing in the delivery step and enter an ID of a source, that is available in Flexmail. If no source valid value is provided, the campaign will throw an exception and will stop and wait for the users interaction. ![2019-12-19 18_46_08-Apteco PeopleStage - Handel](https://user-images.githubusercontent.com/14135678/71196310-b58bf880-2287-11ea-9348-0bd5497f6e66.png)

1. The first time any of the scripts are getting called, a "flexmail.log" file will be created as well as an upload directoy where you can proove the uploaded files.

# Exceptions

* If no source valid value is provided, the campaign will throw an exception and will stop and wait for the users interaction.
![2019-12-19 18_19_10-Apteco PeopleStage - Handel](https://user-images.githubusercontent.com/14135678/71196433-fab02a80-2287-11ea-99f3-73d51a946d58.png)
