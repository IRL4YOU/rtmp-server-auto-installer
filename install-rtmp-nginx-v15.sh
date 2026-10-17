#!/usr/bin/env bash
# IRL4YOU: geführte Nginx-RTMP-Installation auf einem frischen Ubuntu 26.04 / Debian 13.
set -Eeuo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
umask 077

STEP="Vorprüfung"
CONFIG_PENDING=0
NGINX_BACKUP=""
WORK_DIR=""
LOG_FILE=/var/log/irl4you-rtmp-install.log
LOG_READY=0
PROGRESS_PID=""
show_log_error() {
  if (( LOG_READY )) && [[ -s $LOG_FILE ]]; then
    printf '[FEHLER] Letzte Ausgaben aus %s:\n' "$LOG_FILE" >&2
    tail -n 12 "$LOG_FILE" >&2
    printf '[HINWEIS] Das vollständige Protokoll ist nur für Root lesbar. Vor dem Teilen auf vertrauliche Angaben prüfen.\n' >&2
  fi
}
run_quiet() {
  local exit_code
  "$@" >> "$LOG_FILE" 2>&1 || { exit_code=$?; return "$exit_code"; }
}
run_with_progress() {
  local label=$1 exit_code=0
  shift
  printf '  %s' "$label"
  (
    ticks=0
    while sleep 1; do
      printf '.'
      ((ticks+=1))
      if (( ticks % 50 == 0 )); then printf '\n  '; fi
    done
  ) &
  PROGRESS_PID=$!
  "$@" >> "$LOG_FILE" 2>&1 || exit_code=$?
  kill "$PROGRESS_PID" 2>/dev/null || true
  wait "$PROGRESS_PID" 2>/dev/null || true
  PROGRESS_PID=""
  printf '\n'
  return "$exit_code"
}
support_hint() {
  printf '\n[HILFE] Wenn etwas nicht klappt: Im IRL4YOU-Discord im Bereich "Streamsachen" einen Beitrag eröffnen.\n'
  printf 'Discord: https://discord.gg/7AQRAQAp4C\n'
  printf 'Bitte den betroffenen Schritt und die genaue Fehlermeldung oder die Ausgabe des Statusbefehls mitschicken.\n'
  printf '[WICHTIG] Stream-Key, vollständige RTMP-Adresse, Passwörter und Tokens vor dem Teilen unkenntlich machen.\n'
}
rollback_config() {
  if (( CONFIG_PENDING )) && [[ -n $NGINX_BACKUP && -f $NGINX_BACKUP ]]; then
    if cp -p "$NGINX_BACKUP" /etc/nginx/nginx.conf; then
      nginx -t >/dev/null 2>&1 && systemctl restart nginx >/dev/null 2>&1 || true
      printf '[HINWEIS] Vorherige Nginx-Konfiguration wurde wiederhergestellt.\n' >&2
    else
      printf '[FEHLER] Wiederherstellung fehlgeschlagen. Sicherung: %s\n' "$NGINX_BACKUP" >&2
    fi
  fi
}
on_error() {
  local status=$? line=$1
  trap - ERR
  rollback_config
  printf '\n[FEHLER] Schritt: %s (Zeile %s, Exit-Code %s). Installation gestoppt.\n' "$STEP" "$line" "$status" >&2
  show_log_error
  printf '[HINWEIS] Bereits installierte Pakete werden nicht automatisch entfernt.\n' >&2
  support_hint >&2
  exit "$status"
}
trap 'on_error "$LINENO"' ERR
cleanup() {
  if [[ -n $PROGRESS_PID ]]; then
    kill "$PROGRESS_PID" 2>/dev/null || true
    wait "$PROGRESS_PID" 2>/dev/null || true
  fi
  if [[ $WORK_DIR == /tmp/irl4you-rtmp.* && -d $WORK_DIR ]]; then
    rm -f -- "$WORK_DIR/nginx.conf" "$WORK_DIR/stat.xsl"
    rmdir -- "$WORK_DIR" 2>/dev/null || true
  fi
}
trap cleanup EXIT

