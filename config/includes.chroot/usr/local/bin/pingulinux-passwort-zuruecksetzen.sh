#!/bin/bash
#
# pingulinux-passwort-zuruecksetzen.sh  (nur im Live-Modus)
#
# „Eltern-Passwort vergessen“: Vom Pingulinux-Stick starten, dieses
# Werkzeug im Startmenü (System) öffnen. Es sucht das installierte Pingulinux auf der Festplatte,
# zeigt die Eltern-Konten (Gruppe sudo) und setzt für das gewählte Konto
# ein neues Passwort.
#
# Sicherheit: Wer vom Stick starten kann, kommt ohnehin an die Festplatte.
# Dieses Werkzeug macht nur den bekannten Weg bequem. Schutz davor:
# BIOS-Passwort und Start vom USB-Stick abschalten (siehe Eltern-FAQ).
#
# Läuft als Live-Benutzer, root-Befehle über sudo (im Live-Modus ohne
# Passwort). Verschlüsselte Festplatten werden nicht unterstützt.

TITLE="Eltern-Passwort zurücksetzen"
. /usr/local/lib/pingulinux/dialog.sh

if ! grep -qw 'boot=live' /proc/cmdline; then
    pd_info "$TITLE" "Das geht nur, wenn der Computer vom Pingulinux-Stick gestartet wurde.\n\nIm installierten System kann ein anderes Eltern-Konto das Passwort im Kontrollzentrum ändern."
    exit 0
fi

pd_frage "$TITLE" "<b>Eltern-Passwort vergessen?</b>\n\nDieses Werkzeug sucht Pingulinux auf der Festplatte und setzt das Passwort eines Eltern-Kontos neu.\n\nDie Kinderkonten, Fotos und Dokumente bleiben, wie sie sind." "Weiter" "Abbrechen" || exit 0

MNT=$(mktemp -d /tmp/pingu-root.XXXX)
cleanup() { sudo umount "$MNT" 2>/dev/null; rmdir "$MNT" 2>/dev/null; }
trap cleanup EXIT

# Installiertes System suchen: Partitionen mit ext4/btrfs/xfs, auf denen
# /etc/passwd und /var/lib/pingulinux liegen (nicht der Stick selbst).
found=""
while read -r dev fs; do
    case "$fs" in ext4|ext3|btrfs|xfs) ;; *) continue ;; esac
    for opt in ro ro,subvol=@; do
        [ "$fs" != btrfs ] && [ "$opt" != ro ] && continue
        sudo mount -o "$opt" "/dev/$dev" "$MNT" 2>/dev/null || continue
        if [ -f "$MNT/etc/passwd" ] && [ -d "$MNT/var/lib/pingulinux" ]; then
            found="/dev/$dev"; FOPT="$opt"; sudo umount "$MNT"; break 2
        fi
        sudo umount "$MNT" 2>/dev/null
    done
done < <(lsblk -lnpo NAME,FSTYPE | sed 's#^/dev/##')

if [ -z "$found" ]; then
    if lsblk -lno FSTYPE | grep -qx crypto_LUKS; then
        msg="Die Festplatte ist verschlüsselt. Das kann dieses Werkzeug nicht."
    else
        msg="Auf diesem Computer wurde kein installiertes Pingulinux gefunden."
    fi
    pd_fehler "$TITLE" "$msg"
    exit 1
fi

sudo mount -o "${FOPT/ro/rw}" "$found" "$MNT" || { pd_fehler "$TITLE" "Die Festplatte ließ sich nicht öffnen ($found)."; exit 1; }

# Eltern-Konten = Mitglieder der Gruppe sudo im installierten System
mapfile -t PARENTS < <(awk -F: '$1=="sudo"{gsub(",","\n",$4); print $4}' "$MNT/etc/group" | grep -v '^$')
if [ ${#PARENTS[@]} -eq 0 ]; then
    pd_fehler "$TITLE" "Im installierten System wurde kein Eltern-Konto gefunden."
    exit 1
fi
LIST=()
for u in "${PARENTS[@]}"; do
    name=$(awk -F: -v u="$u" '$1==u{split($5,a,","); print a[1]}' "$MNT/etc/passwd")
    LIST+=("$u" "${name:-$u} ($u)")
done
USER_SEL=$(pd_menue "$TITLE" "Für welches Eltern-Konto?" "${LIST[@]}") || exit 0
[ -n "$USER_SEL" ] || exit 0

while true; do
    PW1=$(pd_passwort "$TITLE" "Neues Passwort für $USER_SEL:") || exit 0
    PW2=$(pd_passwort "$TITLE" "Neues Passwort noch einmal:") || exit 0
    if [ -z "$PW1" ]; then
        pd_fehler "$TITLE" "Das Passwort darf nicht leer sein."
    elif [ "$PW1" != "$PW2" ]; then
        pd_fehler "$TITLE" "Die beiden Passwörter sind nicht gleich."
    else
        break
    fi
done

if printf '%s:%s\n' "$USER_SEL" "$PW1" | sudo chroot "$MNT" /usr/sbin/chpasswd; then
    unset PW1 PW2
    # Vermerk im installierten System: Beim nächsten Anmelden sehen alle
    # Eltern, dass das Passwort vom Stick aus zurückgesetzt wurde.
    sudo mkdir -p "$MNT/var/lib/pingulinux"
    printf '%s|%s\n' "$(date +%s)" "$USER_SEL" | sudo tee -a "$MNT/var/lib/pingulinux/passwort-zurueckgesetzt.log" >/dev/null
    sudo chmod 644 "$MNT/var/lib/pingulinux/passwort-zurueckgesetzt.log"
    sync
    pd_info "$TITLE" "<b>Fertig.</b>\n\nDas Passwort für <b>$USER_SEL</b> ist geändert.\n\nStick abziehen und den Computer neu starten."
else
    unset PW1 PW2
    pd_fehler "$TITLE" "Das Passwort konnte nicht geändert werden."
    exit 1
fi
