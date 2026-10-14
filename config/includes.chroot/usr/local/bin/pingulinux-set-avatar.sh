#!/bin/bash
#
# pingulinux-set-avatar.sh  (als root, via pkexec)
# Aufruf: BENUTZER BILDDATEI
# Setzt das Profilbild fuer den Anmeldebildschirm und den Desktop.
# Das Bild wird quadratisch zugeschnitten und auf 256x256 verkleinert.

U="$1"; IMG="$2"
[ -n "$U" ] && [ -f "$IMG" ] || { echo "Aufruf: $0 BENUTZER BILD"; exit 2; }
UID_N=$(id -u "$U" 2>/dev/null) || exit 3
[ "$UID_N" -ge 1000 ] || exit 3

OUT=/var/lib/AccountsService/icons/$U
TMP=$(mktemp /tmp/pingulinux-avatar.XXXXXX.png)
mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users

# Bild quadratisch zuschneiden und auf 256x256 verkleinern
python3 - "$IMG" "$TMP" <<'P' || cp -f "$IMG" "$TMP"
import sys
import gi
gi.require_version("GdkPixbuf", "2.0")
from gi.repository import GdkPixbuf
pb = GdkPixbuf.Pixbuf.new_from_file(sys.argv[1])
w, h = pb.get_width(), pb.get_height()
s = min(w, h)
pb = pb.new_subpixbuf((w - s) // 2, (h - s) // 2, s, s)
pb = pb.scale_simple(256, 256, GdkPixbuf.InterpType.BILINEAR)
pb.savev(sys.argv[2], "png", [], [])
P
chmod 644 "$TMP"

# 1) Offizieller Weg: AccountsService per D-Bus (aktualisiert dessen Zwischenspeicher)
DONE=0
for i in 1 2 3 4 5; do
    OBJ=$(busctl --system call org.freedesktop.Accounts /org/freedesktop/Accounts \
          org.freedesktop.Accounts FindUserByName s "$U" 2>/dev/null | awk '{print $2}' | tr -d '"')
    [ -z "$OBJ" ] && OBJ=$(busctl --system call org.freedesktop.Accounts /org/freedesktop/Accounts \
          org.freedesktop.Accounts CacheUser s "$U" 2>/dev/null | awk '{print $2}' | tr -d '"')
    if [ -n "$OBJ" ] && busctl --system call org.freedesktop.Accounts "$OBJ" \
          org.freedesktop.Accounts.User SetIconFile s "$TMP" >/dev/null 2>&1; then
        DONE=1; break
    fi
    sleep 1
done

# 2) Rueckfall: Dateien direkt schreiben und Dienst neu starten
if [ "$DONE" -ne 1 ]; then
    cp -f "$TMP" "$OUT"; chmod 644 "$OUT"
    F=/var/lib/AccountsService/users/$U
    if [ -f "$F" ]; then
        if grep -q '^Icon=' "$F"; then sed -i "s|^Icon=.*|Icon=$OUT|" "$F"; else sed -i "/^\[User\]/a Icon=$OUT" "$F"; fi
    else
        printf '[User]\nIcon=%s\nSystemAccount=false\n' "$OUT" > "$F"
    fi
    systemctl restart accounts-daemon 2>/dev/null || true
fi
[ -f "$OUT" ] || cp -f "$TMP" "$OUT"
chmod 644 "$OUT" 2>/dev/null

# ~/.face als zusaetzliche Quelle (Desktop)
HOME_DIR=$(getent passwd "$U" | cut -d: -f6)
if [ -d "$HOME_DIR" ]; then
    cp -f "$TMP" "$HOME_DIR/.face"
    chown "$U:$U" "$HOME_DIR/.face"
fi
rm -f "$TMP"
echo "Profilbild fuer $U gesetzt (D-Bus: $DONE)" >> /var/log/pingulinux-profile.log
exit 0