step() { STEP=$1; printf '\n[%s] %s\n' "$2" "$STEP"; }
fail() { trap - ERR; rollback_config; printf '[FEHLER] %s\n' "$*" >&2; (( LOG_READY )) && printf '[HINWEIS] Protokoll: %s\n' "$LOG_FILE" >&2; support_hint >&2; exit 1; }
highlight() {
  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then printf '\033[1;36m%s\033[0m\n' "$1"; else printf '%s\n' "$1"; fi
}
color_line() {
  local color=$1 line=$2
  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then printf '\033[1;%sm%s\033[0m\n' "$color" "$line"; else printf '%s\n' "$line"; fi
}
show_next_steps() {
  printf '\n=== Nach dem Neustart prüfen ===\n'
  printf 'Erneut als Root anmelden (Ubuntu: sudo -i; Debian ohne sudo: su -).\n'
  color_line 36 'Statusbefehl: /usr/local/sbin/irl4you-rtmp-status'
  printf 'Der Befehl prüft Dienste, Nginx-Konfiguration, Listener und Firewall.\n'
  support_hint
}
prompt() {
  if [[ -t 1 && -z ${NO_COLOR:-} ]]; then printf '\033[1;33m%s\033[0m ' "$1"; else printf '%s ' "$1"; fi
}
ask_yes() {
  local answer
  while true; do
    prompt "$1 [j/n]:"
    IFS= read -r answer </dev/tty || fail "Eine Antwort konnte nicht gelesen werden."
    case "$answer" in
      j|J|ja|Ja|JA|y|Y|yes|YES) return 0 ;;
      n|N|nein|Nein|NEIN|no|NO) return 1 ;;
      *) printf '[HINWEIS] Bitte j oder n eingeben.\n' ;;
    esac
  done
}
ssh_ports() {
  local configured="" client_ip="" client_port="" server_ip="" connected_port=""
  if [[ -x /usr/sbin/sshd ]]; then
    configured=$(/usr/sbin/sshd -T 2>/dev/null | awk '$1 == "port" && $2 ~ /^[0-9]+$/ && $2 >= 1 && $2 <= 65535 {print $2}') || configured=""
  fi
  if [[ -n ${SSH_CONNECTION:-} ]]; then
    read -r client_ip client_port server_ip connected_port <<< "$SSH_CONNECTION"
    if [[ $connected_port =~ ^[0-9]+$ ]] && (( connected_port >= 1 && connected_port <= 65535 )); then
      configured+=$'\n'"$connected_port"
    fi
  fi
  printf '%s\n' "$configured" | awk 'NF' | sort -nu
}
valid_ipv4() {
  local ip=$1 octet
  local -a parts
  [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a parts <<< "$ip"
  for octet in "${parts[@]}"; do
    [[ $octet == 0 || $octet != 0* ]] || return 1
    (( 10#$octet <= 255 )) || return 1
  done
}
update_stats_template() {
  local target=/usr/share/nginx/html/stat.xsl current backup
  [[ -f $target && ! -L $target ]] || fail "Die Statistikvorlage fehlt oder ist ein Symlink; es wird nichts überschrieben."
  current=$(sha256sum "$target" | awk '{print $1}')
  case "$current" in
    d74db1f66f625c229fb1e3cbc1a2af56f3101c95b90d4a22aa7f694b3ad29fb0)
      printf '[OK] Aktuelle IRL4YOU-Statistikvorlage ohne Versionsanzeige ist bereits installiert.\n'
      ;;
    729bdc9541b787642c3da0c34dfae3ce3b51fd8ac387649b77aad2f581afcb64|92b6ff7c86bda1e8021d7dab76bc040bc3e50dd393088067381b17b4ee3e2332)
      WORK_DIR=$(mktemp -d /tmp/irl4you-rtmp.XXXXXX)
      run_quiet curl -fsSL --retry 3 https://raw.githubusercontent.com/IRL4YOU/rtmp-server-auto-installer/main/downloads/stat-v3.xsl -o "$WORK_DIR/stat.xsl"
      printf '%s  %s\n' 'd74db1f66f625c229fb1e3cbc1a2af56f3101c95b90d4a22aa7f694b3ad29fb0' "$WORK_DIR/stat.xsl" | sha256sum -c - >> "$LOG_FILE" 2>&1
      backup="$target.irl4you-backup-$(date +%Y%m%d-%H%M%S)"
      cp -p "$target" "$backup"
      install -o root -g www-data -m 0640 "$WORK_DIR/stat.xsl" "$target"
      printf '[OK] Statistikvorlage aktualisiert; Nginx-Konfiguration und Stream-Key bleiben unverändert. Sicherung: %s\n' "$backup"
      ;;
    *)
      fail "Die vorhandene Statistikvorlage ist angepasst oder unbekannt; sie wird nicht überschrieben."
      ;;
  esac
}
show_connection_details() {
  local server_host="" stream_key="" show_key=0 stats_mode="" allowed_ip="" noalbs_stats_url=""
  printf '\n=== Verbindung für OBS, Moblin und andere RTMP-Sender ===\n'
  while true; do
    prompt 'Öffentliche Server-IP oder Domain eingeben (Enter = Platzhalter):'
    IFS= read -r server_host </dev/tty || fail "Serveradresse konnte nicht gelesen werden."
    if [[ -z $server_host ]]; then server_host='DEINE-SERVER-IP'; break; fi
    if [[ $server_host =~ ^[A-Za-z0-9][A-Za-z0-9.-]{0,252}$ ]]; then break; fi
    printf '[HINWEIS] Bitte nur eine IPv4-Adresse oder einen Domainnamen ohne Protokoll und Port eingeben.\n'
  done
  printf '[HINWEIS] Den Stream-Key nicht in Screenshots, Videos oder Chats veröffentlichen.\n'
  if ask_yes 'Persönlichen Stream-Key für RTMP-Sender und NOALBS einmal sichtbar im Terminal anzeigen?'; then
    stream_key=$(sed -nE 's/^[[:space:]]*"([[:xdigit:]]{64})"[[:space:]]+1;[[:space:]]*$/\1/p' /etc/nginx/nginx.conf)
    if [[ ${#stream_key} -eq 64 ]]; then
      show_key=1
    else
      printf '[WARNUNG] Der Key konnte nicht eindeutig aus der Root-geschützten Nginx-Konfiguration gelesen werden.\n' >&2
    fi
  fi

  printf '\n=== Variante 1: Alles in einem Link (z. B. IRL Pro) ===\n'
  if (( show_key )); then
    if [[ $server_host != DEINE-SERVER-IP ]]; then
      color_line 32 "Vollständige RTMP-Adresse: rtmp://$server_host:1935/live/$stream_key"
    else
      printf '[HINWEIS] Für einen nutzbaren Link zuerst die echte Server-IP oder Domain eingeben.\n'
    fi
  else
    printf 'Vollständige RTMP-Adresse: ausgeblendet, weil sie den geheimen Stream-Key enthält.\n'
  fi
  printf 'Diesen Link nur verwenden, wenn die Sende-App ein einziges Feld für die komplette RTMP-Adresse hat.\n'

  printf '\n=== Variante 2: Zwei getrennte Felder (z. B. OBS oder Moblin) ===\n'
  color_line 36 "Server / URL: rtmp://$server_host:1935/live"
  if (( show_key )); then
    color_line 33 "Stream-Key: $stream_key"
  else
    printf 'Stream-Key: ausgeblendet; nur in der Root-geschützten Nginx-Konfiguration hinterlegt.\n'
  fi
  printf 'Server / URL und Stream-Key in die beiden entsprechenden Felder der Sende-App eintragen.\n'
  printf '[HINWEIS] Port 1935 und /live gehören zu diesem Server; /publish/live wird hier nicht verwendet.\n'

  stats_mode=$(sed -n '1p' /etc/irl4you-rtmp-statistik)
  allowed_ip=$(sed -n '2p' /etc/irl4you-rtmp-statistik)
  printf '\n=== RTMP-Statistik im Browser ===\n'
  case "$stats_mode" in
    lokal)
      noalbs_stats_url='http://127.0.0.1:8081/stat.xml'
      printf 'Sicherer Standard: Port 8081 ist nur direkt auf dem Server erreichbar.\n'
      color_line 36 'Direkt auf dem Server: http://127.0.0.1:8081/stat'
      color_line 36 'Im eigenen Browser nach PuTTY-Tunnel: http://127.0.0.1:18081/stat'
      printf 'PuTTY: Connection > SSH > Tunnels; Source port 18081, Destination 127.0.0.1:8081, Add. Danach die PuTTY-Verbindung neu öffnen.\n'
      printf 'NOALBS auf demselben Server (XML): http://127.0.0.1:8081/stat.xml\n'
      ;;
    feste-ip|oeffentlich)
      if [[ $server_host == DEINE-SERVER-IP ]]; then
        printf '[HINWEIS] Für direkte Statistik-Links zuerst die echte Server-IP oder Domain eingeben.\n'
      else
        noalbs_stats_url="http://$server_host:8081/stat.xml"
        color_line 36 "Statistikseite: http://$server_host:8081/stat"
        printf 'NOALBS-Statistik (XML): http://%s:8081/stat.xml\n' "$server_host"
      fi
      if [[ $stats_mode == feste-ip ]]; then
        printf 'Zugriff von außen nur von der freigegebenen IP %s; von anderen Geräten bleibt der Link gesperrt.\n' "$allowed_ip"
        color_line 36 'Im eigenen Browser alternativ nach PuTTY-Tunnel: http://127.0.0.1:18081/stat'
        printf 'PuTTY-Tunnel: Source port 18081, Destination 127.0.0.1:8081, Add; danach neu verbinden.\n'
      else
        printf '[WARNUNG] Die öffentliche Statistik kann während eines Streams den Stream-Key anzeigen.\n'
      fi
      ;;
    *)
      printf '[WARNUNG] Statistikmodus unbekannt; bitte /usr/local/sbin/irl4you-rtmp-status prüfen.\n'
      ;;
  esac

  printf '\n=== NOALBS: Werte für streamServer eintragen ===\n'
  color_line 36 'Typ: Nginx'
  if [[ -n $noalbs_stats_url ]]; then
    color_line 36 "Stats-URL: $noalbs_stats_url"
  else
    printf 'Stats-URL: noch nicht vollständig; den Installer erneut starten und die echte Server-IP oder Domain eingeben.\n'
  fi
  color_line 36 'Application: live'
  if (( show_key )); then
    color_line 33 "Key: $stream_key"
  else
    printf 'Key: ausgeblendet; für die kopierfertige Ausgabe denselben Installer erneut starten und die Key-Anzeige mit j bestätigen.\n'
  fi
  if [[ $stats_mode == lokal ]]; then
    printf '[HINWEIS] Diese Stats-URL funktioniert nur für NOALBS auf demselben Server; von außen ist Port 8081 gesperrt.\n'
  fi
  printf 'Diese Werte in NOALBS unter streamServer als statsUrl, application und key übernehmen.\n'
  unset stream_key
}

