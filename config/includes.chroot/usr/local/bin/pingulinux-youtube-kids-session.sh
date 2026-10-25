#!/bin/bash
#
# pingulinux-youtube-kids-session.sh  (laeuft als root, via pkexec)
# Wird nach der Eltern-Freigabe gestartet und oeffnet YouTube Kids als das
# Kind im eigenen YouTube-Kids-Fenster (pingulinux-youtube-kids-viewer.py).
#
# Frueher wurde hier Firefox fuer das Kind freigegeben. Das Kind konnte dann
# in Firefox jede Seite aufrufen und Firefox auch ein zweites Mal starten.
# Das YouTube-Kids-Fenster ist kein Browser und zeigt nur YouTube Kids,
# deshalb wird Firefox nicht mehr angefasst.

[ -n "$PKEXEC_UID" ] || exit 2
U=$(id -nu "$PKEXEC_UID") || exit 2
HOME_DIR=$(getent passwd "$U" | cut -d: -f6)

exec runuser -u "$U" -- env HOME="$HOME_DIR" DISPLAY="$1" XAUTHORITY="$2" \
    XDG_RUNTIME_DIR="$3" DBUS_SESSION_BUS_ADDRESS="$4" \
    /usr/local/bin/pingulinux-youtube-kids-viewer.py
