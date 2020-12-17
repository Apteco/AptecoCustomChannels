# Getting started

* Create the token through FastStats or another 2fa
* New tokens are only valid for 30 days, and they are getting refreshed automatically. But if you use cleverreach less than every 30 days, make sure you execute the `cleverreach__05__test.ps1` every day via a Windows Task.



# Hints

if there is no list in the parameters (same name as the message) means an datelist upload, which will create a new list and being filled -> there is a clean script available to delete old lists
if there is a list in the parameters, all receivers are getting deactivated first, then an upsert is taken place, and then the mailing will be released
