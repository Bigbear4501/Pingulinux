#!/bin/bash
#
# pingulinux-cleanup.sh - Systembereinigung (Eltern-Kontrollzentrum)
# Raeumt ungenutzte Pakete, Zwischenspeicher, alte Protokolle und
# doppelte Programme (Debian-Paket UND Flatpak) auf.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
TITLE="Systembereinigung"

if grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    zenity --info --title="$TITLE" --width=400 --text="ℹ️ Im Live-Modus gibt es nichts aufzuräumen.\nDie Bereinigung funktioniert nach der Installation."
    exit 0
fi

zenity --question --title="$TITLE" --width=480 --ok-label="Aufräumen" --cancel-label="Abbrechen" \
    --text="<big><b>🧹 Pingu räumt auf</b></big>\n\n• nicht mehr benötigte Pakete entfernen\n• heruntergeladene Installationsdateien löschen\n• ungenutzte Flatpak-Teile entfernen\n• alte Protokolle löschen (älter als 7 Tage)\n• doppelte Programme beseitigen (Debian-Paket und Flatpak)\n• Vorschaubilder-Zwischenspeicher leeren\n\nDeine Dateien und Programme bleiben erhalten." || exit 0

FREE_BEFORE=$(df --output=avail -B1M / | tail -1 | tr -d ' ')

( pkexec /usr/local/bin/pingulinux-cleanup-worker.sh > /tmp/pingulinux-cleanup.log 2>&1; echo $? > /tmp/pingulinux-cleanup.rc ) &
PID=$!
( while kill -0 $PID 2>/dev/null; do echo "# Räume auf…"; sleep 2; done; echo 100 ) \
  | zenity --progress --pulsate --auto-close --no-cancel --title="$TITLE" --width=420 --text="Räume auf…"
wait $PID
rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null

FREE_AFTER=$(df --output=avail -B1M / | tail -1 | tr -d ' ')
GAINED=$((FREE_AFTER - FREE_BEFORE)); [ "$GAINED" -lt 0 ] && GAINED=0
if [ "$(cat /tmp/pingulinux-cleanup.rc 2>/dev/null)" = "0" ]; then
    zenity --info --title="$TITLE" --width=420 --text="✅ Fertig! Es wurden etwa <b>${GAINED} MB</b> Platz frei.\nFrei insgesamt: ${FREE_AFTER} MB."
else
    zenity --error --title="$TITLE" --width=460 --no-markup --text="⚠️ Beim Aufräumen ist etwas schiefgelaufen.

Die letzten Zeilen des Protokolls (/tmp/pingulinux-cleanup.log):

$(tail -n 8 /tmp/pingulinux-cleanup.log 2>/dev/null)"
fi
