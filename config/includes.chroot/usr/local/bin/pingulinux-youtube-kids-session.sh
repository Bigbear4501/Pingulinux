#!/bin/bash
#
# pingulinux-youtube-kids-session.sh  (laeuft als root, via pkexec)
# Wird nach der Eltern-Freigabe gestartet. Gibt Firefox fuer genau diese
# eine YouTube-Kids-Sitzung frei (auch wenn das Kind fuer den normalen
# Browser noch zu jung ist), startet YouTube Kids als das Kind und sperrt
# Firefox danach sofort wieder.

[ -n "$PKEXEC_UID" ] || exit 2
U=$(id -nu "$PKEXEC_UID") || exit 2
HOME_DIR=$(getent passwd "$U" | cut -d: -f6)
FF=$(readlink -f "$(command -v firefox-esr)")

setfacl -x u:"$U" "$FF" 2>/dev/null

runuser -u "$U" -- env HOME="$HOME_DIR" DISPLAY="$1" XAUTHORITY="$2" \
    XDG_RUNTIME_DIR="$3" DBUS_SESSION_BUS_ADDRESS="$4" \
    firefox-esr --new-window "https://www.youtubekids.com/"
RC=$?

# Sperre nach Alter sofort wieder setzen
/usr/local/bin/pingulinux-apply-all-ages.py
exit $RC
