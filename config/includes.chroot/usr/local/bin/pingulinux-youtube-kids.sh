#!/bin/bash
#
# pingulinux-youtube-kids.sh
# Öffnet YouTube Kids im eigenen YouTube-Kids-Fenster
# (pingulinux-youtube-kids-viewer.py). Das Fenster ist kein Browser und
# kann nur YouTube Kids zeigen.
#
# Alpha 3: Kinderkonten brauchen die Freigabe eines Erwachsenen (Passwort).
# Eltern-Konten und der Live-Modus starten direkt.
# Gibt es die Datei /etc/pingulinux/youtube-kids-ohne-passwort, starten
# auch Kinder direkt (geplant als Standard für Beta 1, mit Schalter im
# Kontrollzentrum).

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
VIEWER=/usr/local/bin/pingulinux-youtube-kids-viewer.py

is_parent() { id -nG | tr ' ' '\n' | grep -qx sudo; }

if [ -e /etc/pingulinux/youtube-kids-ohne-passwort ] || is_parent || grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    exec "$VIEWER"
fi

zenity --question --title="YouTube Kids" --width=420 --ok-label="Eltern-Freigabe" --cancel-label="Abbrechen" \
    --text="<big><b>YouTube Kids 📺</b></big>\n\nDas schaust du am besten zusammen mit Mama oder Papa.\nEin Erwachsener muss das Passwort eingeben." || exit 0

pkexec /usr/local/bin/pingulinux-youtube-kids-session.sh \
    "$DISPLAY" "${XAUTHORITY:-$HOME/.Xauthority}" "${XDG_RUNTIME_DIR:-/run/user/$(id -u)}" "${DBUS_SESSION_BUS_ADDRESS:-unix:path=/run/user/$(id -u)/bus}"
RC=$?
if [ $RC -eq 126 ] || [ $RC -eq 127 ]; then
    zenity --error --title="YouTube Kids" --width=360 --text="⚠️ Die Freigabe hat nicht geklappt."
fi
