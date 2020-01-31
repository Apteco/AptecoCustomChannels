

# Get Started

* Create settings
* Replace those tokens in epi__00__create_settings.ps1
<mandantid>
<apiuser>
* Execute that file to create the settings

* To manage recipient lists in EpiServer (which is not able through the online UI), execute "epi__01__manage_lists_manually.ps1" where you can copy lists and much more

# Hints

* Transactional Mailing are always single mailings consisting of a recipient list and a mailing
* Transactional Mailing can contain multiple recipient lists
* A Marketing Automation Process contains 1..n transactional mailings. This process sets the trigger for new recipient entries in a specific list.