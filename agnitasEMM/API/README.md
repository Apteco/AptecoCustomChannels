
# Prozess

Unterstützt werden folgende Funktionalitäten

Feature|Unterstützt
-|-
Auswahl Mailings|x
Auswahl Zielgruppen|x
Upload|x
PrepareMailing|x
Broadcast|x
Vorschau|
Test-Versand|
Response-Download|
Response-Matching|


## Modi

- Upload Only
- Upload + Prepare Mailing
- Upload + Prepare Mailing + Broadcast

# Agnitas EMM an Apteco PeopleStage/Orbit verbinden

## Voraussetzungen

- Apteco-Server (einer oder mehrere) mit Apteco Response Gatherer
- RDP- oder PowerShell-Zugriff zum Apteco-Server mit FastStats Service
- SFTP-Server zum Austausch der Dateien. Zugriff via Benutzername/Password oder Benutzername/PrivateKey unterstützt. Bitte den Host-Fingerprint vom SFTP-Server bereithalten. Dies kann z.B. mit WinSCP oder FileZilla ausgelesen werden und hat z.B. ein Format wie `ssh-ed25519 255 yrt1ZYQO/YULXZ/IXS...` oder `ssh-rsa 2048 xxxxxxxxxxx...`
  - Auf dem SFTP-Server sollten zwei Verzeichnisse in der root liegen: `import` und `archive`
- Zugriff auf Agnitas EMM via **UI**, aber auch **REST** und **SOAP**. Dies sind in der Regel unterschiedliche Benutzer.
- Ein fertig konfigurierter Auto-Import in Agnitas (siehe `Konfiguration Agnitas EMM`)

## Konfiguration Agnitas EMM

- Anlage Auto-Import, bitte ID notieren

## Konfiguration Apteco

- Herunterladen vom Code von Github
  - via Oberfläche - SCREENSHOT EINFÜGEN
  - via PowerShell-Befehl `LINK EINFÜGEN`
- Kopieren der Dateien in einen beliebigen Ordner, auf den der Windows-Benutzer von FastStats Service Zugriff hat
- Ausführen der Datei `agnitas__00__create_settings.ps1` <br/><br/>
- Während der Ausfragen werden unterschiedliche Zugangsdaten abgefragt. Die Voraussetzungen sind im vorherigen Kapitel aufgelistet. Weiterhin werden während des Vorgangs weitere Dateien nachgeladen bzw. man wird dazu aufgefordert

If you add the integartion parameter `;mode=send`, the mailing will be copied, connected with the targetgroup and send directly, otherwise it will do all of this, but not send in the end, so you can trigger it manually


--- 

# Notizen zum Einbauen

New file

Die Konfiguration der Kanäle ist hier in PeopleStage gezeigt, wird aber zukünftig in Orbit ermöglicht.


Notwendige Premium Features:

- Automation Package
- Auto-Import
- Reaktionen
- REST


# Schritte

Importprofil anlegen
Auto-Import anlegen

Datumsgesteuertes Mailing (jeder Tag zur gleichen Uhrzeit) oder Intervallgesteuertes Mailing

Auto-Export anlegen

