#!/bin/bash
#
# pingulinux-reset-hinweis.sh – beim Anmelden
#
# Wurde ein Eltern-Passwort vom USB-Stick aus zurückgesetzt
# (pingulinux-passwort-zuruecksetzen.sh), sehen das alle Eltern beim
# nächsten Anmelden einmal. Waren sie es nicht selbst, merken sie es sofort.
LOG=/var/lib/pingulinux/passwort-zurueckgesetzt.log
SEEN="$HOME/.local/state/pingulinux/passwort-hinweis-gesehen"
[ -s "$LOG" ] || exit 0
id -nG "$USER" | tr ' ' '\n' | grep -qx sudo || exit 0     # nur Eltern
last=$(cat "$SEEN" 2>/dev/null || echo 0)
msg=""; newest=$last
while IFS='|' read -r ts user; do
    [[ "$ts" =~ ^[0-9]+$ ]] || continue
    [ "$ts" -gt "$last" ] || continue
    msg+="• <b>$user</b> am $(date -d "@$ts" '+%d.%m.%Y um %H:%M') Uhr\n"
    [ "$ts" -gt "$newest" ] && newest=$ts
done < "$LOG"
[ -n "$msg" ] || exit 0
sleep 8   # erst nach dem Aufbau des Schreibtischs
. /usr/local/lib/pingulinux/dialog.sh
pd_info "Sicherheits-Hinweis" "⚠️ <b>Ein Eltern-Passwort wurde vom USB-Stick aus zurückgesetzt:</b>\n\n$msg\nWart ihr das nicht selbst? Dann hat jemand den Computer vom Stick gestartet.\nTipp: BIOS-Passwort setzen und den Start vom USB-Stick abschalten (siehe Eltern-FAQ)." "Verstanden"
mkdir -p "$(dirname "$SEEN")" && echo "$newest" > "$SEEN"
