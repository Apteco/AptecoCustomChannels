# Getting started

* Create the token through FastStats or another 2fa
* New tokens are only valid for 30 days, and they are getting refreshed automatically. But if you use cleverreach less than every 30 days, make sure you execute the `cleverreach__05__test.ps1` every day via a Windows Task.

# Responses

To find out which Broadcasts have been done through this integration, use the following statements on the response database

```SQL
SELECT *
FROM [dbo].[Broadcasts]
WHERE [Id] IN (
		SELECT DISTINCT [BroadcastId]
		FROM [dbo].[BroadcastsDetail]
		WHERE upper(Parameters) LIKE '%CUSTOMPROVIDER=CLVRBRCST%'
		)


SELECT *
FROM BroadcastsDetail
WHERE BroadcastId IN (
		SELECT DISTINCT [BroadcastId]
		FROM [dbo].[BroadcastsDetail]
		WHERE upper(Parameters) LIKE '%CUSTOMPROVIDER=CLVRBRCST%'
		)
```

The default `FastStats Email Response Gatherer` (FERGE) is compatible with this custom CleverReach integration. Before triggering FERGE, execute this query

```SQL
Update [dbo].[Broadcasts] set [Broadcaster] = 'CleverReach'
WHERE [Id] IN (
		SELECT DISTINCT [BroadcastId]
		FROM [dbo].[BroadcastsDetail]
		WHERE upper(Parameters) LIKE '%CUSTOMPROVIDER=CLVRBRCST%'
		)
```

E.g. this can be executed automatically if you use this script https://github.com/Apteco/HelperScripts/tree/master/scripts/housekeeping and put the query in a `.sql` file in a subfolder `prefix_rs`

Then set up ferge like

![grafik](https://user-images.githubusercontent.com/14135678/151584109-00c2f674-cdb7-4cce-ac94-9388d7ad152d.png)

and execute it like

```PowerShell
Start-Process "EmailResponseGatherer64.exe" -ArgumentList "D:\Scripts\CleverReach\FERGE\CleverReach_FERGE.xml" -WorkingDirectory "C:\Program Files\Apteco\FastStats Email Response Gatherer x64"
```

# Hints

if there is no list in the parameters (same name as the message) means an datelist upload, which will create a new list and being filled -> there is a clean script available to delete old lists
if there is a list in the parameters, all receivers are getting deactivated first, then an upsert is taken place, and then the mailing will be released
