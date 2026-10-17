# IRL4YOU RTMP Auto-Installer

Dieses Repository enthält ausschließlich den **RTMP Auto-Installer**. SRTLA ist ein eigenständiges Projekt und gehört nicht hierher.

Die Version `v15` wurde bei einer Neuinstallation auf Ubuntu 26.04 LTS und Debian 13 (jeweils amd64) praktisch getestet. Ein RTMP-Teststream wurde ebenfalls durchgeführt. Seit der Umstellung des Downloads von der Webseite auf dieses Repository ist nur die Adresse der Vorlagen geändert (Prüfsummen unverändert); ein vollständiger Neutest steht noch aus.

## Praxisvideo

- [Praxisvideo auf YouTube](https://youtu.be/e_WPA0VonDw) – Installation von RTMP und SRTLA; dieses Repository enthält ausschließlich den RTMP-Installer

## Inhalt

- `downloads/install-rtmp-nginx-v15.sh`: interaktiver Installer und Statusprüfung
- `downloads/nginx.conf`: Nginx-/RTMP-Konfigurationsvorlage mit Key-Platzhalter
- `downloads/stat-v3.xsl`: HTML-Ansicht der RTMP-Statistik
- `SHA256SUMS`: Prüfsummen genau dieser drei Dateien

Der Installer lädt die beiden Vorlagen (`nginx.conf`, `stat-v3.xsl`) von diesem Repository (`raw.githubusercontent.com`, Ordner `downloads`) und prüft ihre fest eingebauten SHA-256-Werte. Eine Kopie dieses Verzeichnisses allein ist daher **kein Offline-Installer**; das Repository muss öffentlich erreichbar sein. Änderungen an einer Vorlage erfordern eine neue Prüfsumme und eine neue getestete Installer-Version.

**Installieren** (als Root auf einem frischen Ubuntu 26.04 oder Debian 13, interaktive Sitzung):

```sh
curl -fsSL https://raw.githubusercontent.com/IRL4YOU/rtmp-server-auto-installer/main/downloads/install-rtmp-nginx-v15.sh -o install-rtmp.sh && bash install-rtmp.sh
```

Nginx, das RTMP-Modul und weitere Systempakete sind hier nicht enthalten. Sie werden auf dem Zielsystem über dessen Paketverwaltung installiert. Persönliche Stream-Keys, Serverdaten und Installationsprotokolle gehören nicht in dieses Repository.

## Lizenz und Fremdkomponenten

Die IRL4YOU-Dateien in diesem Repository stehen unter der [BSD-2-Clause-Lizenz](LICENSE). Hinweise zum separat installierten Nginx-/RTMP-Modul und der vorsorglich beigefügte Lizenzhinweis für dessen Statistikvorlage stehen in [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md). Dieses Repository enthält keine Nginx- oder RTMP-Modul-Binärdateien.