step "System, Rechte und vorhandene Dienste prüfen" "1/8"
(( EUID == 0 )) || fail "Bitte zuerst Root werden: Ubuntu sudo -i; Debian ohne sudo su -."
[[ -r /etc/os-release ]] || fail "/etc/os-release fehlt."
# shellcheck disable=SC1091
. /etc/os-release
case "${ID:-}:${VERSION_ID:-}" in
  ubuntu:26.04|debian:13) ;;
  *) fail "Freigegeben sind nur Ubuntu Server 26.04 und Debian 13. Erkannt: ${PRETTY_NAME:-unbekannt}." ;;
esac
command -v systemctl >/dev/null || fail "systemd wird benötigt."
command -v apt-get >/dev/null || fail "apt-get wird benötigt."
[[ -r /dev/tty ]] || fail "Eine interaktive SSH- oder Konsolensitzung wird benötigt."
: >> "$LOG_FILE"
chmod 0600 "$LOG_FILE"
LOG_READY=1
printf '\n=== IRL4YOU RTMP-Installer: %s ===\n' "$(date -Is)" >> "$LOG_FILE"
if [[ -e /usr/local/sbin/irl4you-rtmp-status ]]; then
  [[ -r /etc/nginx/nginx.conf && -r /etc/irl4you-rtmp-statistik ]] || fail "Eine vorhandene Installation ist unvollständig; es wird nichts überschrieben."
  grep -Fq 'on_publish http://127.0.0.1:8080/publish-auth;' /etc/nginx/nginx.conf || fail "Die vorhandene Nginx-Konfiguration gehört nicht zum IRL4YOU-Installer."
  printf '[OK] IRL4YOU-Installation ist bereits abgeschlossen; Nginx-Konfiguration und Stream-Key bleiben unverändert.\n'
  /usr/local/sbin/irl4you-rtmp-status || fail "Bitte zuerst den gemeldeten Dienstfehler beheben; es wurde nichts verändert."
  update_stats_template
  show_connection_details
  show_next_steps
  exit 0
