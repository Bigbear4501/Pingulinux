#!/bin/bash
#
# pingulinux-timeshift-einrichten.sh  (be21)  – läuft als root
#
# Tägliche Systemsicherung mit Timeshift, ohne dass Eltern etwas einrichten
# müssen:
#   * Beim ersten Lauf nach der Installation wird Timeshift eingerichtet
#     (rsync-Modus auf der Systemplatte, täglich, die letzten 5 Stände).
#   * Danach prüft der Dienst jede Stunde („timeshift --check“), ob eine
#     neue Sicherung fällig ist, und löscht zu alte.
#
# Eltern-Einstellungen gehen vor: Hat schon jemand Timeshift eingerichtet
# (Sicherungs-Platte gewählt), wird nichts überschrieben.
# Gesichert wird das System, nicht die eigenen Dateien in /home.

CONF=/etc/timeshift/timeshift.json
STATE=/var/lib/pingulinux/sicherung-status
MIN_FREE_GB=15

mkdir -p /var/lib/pingulinux
status() { echo "$1" > "$STATE"; echo "Sicherung: $1"; }

grep -qw 'boot=live' /proc/cmdline && exit 0
command -v timeshift >/dev/null 2>&1 || { status "Timeshift fehlt"; exit 0; }

MARK=/var/lib/pingulinux/timeshift-von-pingulinux   # UUID, die Pingulinux selbst eingetragen hat

conf_uuid() {
    python3 -c "import json; print(json.load(open('$CONF')).get('backup_device_uuid',''))" 2>/dev/null
}
configured() {
    [ -f "$CONF" ] && [ -n "$(conf_uuid)" ]
}

# Von Pingulinux eingetragene Platte gibt es nicht mehr (z. B. neu installiert,
# Festplatte getauscht, System kopiert) → neu einrichten. Hat ein Erwachsener
# selbst eine andere Platte gewählt (USB), wird nichts angefasst.
if configured && [ -f "$MARK" ] && [ "$(conf_uuid)" = "$(cat "$MARK")" ] \
   && ! blkid -U "$(conf_uuid)" >/dev/null 2>&1; then
    echo "Sicherungs-Platte $(conf_uuid) nicht mehr da – richte neu ein."
    rm -f "$CONF"
fi

if ! configured; then
    FSTYPE=$(findmnt -no FSTYPE /)
    UUID=$(findmnt -no UUID /)
    if [ "$FSTYPE" = btrfs ] || [ -z "$UUID" ]; then
        status "Nicht eingerichtet (Dateisystem $FSTYPE) – bitte in Timeshift selbst einrichten"
        exit 0
    fi
    FREE_GB=$(df --output=avail -BG / | tail -1 | tr -dc '0-9')
    if [ "${FREE_GB:-0}" -lt "$MIN_FREE_GB" ]; then
        status "Nicht eingerichtet: zu wenig Platz (${FREE_GB} GB frei, mindestens ${MIN_FREE_GB} GB nötig)"
        exit 0
    fi
    mkdir -p /etc/timeshift
    cat > "$CONF" <<JSON
{
  "backup_device_uuid" : "$UUID",
  "parent_device_uuid" : "",
  "do_first_run" : "false",
  "btrfs_mode" : "false",
  "include_btrfs_home_for_backup" : "false",
  "include_btrfs_home_for_restore" : "false",
  "stop_cron_emails" : "true",
  "schedule_monthly" : "false",
  "schedule_weekly" : "false",
  "schedule_daily" : "true",
  "schedule_hourly" : "false",
  "schedule_boot" : "false",
  "count_monthly" : "2",
  "count_weekly" : "3",
  "count_daily" : "5",
  "count_hourly" : "6",
  "count_boot" : "5",
  "date_format" : "%Y-%m-%d %H:%M:%S",
  "exclude" : [
    "/home/**",
    "/root/**",
    "/var/cache/apt/archives/**",
    "/var/lib/flatpak/**",
    "/var/tmp/**",
    "/tmp/**"
  ],
  "exclude-apps" : []
}
JSON
    echo "$UUID" > "$MARK"
    status "Eingerichtet: täglich, die letzten 5 Stände"
fi

# Läuft schon eine Sicherung (z. B. „System jetzt sichern“ von Hand)?
# Dann diesmal nichts tun – sonst meldet Timeshift „Another instance …“
# und das Kontrollzentrum zeigt fälschlich einen Fehler.
if pgrep -x timeshift >/dev/null 2>&1; then
    echo "Timeshift läuft gerade schon – nächste Prüfung in einer Stunde."
    exit 0
fi

# Fällige Sicherung anlegen und zu alte löschen (macht Timeshift selbst)
if nice -n 19 ionice -c 3 timeshift --check --scripted >/var/log/pingulinux-sicherung.log 2>&1; then
    LAST=$(timeshift --list --scripted 2>/dev/null | awk '/^[0-9]+ +>/ {print $3}' | tail -1)
    status "OK${LAST:+ – letzte Sicherung: $LAST}"
else
    status "Fehler bei der letzten Prüfung – siehe /var/log/pingulinux-sicherung.log"
fi
exit 0
