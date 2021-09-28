

# Get Started

* Create settings
* Replace those tokens in epi__00__create_settings.ps1
<mandantid>
<apiuser>
* Execute that file to create the settings
* Popup to exclude fiels with recommendations like "Urn"
* To manage recipient lists in EpiServer (which is not able through the online UI), execute "epi__01__manage_lists_manually.ps1" where you can copy lists and much more

# Hints

* Transactional Mailing are always single mailings consisting of a recipient list and a mailing
* Transactional Mailing can contain multiple recipient lists
* A Marketing Automation Process contains 1..n transactional mailings. This process sets the trigger for new recipient entries in a specific list.
* Be aware to fill **all** numerical values for the upload with 0, otherwise the api call will be canceled with a http500 code

# How To in Epi

* [ ] Add more screenshots here
* Create an Email Template
* Create a Transactional Mailing refering to that template
* Create a Marketing Automation refering to that Transactional Mailing

# Next steps

* [ ] Implement email html preview
* [ ] Implement test connection