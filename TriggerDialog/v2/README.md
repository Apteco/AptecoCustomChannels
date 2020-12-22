
* Replace the tags in `TriggerDialog__00__create_settings.ps1`

# Process

* In the `Delivery Step` in PeopleStage you will get a dropdown field that contains entries in this format: `34362 / 30449 / Kampagne A / Pausiert / EDIT`<br/>This is showing 5 informations
  * Campaign ID
  * Mailing ID
  * Campaign Name
  * Campaign State
  * Campaign Operation - Choose the operation you want to do on the campaign
* Choose `0 / 0 / New Campaign + Mailing / New / Create`
* Open the PeopleStage Preview Window and the campaign and the mailing will be created automatically, all fields from the campaign are automatically synced
* After that you need to login to TriggerDialog to finish the campaign/mailings settings like the format, the volume, field-mapping etc.
* When you have activated the campaign you can choose it in PeopleStage with an entry like `34362 / 30449 / Kampagne A / Aktiv / UPLOAD` and publish the campaign

* If you want to add more fields to the campaign/mailing, please log into TriggerDialog, pause the campaign and in PeopleStage you can see an entry like `34362 / 30449 / Kampagne A / Pausiert / EDIT`. When you open the preview window now, all fields are automatically synced again between PeopleStage and TriggerDialog
* If you want to delete a campaign, do it in the TriggerDialog UI or in PeopleStage navigate to the option `34362 / 30449 / Kampagne A / Pausiert / DELETE` and open the preview window to commit the change


# Datentypen

id|label
-|-
10|Text
20|Ganzzahl
30|Boolscher Wert
40|Datum
50|Bild
60|Bild-URL
70|Fließkommazahl
80|Postleitzahl
90|Ländercode

<br/>

# Felder

* If you have the chance in the channel editor and the content step, name your fields like the name or the synonyms

id|createdOn|changedOn|version|name|sortOrder|synonyms
-|-|-|-|-|-|-
1|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Firma|10|Firmenname,Company,Unternehmen,Firma,Company name
11|2020-11-25T17:21:05.000Z||0|Firma 2|12|Firmenname 2,Company 2,Unternehmen 2
12|2020-11-25T17:21:05.000Z||0|Firma 3|14|Firmenname 3,Company 3,Unternehmen 3
2|2019-11-18T16:16:26.000Z||0|Anrede|20|salutation,Anrede
3|2019-11-18T16:16:26.000Z||0|Titel|30|title,Titel
4|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Vorname|40|firstname,first name,first_name,Vorname
5|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Nachname|50|surname,lastname,last name,Name,family name,last_name,family_name,Nachname
13|2020-11-25T17:21:05.000Z||0|Adresszusatz|55|Additional address,Address suffix,Address supplement,address addendum
6|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Straße|60|Strasse,str,str.,street,st.,road,Straße,Street address
7|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Hausnummer|70|hnr,hausnr.,hausnr,haus-nr,haus nr.,Haus-Nummer,Hausnummer,Haus_Nr,Haus_Nr.,Haus_Nummer,house number,house no,house_number,street number,Haus-Nr.,numm...
10|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Postfach|75|post office box,po box,post_office_box,box number,po_box,box_number,Postfach
8|2019-11-18T16:16:26.000Z||0|PLZ|80|Postleitzahl,zip,zip code,zip-code,PLZ
9|2019-11-18T16:16:26.000Z|2019-11-18T16:16:26.000Z|1|Ort|90|Wohnort,Stadt,city,Gemeinde,municipality,Ort        

# TODO 

- [ ] Think about usage of response data and receiver download
- [ ] Fill debug input parameters properly