fi
RESUME=0
if [[ -e /etc/nginx/nginx.conf ]]; then
  [[ -r /etc/irl4you-rtmp-statistik && -f /etc/fail2ban/jail.d/irl4you-rtmp-sshd.local ]] || fail "Eine vorhandene Nginx-Konfiguration wird nicht verändert. Dies ist kein fortsetzbarer IRL4YOU-Stand."
  grep -Fq 'on_publish http://127.0.0.1:8080/publish-auth;' /etc/nginx/nginx.conf || fail "Die vorhandene Nginx-Konfiguration gehört nicht zum fortsetzbaren IRL4YOU-Stand."
  [[ $(stat -c %a /etc/nginx/nginx.conf) == 600 ]] || fail "Die vorhandene Nginx-Konfiguration ist nicht nur für Root lesbar. Bitte zuerst prüfen."
  run_quiet nginx -t || fail "Vorhandene Nginx-Konfiguration ist ungültig."
  systemctl is-active --quiet nginx || fail "Nginx läuft nicht."
  mapfile -t INSTALLED_SETTINGS < /etc/irl4you-rtmp-statistik
  STATS_MODE=${INSTALLED_SETTINGS[0]:-}
  NOALBS_IP=${INSTALLED_SETTINGS[1]:-}
  case "$STATS_MODE" in
    lokal|oeffentlich) ;;
    feste-ip) valid_ipv4 "$NOALBS_IP" || fail "Gespeicherte NOALBS-IP ist ungültig." ;;
    *) fail "Gespeicherter Statistikmodus ist ungültig." ;;
  esac
  RESUME=1
  printf '[OK] Begonnene IRL4YOU-Installation erkannt; Nginx und Stream-Key bleiben unverändert. Fortsetzung ab Schritt 6.\n'
