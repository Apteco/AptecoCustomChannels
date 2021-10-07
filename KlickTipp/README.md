# Prerequisites

- Premium Klicktipp Package
- Apteco Orbit with WS, PS and RS database
- Apteco Administrator for setting up this channel
- Remote Access to Apteco Server for initial setup

- PeopleStage needs to be configured to fill the column `subscriberId`, if already present

# Notes

- There is no API rate limiting yet, and no bulk mode available, so every request is handled one after the other
- There is no chance to check the datatypes in Klicktipp yet so you need to ensure to deliver the data in the right format, following datatypes are available:
  - Zeile
  - Absatz
  - E-Mail-Adresse
  - Zahlen
  - URL
  - Datum
  - Zeit
  - Datum & Zeit
- This is an upload only channel, no field creation supported yet


# Channel Modes

## Tagging

Tags can be used for to filter the target groups for
 - Audiences (saved search in contact cloud which can be used in the next hiphens, too)
 - Email Campaigns ()
 - Follow-Up Campaigns (Email + SMS with delay after a specific events)
 - Birthday Follow-Up Campaign (Email + SMS / Triggered at same time, date is read from field)
 - Email Newsletter (one-shot emails)

But also trigger Outbounds, which contacts a webhooks endpoint with the data setup in the outbound

The tagging is using the email address as the identifier, so does not need the `subscriberId` here

If a subscriber gets a tag that it already have, then the update is still marked as successful.

To use tagging, please configure the integration parameter `mode=tags`

## Subscribing

Supported operations
- Subscribe
- Update
- Unsubscribe
- Delete

Other notes

- Subscribing a recipient triggers a DOI email that needs to be confirmed like here <br/>![grafik](https://user-images.githubusercontent.com/14135678/136199457-50da0eae-cfad-46fa-9c71-b157b6e3930a.png)
- Uploading an already subscribed recipient does not trigger the DOI again, but does update the fields that have been uploaded in this request
- The subscriber update needs the id of the subscriber to update that record
- The subscriber delete needs the id of the subscriber to delete that record
- Fields need to be created in Klicktipp before usage
- Fields then can be used for textual personalisation

# Response

- The reaction data of the subscriber cannot be mapped properly to automated mails and sms that went out
- So the subscribers data will get downloaded automatically once a day in JSON format and put into a database that can be read from FastStats Designer

