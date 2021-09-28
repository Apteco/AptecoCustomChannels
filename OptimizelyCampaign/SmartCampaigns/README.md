
# Setup

## Server

* Edit the file "epi__00__create_settings.ps1"
  * Replace the tokens
    * <mandantid>
    * <username>
  * Check the default settings in the file if you want to change something
* Execute the file "epi__00__create_settings.ps1" and follow the questions
* The script will create three files
  * aes.key
  * session.json
  * settings.json

## Channel in PeopleStage

# Response

* [ ] Add Screenshots and FERGE xml example


# Process

When PeopleStage triggers a SmartCampaign in EpiServer Campaign, the process is as follows

* A SmartCampaign ID is used as to create a new wave ID
* The data will be uploaded with the wave ID
* When the upload is finished, a mailing will be triggered by EpiServer
* Then the wave ID will be exchanged with a compound mailing ID
* The response data will deliver back the compound mailing ID as well as the single mailing IDs

Hints:
* A SmartCampaign can contain multiple mailings (e.g. a 50/50 split) which means a mailing ID is not always 1:1 the compound mailing ID
* Only SmartCampaigns with status "Activation required" can be used to actively send out mails