else
  [[ ! -e /etc/fail2ban/jail.d/irl4you-rtmp-sshd.local ]] || fail "Eine IRL4YOU-RTMP-Fail2Ban-Konfiguration ist bereits vorhanden."
  [[ ! -e /root/irl4you-rtmp-stream-key ]] || fail "Eine frühere IRL4YOU-Key-Datei ist bereits vorhanden; nichts wird überschrieben."
  if command -v ss >/dev/null 2>&1; then
    for port in 80 1935 8080 8081; do
      if ss -H -ltn | awk -v port="$port" '$4 ~ (":" port "$") {found=1} END {exit !found}'; then
        fail "TCP-Port $port ist bereits belegt. Installation nicht gestartet."
      fi
    done
  fi
  printf '[OK] %s auf %s; keine vorhandene Nginx-Konfiguration wird überschrieben.\n' "${PRETTY_NAME:-Linux}" "$(dpkg --print-architecture)"
fi

if (( RESUME == 0 )); then
step "Betriebssystem aktualisieren (Details im Protokoll)" "2/8"
export DEBIAN_FRONTEND=noninteractive
run_with_progress 'Paketlisten aktualisieren' apt-get update
run_with_progress 'Systemupdates installieren' apt-get upgrade -y --no-remove
if [[ -e /run/reboot-required || -e /var/run/reboot-required ]]; then
  fail "Ein Neustart ist nötig. Server neu starten und anschließend denselben Installer erneut ausführen."
fi
printf '[OK] Systemupdates abgeschlossen; kein automatischer Neustart.\n'

step "Nginx, RTMP-Modul und SSH-Schutz installieren (Details im Protokoll)" "3/8"
if [[ ${ID:-} == ubuntu ]] && ! apt-get -s --no-remove install -y libnginx-mod-rtmp >> "$LOG_FILE" 2>&1; then
  highlight "Das RTMP-Modul fehlt in den aktiven Paketquellen; offizielles Ubuntu-'universe' wird jetzt aktiviert."
  run_with_progress 'Ubuntu-Paketquellen vorbereiten' apt-get install -y software-properties-common
  run_with_progress 'Ubuntu-universe aktivieren' add-apt-repository -y universe
  run_with_progress 'Paketlisten erneut aktualisieren' apt-get update
