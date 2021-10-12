New file


Notwendige Premium Features

Auto-Import


Schritte

Importprofil anlegen
Auto-Import anlegen

Datumsgesteuertes Mailing (jeder Tag zur gleichen Uhrzeit) oder Intervallgesteuertes Mailing

Auto-Export anlegen

## Voraussetzungen

- Apteco-Server (einer oder mehrere)
- RDP- oder PowerShell-Zugriff zum Apteco-Server mit FastStats Service
- SFTP-Server zum Austausch der Dateien. Zugriff via Benutzername/Password oder Benutzername/PrivateKey unterstützt. Bitte den Host-Fingerprint vom SFTP-Server bereithalten. Dies kann z.B. mit WinSCP oder FileZilla ausgelesen werden und hat z.B. ein Format wie `ssh-ed25519 255 yrt1ZYQO/YULXZ/IXS...` oder `ssh-rsa 2048 xxxxxxxxxxx...`
- Zugriff auf Agnitas EMM via **UI**, aber auch **REST** und **SOAP**. Dies sind in der Regel unterschiedliche Benutzer.

## Konfiguration

- Herunterladen vom Code von Github
  - via Oberfläche - SCREENSHOT EINFÜGEN
  - via PowerShell-Befehl `LINK EINFÜGEN`
- Kopieren der Dateien in einen beliebigen Ordner, auf den der Windows-Benutzer von FastStats Service Zugriff hat
- Ausführen der Datei `agnitas__00__create_settings.ps1` <br/><br/>
- Während der Ausfragen werden unterschiedliche Zugangsdaten abgefragt. Die Voraussetzungen sind im vorherigen Kapitel aufgelistet. Weiterhin werden während des Vorgangs weitere Dateien nachgeladen bzw. man wird dazu aufgefordert