

# Get Started

* Create settings
* Replace those tokens in epi__00__create_settings.ps1
<mandantid>
<apiuser>
<masterlistid>
* Execute that file to create the settings

# Debugging
* To get the detailed message for the http500, and PowerShell only allows us those messages since PSCore6 or when the exception is thrown, it is sometimes easier, to test the soap calls in a Rest client like Postman. To get this done, you need to make sure, the function ```Invoke-Epi``` is called with the parameter ```-writeCallToFile = "c:\test.xml"```. Then you get the xml. This one you can paste 1:1 into the body of the REST call, choose the POST method, then create a header named ```SOAPACTION``` and a value of the soap call like ```addall3``` and you are good to go. Please be quick, because the tokens of Epi do expire after 20 minutes. 