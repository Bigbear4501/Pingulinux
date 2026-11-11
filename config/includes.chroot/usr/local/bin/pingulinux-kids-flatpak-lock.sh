#!/bin/bash
#
# pingulinux-kids-flatpak-lock.sh  (läuft als root, beim Start und wenn
# sich Kinderkonten ändern)
#
# Kinder dürfen keine Flatpaks selbst installieren. Mit „flatpak --user“
# ginge das ohne Administrator-Passwort, am App Store und an den
# Altersgrenzen vorbei. Neue Programme gibt es nur über den App Store.
#
# So wird es gesperrt: Im Kinderkonto wird der Ordner, in den Flatpak
# eigene Programme legt (~/.local/share/flatpak), durch einen leeren,
# schreibgeschützten Ordner ersetzt, der root gehört und mit chattr +i
# gegen Umbenennen und Löschen geschützt ist.
# Flatpaks, die Eltern über den App Store installieren (systemweit), laufen
# für Kinder ganz normal weiter.
#
# Wird ein Konto kein Kinderkonto mehr, wird die Sperre wieder entfernt.
#
#   --dry-run   nur anzeigen, was passieren würde
#   PINGU_DATA  anderer Datenordner (zum Testen)

DATA="${PINGU_DATA:-/var/lib/pingulinux}"
DRY=0; [ "${1:-}" = "--dry-run" ] && DRY=1
run() { if [ $DRY = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }

is_kid() {
    [ -e "$DATA/birth/$1" ] || [ -e "$DATA/profiles/$1" ]
}

grep -qw 'boot=live' /proc/cmdline 2>/dev/null && [ $DRY = 0 ] && exit 0

getent passwd | while IFS=: read -r user _ uid gid _ home _; do
    [ "$uid" -ge 1000 ] 2>/dev/null && [ "$uid" -lt 60000 ] || continue
    [ -d "$home" ] || continue
    dir="$home/.local/share/flatpak"

    if is_kid "$user"; then
        # schon gesperrt?
        if [ -d "$dir" ] && [ "$(stat -c %U "$dir")" = root ] && lsattr -d "$dir" 2>/dev/null | cut -c1-20 | grep -q i; then
            continue
        fi
        echo "Sperre Flatpak --user für $user"
        [ -e "$dir" ] && { run chattr -i "$dir" 2>/dev/null; run rm -rf "$dir"; }
        for d in "$home/.local" "$home/.local/share"; do
            [ -d "$d" ] || { run mkdir "$d"; run chown "$uid:$gid" "$d"; }
        done
        run install -d -o root -g root -m 555 "$dir"
        run chattr +i "$dir"
    else
        # früher gesperrt (Ordner gehört root), jetzt kein Kind mehr: Sperre lösen
        if [ -d "$dir" ] && [ "$(stat -c %U "$dir")" = root ]; then
            echo "Löse Flatpak-Sperre für $user"
            run chattr -i "$dir"
            run rmdir "$dir"
        fi
    fi
done
exit 0
