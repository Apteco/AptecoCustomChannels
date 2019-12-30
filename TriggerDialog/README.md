# Dependencies

* Make sure PS Version 5.1 is installed at Minimum (which is normally pre-installed with Windows Server)
  * You can see it in Powershell if you type in ```$PSVersionTable```
  * If PSVersion < 5.1, then install this one: https://www.microsoft.com/en-us/download/details.aspx?id=54616
  * And restart the machine

# Getting Started

1. Download all the files in a directoy
1. Put those files somewhere on your Apteco server where the faststats service is running or where that directoy can be read

# Setup

## Scripts

* Open the file "TriggerDialog__00__create_settings.ps1" and change your settings, especially the following tags<br/>
~~~
<accountname/>
<issuer/>
<masId/> 
<clientid/>
<username/>
<email/>
<firstname/>
<lastname/>
~~~
* Run that file and you will be asked for the TriggerDialog secret and your password. This one will be encrypted and only accessible by the server that runs that script. A "settings.json" file will be created in that directory as well as a "aes.key" file.

## Channel Editor

1. Open up your channel editor, create a new channel and choose "PowerShell". Username and Password are only dummy values.

# First Campaign

* Execute the file `TriggerDialog__91__create_auth_url_to_login.ps1` to get automatically logged into TriggerDialog and to see if the login with a jwt token is working
![TriggerDialog_UI](https://user-images.githubusercontent.com/14135678/71591590-d7f20180-2b24-11ea-9a14-a6010a3ec26e.gif)
* Create the first campaign via `TriggerDialog__92__create_campaign.ps1`, have a look at it in the browser, put your creative content in there and then you are able to use and automate this campaign via Apteco PeopleStage. 

# Exceptions

# Hints

# Next steps

- [ ] Implementation of SAML
