#!/bin/bash
#
# pingulinux-cleanup.sh - Systembereinigung (Eltern-Kontrollzentrum)
# Raeumt ungenutzte Pakete, Zwischenspeicher, alte Protokolle und
# doppelte Programme (Debian-Paket UND Flatpak) auf.

. /usr/local/lib/pingulinux/dialog.sh
TITLE="Systembereinigung"

if grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    pd_info "$TITLE" "ℹ️ Im Live-Modus gibt es nichts aufzuräumen.\nDie Bereinigung funktioniert nach der Installation."
    exit 0
fi

pd_frage "$TITLE" "<big><b>🧹 Pingu räumt auf</b></big>\n\n• nicht mehr benötigte Pakete entfernen\n• heruntergeladene Installationsdateien löschen\n• ungenutzte Flatpak-Teile entfernen\n• alte Protokolle löschen (älter als 7 Tage)\n• doppelte Programme beseitigen (Debian-Paket und Flatpak)\n• Vorschaubilder-Zwischenspeicher leeren\n\nDeine Dateien und Programme bleiben erhalten." "Aufräumen" "Abbrechen" || exit 0

FREE_BEFORE=$(df --output=avail -B1M / | tail -1 | tr -d ' ')

run_cleanup() { pkexec /usr/local/bin/pingulinux-cleanup-worker.sh > /tmp/pingulinux-cleanup.log 2>&1; }
pd_warten "$TITLE" "Räume auf…" run_cleanup
echo $? > /tmp/pingulinux-cleanup.rc
rm -rf "$HOME/.cache/thumbnails"/* 2>/dev/null

FREE_AFTER=$(df --output=avail -B1M / | tail -1 | tr -d ' ')
GAINED=$((FREE_AFTER - FREE_BEFORE)); [ "$GAINED" -lt 0 ] && GAINED=0
if [ "$(cat /tmp/pingulinux-cleanup.rc 2>/dev/null)" = "0" ]; then
    pd_info "$TITLE" "✅ Fertig! Es wurden etwa <b>${GAINED} MB</b> Platz frei.\nFrei insgesamt: ${FREE_AFTER} MB."
else
    pd_fehler_roh "$TITLE" "⚠️ Beim Aufräumen ist etwas schiefgelaufen.

Die letzten Zeilen des Protokolls (/tmp/pingulinux-cleanup.log):

$(tail -n 8 /tmp/pingulinux-cleanup.log 2>/dev/null)"
fi
