#!/bin/bash
#
# pingulinux-standard-profilbild.sh  (t3) – läuft als root beim Start
#
# Jedes Konto ohne eigenes Profilbild bekommt Pingu – auch das Eltern-Konto,
# das der Installer angelegt hat. Sonst zeigt der Anmeldebildschirm (SDDM)
# dort nur ein graues Standard-Symbol.
# Konten mit eigenem Bild (Kinder, oder in KDE selbst gewählt) bleiben, wie
# sie sind.
PINGU=/usr/share/pingulinux/icons/pingu.png
[ -f "$PINGU" ] || exit 0
grep -qw 'boot=live' /proc/cmdline && exit 0

getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 && $7 !~ /(nologin|false)$/ {print $1}' |
while read -r u; do
    icon=/var/lib/AccountsService/icons/$u
    conf=/var/lib/AccountsService/users/$u
    # schon ein Bild? (Datei vorhanden oder Icon= zeigt auf eine vorhandene Datei)
    [ -s "$icon" ] && continue
    cur=$(sed -n 's/^Icon=//p' "$conf" 2>/dev/null)
    [ -n "$cur" ] && [ -s "$cur" ] && continue
    /usr/local/bin/pingulinux-set-avatar.sh "$u" "$PINGU" >/dev/null 2>&1 \
        && echo "Profilbild Pingu gesetzt: $u"
done
exit 0
