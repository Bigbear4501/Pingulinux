#!/bin/bash
#
# pingulinux-youtube-kids.sh
# Öffnet YouTube Kids im eigenen YouTube-Kids-Fenster
# (pingulinux-youtube-kids-viewer.py). Das Fenster ist kein Browser und
# kann nur YouTube Kids zeigen.
#
# Starten auch Kinder direkt: Die Datei
# /etc/pingulinux/youtube-kids-ohne-passwort liegt in der ISO.
# Wird sie gelöscht, brauchen Kinderkonten wieder die Freigabe eines
# Erwachsenen (Passwort). Eltern-Konten und der Live-Modus starten immer
# direkt. Schalter im Kontrollzentrum folgt.

. /usr/local/lib/pingulinux/dialog.sh
VIEWER=/usr/local/bin/pingulinux-youtube-kids-viewer.py

is_parent() { id -nG | tr ' ' '\n' | grep -qx sudo; }

if [ -e /etc/pingulinux/youtube-kids-ohne-passwort ] || is_parent || grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    exec "$VIEWER"
fi

pd_frage "YouTube Kids" "<big><b>YouTube Kids 📺</b></big>\n\nDas schaust du am besten zusammen mit Mama oder Papa.\nEin Erwachsener muss das Passwort eingeben." "Eltern-Freigabe" "Abbrechen" || exit 0

pkexec /usr/local/bin/pingulinux-youtube-kids-session.sh \
    "$DISPLAY" "${XAUTHORITY:-$HOME/.Xauthority}" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
RC=$?
if [ $RC -eq 126 ] || [ $RC -eq 127 ]; then
    pd_fehler "YouTube Kids" "⚠️ Die Freigabe hat nicht geklappt."
fi
