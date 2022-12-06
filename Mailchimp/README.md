Note that this integration was demonstrated at a focus group at Apteco Live 2022.  It is a sample integration that works as-is but hasn't been rigourously tested in a production environment.  Further enhancements may be required to work in a production setting.

All template campaigns should be defined in a folder called "Templates" in Mailchimp

# Dependencies

* Make sure PS Version 5.1 is installed at Minimum (which is normally pre-installed with Windows Server)
  * You can see it in Powershell if you type in ```$PSVersionTable```
  * If PSVersion < 5.1, then install this one: https://www.microsoft.com/en-us/download/details.aspx?id=54616
  * And restart the machine

# Getting Started

1. Download all the files in a directoy
1. Put those files somewhere on your Apteco server where the faststats service is running or where that directoy can be read

# Setup

## Channel Editor

1. Open up your channel editor, create a new channel and choose "PowerShell". Enter the Mailchimp "server prefix" for your account (see https://mailchimp.com/developer/marketing/guides/quick-start/#make-your-first-api-call) as the username and your API key as the password.
1. For all of the available Mailchimp scripts that were copied to the server above, add their full path into the corresponding settings on the Parameters tab of the channel editor.
1. The `IntegrationParameters` parameter can have settings to control whether a debug file is written when calls are made to the Mailchimp API and the location of the directory containing the scripts.  If the path on the Apteco server where the scripts have been copied was `C:\FastStats\Mailchimp-scripts\` then the value for `IntegrationParameters` might be:
```DebugFile=C:\temp\mailchimp_debug.txt;ScriptRoot=C:\FastStats\Mailchimp-scripts```
1. Add any extra variables to the Additional Variables tab in the channel editor.  The descriptions of the variables should match any merge tags defined in Mailchimp (see https://mailchimp.com/en-gb/help/getting-started-with-merge-tags/).
