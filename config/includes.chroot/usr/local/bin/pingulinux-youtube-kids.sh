#!/bin/bash
#
# pingulinux-youtube-kids.sh
# Oeffnet YouTube Kids als eigenes Fenster (Web-App).
# Kinderkonten (ohne Admin-Rechte) brauchen dafuer die Freigabe eines
# Erwachsenen (Administrator-Passwort). Das gilt auch fuer ganz kleine
# Kinder, die sonst keinen Browser starten duerfen: Die Freigabe gilt nur
# fuer diese eine YouTube-Kids-Sitzung.
# Admin-/Eltern-Konten starten direkt.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
URL="https://www.youtubekids.com/"

if id -nG | tr ' ' '\n' | grep -qx sudo || grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    exec firefox-esr --new-window "$URL"
fi

zenity --question --title="YouTube Kids" --width=420 --ok-label="Eltern-Freigabe" --cancel-label="Abbrechen" \
    --text="<big><b>YouTube Kids 📺</b></big>\n\nDas schaust du am besten zusammen mit Mama oder Papa.\nEin Erwachsener muss das Passwort eingeben." || exit 0

pkexec /usr/local/bin/pingulinux-youtube-kids-session.sh \
    "$DISPLAY" "${XAUTHORITY:-$HOME/.Xauthority}" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
RC=$?
if [ $RC -eq 126 ] || [ $RC -eq 127 ]; then
    zenity --error --title="YouTube Kids" --width=360 --text="⚠️ Die Freigabe hat nicht geklappt."
fi