fi
apt-get -s --no-remove install -y libnginx-mod-rtmp >> "$LOG_FILE" 2>&1 || fail "Das RTMP-Modul ist nicht installierbar. Paketquellen und Abhängigkeiten bitte prüfen."
printf '[OK] Paketverwaltung kann das RTMP-Modul installieren.\n'
run_with_progress 'RTMP-Pakete installieren' apt-get install -y nginx libnginx-mod-rtmp fail2ban python3-systemd curl ca-certificates openssl
command -v nginx >/dev/null || fail "Nginx ist nach der Paketinstallation nicht verfügbar."
command -v sha256sum >/dev/null || fail "sha256sum fehlt."
WORK_DIR=$(mktemp -d /tmp/irl4you-rtmp.XXXXXX)
run_quiet curl -fsSL --retry 3 https://raw.githubusercontent.com/IRL4YOU/rtmp-server-auto-installer/main/downloads/nginx.conf -o "$WORK_DIR/nginx.conf"
printf '%s  %s\n' '2f002720a152baffc3150142d7afaf7ac87dc6c5aa1bface5444a07465d3c4cc' "$WORK_DIR/nginx.conf" | sha256sum -c - >> "$LOG_FILE" 2>&1
run_quiet curl -fsSL --retry 3 https://raw.githubusercontent.com/IRL4YOU/rtmp-server-auto-installer/main/downloads/stat-v3.xsl -o "$WORK_DIR/stat.xsl"
printf '%s  %s\n' 'd74db1f66f625c229fb1e3cbc1a2af56f3101c95b90d4a22aa7f694b3ad29fb0' "$WORK_DIR/stat.xsl" | sha256sum -c - >> "$LOG_FILE" 2>&1
printf '[OK] Pakete installiert und beide Vorlagen mit Prüfsumme kontrolliert.\n'

step "Persönlichen Stream-Key und NOALBS-Zugriff festlegen" "4/8"
prompt '64-stelligen hexadezimalen Stream-Key verdeckt eingeben (Enter = neuen Key erzeugen):'
IFS= read -rs STREAM_KEY </dev/tty || fail "Key-Eingabe konnte nicht gelesen werden."
printf '\n'
KEY_GENERATED=0
if [[ -z $STREAM_KEY ]]; then
  STREAM_KEY=$(openssl rand -hex 32)
  KEY_GENERATED=1
  printf '[OK] Ein neuer zufälliger Key wurde erzeugt.\n'
else
  [[ $STREAM_KEY =~ ^[[:xdigit:]]{64}$ ]] || fail "Der Key muss genau 64 Zeichen aus 0–9 und a–f enthalten."
  printf '[OK] Persönlicher Key übernommen.\n'
fi
highlight 'Statistik für NOALBS: 1) nur dieser Server (sicherer Standard)  2) feste NOALBS-IPv4  3) öffentlich (Key kann sichtbar sein)'
prompt 'Auswahl [1] (Enter = nur dieser Server):'
IFS= read -r MODE_CHOICE </dev/tty || fail "NOALBS-Auswahl konnte nicht gelesen werden."
NOALBS_IP=""
case "${MODE_CHOICE:-1}" in
  1) STATS_MODE=lokal ;;
  2)
    STATS_MODE=feste-ip
    prompt 'Öffentliche IPv4-Adresse des NOALBS-Rechners:'
    IFS= read -r NOALBS_IP </dev/tty || fail "NOALBS-IP konnte nicht gelesen werden."
    valid_ipv4 "$NOALBS_IP" || fail "Ungültige IPv4-Adresse."
    ;;
  3)
    STATS_MODE=oeffentlich
    highlight 'WARNUNG: Die öffentliche Statistik kann während des Streams den Publish-Key verraten.'
    ask_yes 'Statistik wirklich ohne IP-Beschränkung veröffentlichen?' || fail "Öffentliche Statistik nicht bestätigt."
    ;;
  *) fail "Bitte 1, 2 oder 3 wählen." ;;
esac
printf '[OK] Statistikmodus: %s.\n' "$STATS_MODE"

