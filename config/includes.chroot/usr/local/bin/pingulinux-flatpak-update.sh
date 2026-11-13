#!/bin/bash
#
# pingulinux-flatpak-update.sh  (bz22) – läuft als root, täglich per Timer
#
# Aktualisiert die Programme aus dem App Store, die als Flatpak installiert
# sind (systemweit). Vorher wird die tägliche Sicherung angelegt, falls fällig.

command -v flatpak >/dev/null 2>&1 || exit 0
[ -n "$(flatpak list --system --columns=application 2>/dev/null)" ] || exit 0
/usr/local/bin/pingulinux-timeshift-einrichten.sh >/dev/null 2>&1
LOG=/var/log/pingulinux-flatpak-update.log
{
    echo "=== $(date '+%d.%m.%Y %H:%M') ==="
    nice -n 19 ionice -c 3 flatpak update -y --noninteractive --system
    echo "rc=$?"
} >>"$LOG" 2>&1
exit 0
