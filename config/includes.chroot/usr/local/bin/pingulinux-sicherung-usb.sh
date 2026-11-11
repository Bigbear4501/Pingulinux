#!/bin/bash
#
# pingulinux-sicherung-usb.sh
#
# „Auf USB-Stick sichern“ für Eltern: Stick einstecken, starten, Stick
# auswählen, festlegen was gesichert wird – läuft durch.
#   • Eigene Dateien aller Konten (Fotos, Dokumente …)
#   • System (Timeshift-Stand, zum Wiederherstellen)
# Die eigentliche Arbeit macht pingulinux-sicherung-usb-worker.sh als root.

. /usr/local/lib/pingulinux/dialog.sh
TITLE="Auf USB-Stick sichern"
WORKER=/usr/local/bin/pingulinux-sicherung-usb-worker.sh
RESULT=/var/lib/pingulinux/usb-sicherung-ergebnis

if grep -qw 'boot=live' /proc/cmdline 2>/dev/null; then
    pd_info "$TITLE" "ℹ️ Im Live-Modus gibt es noch nichts zu sichern.\nDie Sicherung funktioniert nach der Installation."
    exit 0
fi

# --- Stick suchen: Partitionen (oder ganze Sticks) auf Wechseldatenträgern ---
ROOTDISK=$(lsblk -npdo PKNAME "$(findmnt -no SOURCE /)" 2>/dev/null | tr -d ' ')
find_sticks() {
    local NAME TYPE FSTYPE SIZE LABEL MOUNTPOINT HOTPLUG PKNAME MODEL hp model
    while IFS= read -r line; do
        eval "$line"
        [ -n "$FSTYPE" ] || continue
        case "$FSTYPE" in swap|crypto_LUKS|LVM2_member|iso9660|udf|squashfs) continue ;; esac
        # Wechseldatenträger? HOTPLUG oder RM = 1 oder über USB angeschlossen.
        # (Manche Sticks/USB-Platten – und Sticks in einer VM – melden HOTPLUG=0, aber TRAN=usb.)
        hp=0
        for d in "$NAME" $PKNAME; do
            read -r h r t < <(lsblk -dno HOTPLUG,RM,TRAN "$d" 2>/dev/null)
            { [ "$h" = 1 ] || [ "$r" = 1 ] || [ "$t" = usb ]; } && hp=1
        done
        [ "$hp" = 1 ] || continue
        # nie die Platte, auf der das System läuft
        [ -n "$ROOTDISK" ] && { [ "$NAME" = "$ROOTDISK" ] || [ "$PKNAME" = "$ROOTDISK" ]; } && continue
        [ "$TYPE" = part ] || [ "$TYPE" = disk ] || continue
        # den Pingulinux-Stick selbst (Live-Medium) auslassen
        [ "$MOUNTPOINT" = /run/live/medium ] && continue
        model=$( [ -n "$PKNAME" ] && lsblk -dno MODEL "$PKNAME" 2>/dev/null | sed 's/ *$//' )
        printf '%s\t%s\n' "$NAME" "${LABEL:-${model:-USB-Speicher}} – $SIZE ($FSTYPE)"
    done < <(lsblk -Pnpo NAME,TYPE,FSTYPE,SIZE,LABEL,MOUNTPOINT,HOTPLUG,PKNAME 2>/dev/null)
}