step "Nginx sicher konfigurieren und starten" "5/8"
NGINX_BACKUP="/etc/nginx/nginx.conf.irl4you-backup-$(date +%Y%m%d-%H%M%S)"
cp -p /etc/nginx/nginx.conf "$NGINX_BACKUP"
CONFIG_PENDING=1
TEMPLATE=$(<"$WORK_DIR/nginx.conf")
TEMPLATE=${TEMPLATE/HIER_DEINEN_STREAM_KEY_EINTRAGEN/$STREAM_KEY}
TEMPLATE=${TEMPLATE/'        access_log /var/log/nginx/rtmp-auth-access.log;'/'        access_log off;'}
case "$STATS_MODE" in
  lokal)
    TEMPLATE=${TEMPLATE/'        listen 8081;'/'        listen 127.0.0.1:8081;'}
    ;;
  feste-ip)
    RULES=$(printf '        listen 8081;\n        allow 127.0.0.1;\n        allow %s;\n        deny all;' "$NOALBS_IP")
    TEMPLATE=${TEMPLATE/'        listen 8081;'/$RULES}
    ;;
esac
[[ $TEMPLATE != *HIER_DEINEN_STREAM_KEY_EINTRAGEN* ]] || fail "Der Key-Platzhalter wurde nicht ersetzt."
[[ $TEMPLATE != *rtmp-auth-access.log* ]] || fail "Das Authentifizierungsprotokoll konnte nicht deaktiviert werden."
printf '%s\n' "$TEMPLATE" > /etc/nginx/nginx.conf
chmod 0600 /etc/nginx/nginx.conf
unset TEMPLATE RULES
install -o root -g www-data -m 0640 "$WORK_DIR/stat.xsl" /usr/share/nginx/html/stat.xsl
run_quiet nginx -t
run_quiet systemctl enable --now nginx
run_quiet systemctl restart nginx
systemctl is-active --quiet nginx || fail "Nginx läuft nicht."
if (( KEY_GENERATED )); then
  printf '%s\n' "$STREAM_KEY" > /root/irl4you-rtmp-stream-key
  chmod 0600 /root/irl4you-rtmp-stream-key
fi
unset STREAM_KEY
printf '%s\n%s\n' "$STATS_MODE" "$NOALBS_IP" > /etc/irl4you-rtmp-statistik
chmod 0600 /etc/irl4you-rtmp-statistik
CONFIG_PENDING=0
printf '[OK] Nginx läuft. Publish-Key wurde nicht auf dem Bildschirm ausgegeben.\n'
printf '[OK] Vorherige Standardkonfiguration gesichert: %s\n' "$NGINX_BACKUP"
if (( KEY_GENERATED )); then
  printf '[HINWEIS] Der erzeugte Key liegt nur für Root lesbar in /root/irl4you-rtmp-stream-key. Nach Übernahme in den Sender kann diese zusätzliche Datei entfernt werden.\n'
fi
fi

update_stats_template

step "Fail2Ban für SSH aktivieren" "6/8"
install -d -m 0755 /etc/fail2ban/jail.d
printf '[sshd]\nenabled = true\nbackend = systemd\nmaxretry = 5\nfindtime = 10m\nbantime = 1h\n' > /etc/fail2ban/jail.d/irl4you-rtmp-sshd.local
chmod 0644 /etc/fail2ban/jail.d/irl4you-rtmp-sshd.local
run_quiet fail2ban-client -t
run_quiet systemctl enable --now fail2ban
run_quiet systemctl restart fail2ban
systemctl is-active --quiet fail2ban || fail "Fail2Ban läuft nicht."
for attempt in {1..20}; do
  if fail2ban-client status sshd >/dev/null 2>&1; then break; fi
  sleep 1
done
run_quiet fail2ban-client status sshd
printf '[OK] Fail2Ban überwacht SSH und startet automatisch.\n'

