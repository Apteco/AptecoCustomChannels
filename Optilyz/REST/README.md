

# Setup on the application server

* Download the whole repository<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101184664-469edf80-3651-11eb-8429-bf2f1d6e5f2b.png)
* Put the scripts that you need to a directory on the application server
* Depending on your Windows security settings you maybe are not allowed to execute the downloaded PowerShell scripts. If this is the case, please go to the Properties of the files and unblock the scripts to allow the usage
* Execute `optilyz__00__create_settings.ps1` and enter your token from Optilyz
* If you want to test the communication, open `optilyz__10__getmailings.ps1`, set the debug mode to `$true` and execute it<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101185975-d2fdd200-3652-11eb-8605-fc2309deb6f4.png)


# Setup in PeopleStage

* Create a new channel with a name like `Print - Optilyz`<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101179826-08062680-364b-11eb-98f2-32b4b84cb8ad.png)<br/><br/>
* Choose `PowerShell` as the integration, username and password filled with dummy values, the email variable (the variable is not used for the print) and the message Content type like in the screenshot<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101180010-4dc2ef00-364b-11eb-83ac-155bc5c2cac0.png)<br/><br/>
* Make sure the Export is in `utf-8` and uses double quotes for string values<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101180089-6d5a1780-364b-11eb-9f62-c0c5176211c5.png)<br/><br/>
* Setup your parameters like in the screenshot and make sure you refer to the correct files<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101180279-aa260e80-364b-11eb-95cf-29c1b4a74bc5.png)<br/><br/>
* Setup the variables and change the descriptions in the second column so they fit to the ones from Optilyz<br/><br/>
![grafik](https://user-images.githubusercontent.com/14135678/101180389-ce81eb00-364b-11eb-8be8-28813656d0f4.png)<br/><br/>See the chapter `Field Mapping` for more information<br/><br/>
* The first campaign then can look like this<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101180518-fa9d6c00-364b-11eb-9a15-707d41cadb08.png)<br/><br/>
* In the content step you can use `individualisation1`, `individualisation2`, etc. as many times as you want; use `variation` to choose the variation of the Optilyz automation (e.g. 1 for the female variation, 2 for the male variation)<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101180979-97f8a000-364c-11eb-84bd-a7bd8ec88ea0.png)<br/><br/>
* Then you can choose the Optilyz automation where the data should be uploaded to<br/><br/>![grafik](https://user-images.githubusercontent.com/14135678/101181107-caa29880-364c-11eb-8592-8dcb9ce157ad.png)<br/><br/>

## Field Mapping

The information here is referring to the api documentation of Optilyz: https://www.optilyz.com/doc/api/#api-Recipients-EnqueueMultipleRecipient

Following fields are can be used in PeopleStage in connection with Optilyz:

Field|Optional
-|-
title|x
otherTitles|x 	
jobTitle|x 	
gender|x
companyName1|x 	
companyName2|x 	
companyName3|x
individualisation1|x
individualisation2|x
individualisation3|x
careOf|x
firstName|x
lastName|
fullName|
houseNumber|
street|
address1|
address2|x
zipCode|
city|
country|x
<br/>

Notes:
* `Individualisation` appended with a number can be used infinitely
* You have to define
  * `fullName` OR<br/>`firstName` and `lastName`
  * `address1` OR<br/>`street` and `houseNumber`
* If no `variation` is provided in the campaign, then the variation will be chosen by random