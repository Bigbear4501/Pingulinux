#!/bin/bash
#
# pingulinux-kids-noexec.sh  (läuft als root)
#
# Kinder sollen keine Programme starten können, die sie selbst
# heruntergeladen oder entpackt haben (AppImages, entpackte .deb-Dateien,
# eigene Flatpak-Ordner). Sonst ginge das am App Store und an den
# Altersgrenzen vorbei.
#
# Dafür werden Ordner, in die ein Kind schreiben kann, mit „noexec“
# eingehängt: Dateien darin lassen sich öffnen und speichern (Bilder,
# Dokumente), aber nicht als Programm starten.
#
#   boot           Kinder-Ordner (/home/<kind>) und /tmp, /var/tmp, /dev/shm
#                  (beim Start und wenn sich Kinderkonten ändern)
#   runtime <uid>  /run/user/<uid> eines Kindes (bei jeder Anmeldung)
#   --dry-run      als erstes Argument: nur anzeigen
#
# Für Eltern ändert sich nur, dass in /tmp, /var/tmp und /dev/shm keine
# Programme gestartet werden können. Ihr eigener Ordner bleibt normal.

DATA="${PINGU_DATA:-/var/lib/pingulinux}"
DRY=0; [ "${1:-}" = "--dry-run" ] && { DRY=1; shift; }
run() { if [ $DRY = 1 ]; then echo "[dry-run] $*"; else "$@"; fi; }
OPTS=noexec,nosuid,nodev

is_kid() { [ -e "$DATA/birth/$1" ] || [ -e "$DATA/profiles/$1" ]; }
has_noexec() { findmnt -n -M "$1" -o OPTIONS 2>/dev/null | tr ',' '\n' | grep -qx noexec; }

lock_dir() {   # Ordner (wenn nötig auf sich selbst gebunden) noexec einhängen
    local d="$1"
    [ -d "$d" ] || return 0
    has_noexec "$d" && return 0
    if ! mountpoint -q "$d"; then
        run mount --bind "$d" "$d" || return 1
        run mount -o "remount,bind,$OPTS" "$d"
    else
        run mount -o "remount,$OPTS" "$d"
    fi
    echo "noexec: $d"
}

# Im Live-Modus nichts tun (Testsystem)
grep -qw 'boot=live' /proc/cmdline 2>/dev/null && [ $DRY = 0 ] && exit 0

case "${1:-boot}" in
    boot)
        for d in /tmp /var/tmp /dev/shm; do lock_dir "$d"; done
        getent passwd | while IFS=: read -r user _ uid _ _ home _; do
            [ "$uid" -ge 1000 ] 2>/dev/null && [ "$uid" -lt 60000 ] || continue
            case "$home" in /home/*) ;; *) continue ;; esac
            [ -d "$home" ] || continue
            mark="/run/pingulinux/noexec-$user"
            if is_kid "$user"; then
                lock_dir "$home" && { run mkdir -p /run/pingulinux; run touch "$mark"; }
            elif [ -e "$mark" ]; then
                echo "Kein Kinderkonto mehr, noexec aufheben: $home"
                run umount "$home"; run rm -f "$mark"
            fi
        done
        ;;
    runtime)
        uid="${2:?uid fehlt}"
        user=$(getent passwd "$uid" | cut -d: -f1)
        [ -n "$user" ] && is_kid "$user" && lock_dir "/run/user/$uid"
        ;;
esac
exit 0