step "Lokale Firewall optional einrichten" "7/8"
if ask_yes 'UFW für SSH, RTMP und gegebenenfalls NOALBS einrichten und aktivieren?'; then
  SSH_PORTS=$(ssh_ports)
  printf 'Erkannte SSH-Port(s): %s\n' "${SSH_PORTS:-keine}"
  if [[ -z $SSH_PORTS ]] || ! ask_yes 'Stimmen diese SSH-Ports mit deiner aktuellen Verbindung überein?'; then
    prompt 'Tatsächlich verwendeten SSH-Port eingeben:'
    IFS= read -r MANUAL_SSH_PORT </dev/tty || fail "Kein SSH-Port angegeben; UFW bleibt unverändert."
    [[ $MANUAL_SSH_PORT =~ ^[0-9]{1,5}$ ]] || fail "Ungültiger SSH-Port; UFW bleibt unverändert."
    MANUAL_SSH_PORT=$((10#$MANUAL_SSH_PORT))
    (( MANUAL_SSH_PORT >= 1 && MANUAL_SSH_PORT <= 65535 )) || fail "Ungültiger SSH-Port; UFW bleibt unverändert."
    SSH_PORTS=$(printf '%s\n%s\n' "$SSH_PORTS" "$MANUAL_SSH_PORT" | awk 'NF' | sort -nu)
  fi
  run_with_progress 'Firewall-Paket installieren' apt-get install -y ufw
  run_quiet ufw default deny incoming
  run_quiet ufw default allow outgoing
  while IFS= read -r ssh_port; do run_quiet ufw allow "$ssh_port/tcp"; done <<< "$SSH_PORTS"
  run_quiet ufw allow 1935/tcp
  case "$STATS_MODE" in
    lokal) ;;
    feste-ip) run_quiet ufw allow from "$NOALBS_IP" to any port 8081 proto tcp ;;
    oeffentlich) run_quiet ufw allow 8081/tcp ;;
  esac
  run_quiet ufw --force enable
  LC_ALL=C run_quiet ufw status verbose
  printf '[OK] UFW aktiv. Teste eine zweite SSH-Anmeldung, bevor du diese Sitzung schließt.\n'
else
  printf '[WARNUNG] UFW blieb unverändert. SSH und RTMP müssen über eine andere Firewall passend geschützt und erreichbar sein.\n'
fi

step "Statusbefehl und nächste Schritte bereitstellen" "8/8"
install -d -m 0755 /usr/local/sbin
cat > /usr/local/sbin/irl4you-rtmp-status <<'STATUS'
#!/usr/bin/env bash
set -uo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"
(( EUID == 0 )) || { printf '[FEHLER] Bitte zuerst Root werden.\n' >&2; exit 2; }
result=0
printf 'IRL4YOU RTMP – Status nach der Installation\n'
[[ -r /etc/os-release ]] && { . /etc/os-release; printf 'System: %s\n' "${PRETTY_NAME:-unbekannt}"; }
printf 'Letzter Start: %s\n' "$(uptime -s 2>/dev/null || printf unbekannt)"
if [[ -r /etc/irl4you-rtmp-statistik ]]; then
  IFS= read -r mode < /etc/irl4you-rtmp-statistik || true
  printf 'NOALBS-Statistik: %s\n' "${mode:-unbekannt}"
fi
for service in nginx fail2ban; do
  enabled=$(systemctl is-enabled "$service" 2>/dev/null || true)
  active=$(systemctl is-active "$service" 2>/dev/null || true)
  printf '%s: Autostart %s | Zustand %s\n' "$service" "${enabled:-unbekannt}" "${active:-unbekannt}"
  [[ $enabled == enabled && $active == active ]] || result=1
done
nginx -t 2>&1 || result=1
fail2ban-client status sshd || result=1
printf '\nListener:\n'
ss -ltnp | grep -E ':1935|:8080|:8081' || result=1
printf '\nUFW:\n'
if command -v ufw >/dev/null; then LC_ALL=C ufw status verbose; else printf 'Nicht installiert.\n'; fi
if (( result == 0 )); then
  printf '\n[OK] RTMP, Nginx und SSH-Schutz sind aktiv.\n'
else
  printf '\n[FEHLER] Mindestens eine Prüfung braucht Aufmerksamkeit.\n'
fi
printf 'Mit freundlichen Grüßen\nIRL4YOU\n'
exit "$result"
STATUS
chmod 0755 /usr/local/sbin/irl4you-rtmp-status
bash -n /usr/local/sbin/irl4you-rtmp-status
/usr/local/sbin/irl4you-rtmp-status
printf '\n[HINWEIS] Die externe Firewall des Hosters/Routers wurde nicht automatisch geprüft.\n'
show_connection_details
show_next_steps