while true; do
    mapfile -t STICKS < <(find_sticks)
    [ ${#STICKS[@]} -gt 0 ] && break
    pd_frage "$TITLE" "🔌 Bitte stecke jetzt den USB-Stick oder die USB-Festplatte ein.\n\nDanach auf „Nochmal suchen“ klicken." "Nochmal suchen" "Abbrechen" || exit 0
    sleep 2
done

ARGS=()
for s in "${STICKS[@]}"; do ARGS+=("${s%%$'\t'*}" "${s#*$'\t'}"); done
DEV=$(pd_menue "$TITLE" "Auf welchen Stick soll gesichert werden?" "${ARGS[@]}") || exit 0
[ -n "$DEV" ] || exit 0
FSTYPE=$(lsblk -dno FSTYPE "$DEV" | tr -d ' ')

# --- Was sichern? ---
WAHL=$(pd_auswahl "$TITLE" "Was soll auf den Stick?" \
    daten "📁  Eigene Dateien aller Konten (Fotos, Dokumente, Spielstände …)" an \
    system "💻  System (zum Wiederherstellen, falls Pingulinux nicht mehr richtig läuft)" an) || exit 0
WAHL=$(echo "$WAHL" | tr -d '"')
DATEN=; SYSTEM=
grep -qx daten <<<"$WAHL" && DATEN=1
grep -qx system <<<"$WAHL" && SYSTEM=1
[ -n "$DATEN$SYSTEM" ] || exit 0

# --- System braucht ein Linux-Dateisystem ---
case "$FSTYPE" in ext2|ext3|ext4|btrfs|xfs) LINUXFS=1 ;; *) LINUXFS= ;; esac
if [ -n "$SYSTEM" ] && [ -z "$LINUXFS" ]; then
    NAME=$(printf '%s\n' "${STICKS[@]}" | awk -F'\t' -v d="$DEV" '$1==d {print $2}')
    if pd_frage "$TITLE" "Die System-Sicherung braucht einen Stick im Linux-Format (ext4).\nDieser Stick hat das Format <b>$FSTYPE</b>.\n\nSoll der Stick dafür formatiert werden?\n\n⚠️ <b>Dabei wird ALLES gelöscht, was jetzt auf dem Stick ist.</b>\nDanach kann Windows den Stick nicht mehr lesen." "Stick formatieren" "Nein, nur eigene Dateien"; then
        pd_frage "$TITLE" "Wirklich <b>alles</b> auf diesem Stick löschen?\n\n$NAME" "Ja, alles löschen" "Abbrechen" || exit 0
        udisksctl unmount -b "$DEV" --no-user-interaction >/dev/null 2>&1
        pkexec "$WORKER" formatieren "$DEV" | pd_fortschritt "$TITLE" "Stick wird formatiert…"
        if ! grep -q "✅" "$RESULT" 2>/dev/null; then
            pd_fehler "$TITLE" "$(cat "$RESULT" 2>/dev/null || echo "⚠️ Abgebrochen.")"
            exit 1
        fi
        FSTYPE=ext4; LINUXFS=1
    else
        SYSTEM=
        [ -n "$DATEN" ] || exit 0
    fi
fi

# --- Stick einbinden (falls noch nicht) ---
MP=$(lsblk -no MOUNTPOINT "$DEV" | head -1)
if [ -z "$MP" ]; then
    udisksctl mount -b "$DEV" --no-user-interaction >/dev/null 2>&1
    sleep 1
    MP=$(lsblk -no MOUNTPOINT "$DEV" | head -1)
fi
[ -n "$MP" ] || { pd_fehler "$TITLE" "⚠️ Der Stick ließ sich nicht öffnen."; exit 1; }

if [ -n "$DATEN" ] && [ -n "$SYSTEM" ]; then WHAT=beides
elif [ -n "$SYSTEM" ]; then WHAT=system
else WHAT=daten; fi

pd_frage "$TITLE" "Jetzt sichern?\n\nEin Erwachsener muss gleich das Passwort eingeben.\nJe nach Menge dauert das einige Minuten – den Stick bitte nicht abziehen." "Sichern" "Abbrechen" || exit 0

pkexec "$WORKER" sichern "$DEV" "$MP" "$WHAT" | pd_fortschritt "$TITLE" "Sicherung läuft…"

if [ -s "$RESULT" ]; then
    MSG=$(cat "$RESULT")
else
    pd_info "$TITLE" "Abgebrochen – es wurde nichts gesichert."
    exit 0
fi

if pd_frage "$TITLE" "$MSG\n\nDer Stick liegt jetzt im Ordner „Pingulinux-Sicherung“.\n\nStick sicher entfernen?" "Stick auswerfen" "Noch nicht"; then
    sync
    udisksctl unmount -b "$DEV" --no-user-interaction >/dev/null 2>&1
    PARENT=$(lsblk -dno PKNAME "$DEV" | tr -d ' ')
    udisksctl power-off -b "${PARENT:-$DEV}" --no-user-interaction >/dev/null 2>&1
    pd_info "$TITLE" "✅ Du kannst den Stick jetzt abziehen."
fi
