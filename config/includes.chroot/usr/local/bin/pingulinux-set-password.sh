#!/bin/bash
#
# pingulinux-set-password.sh  (als root, via pkexec)
# Aufruf: BENUTZER   -  das neue Passwort kommt ueber stdin.
# Gibt bei Fehlern eine verstaendliche Meldung auf stderr aus.

U="$1"
PW=$(cat)

[ -n "$U" ] && [ -n "$PW" ] || { echo "Benutzername oder Passwort fehlt."; exit 2; }
UID_N=$(id -u "$U" 2>/dev/null) || { echo "Das Konto '$U' gibt es nicht."; exit 3; }
if [ "$UID_N" -lt 1000 ] || [ "$UID_N" -ge 60000 ]; then
    echo "Für '$U' darf hier kein Passwort geändert werden."; exit 3
fi

if ! printf '%s:%s\n' "$U" "$PW" | chpasswd 2>/tmp/pingulinux-chpasswd.err; then
    echo "Das Passwort wurde nicht angenommen:"
    cat /tmp/pingulinux-chpasswd.err
    rm -f /tmp/pingulinux-chpasswd.err
    exit 4
fi
rm -f /tmp/pingulinux-chpasswd.err
exit 0
