#!/bin/bash
#
# pingulinux-sicherung-usb-worker.sh – läuft als root (pkexec)
#
# Sicherung auf einen USB-Stick oder eine USB-Platte.
# Aufruf (nur aus pingulinux-sicherung-usb.sh):
#   …-worker.sh formatieren GERÄT
#   …-worker.sh sichern GERÄT ZIELORDNER daten|system|beides
#
# Das Ergebnis steht danach in /var/lib/pingulinux/usb-sicherung-ergebnis.
#
# Ausgabe für das Fortschrittsfenster: Zahlen 0–100 und Zeilen „# Text“.
#
#   daten:  eigene Dateien aller Konten (/home) nach
#           ZIEL/Pingulinux-Sicherung/<Rechner>/Eigene-Dateien/
#           Nichts wird auf dem Stick gelöscht: Was zu Hause gelöscht wurde,
#           bleibt auf dem Stick erhalten.
#   system: Timeshift-Sicherung des Systems direkt auf den Stick
#           (braucht ein Linux-Dateisystem, z. B. ext4)

set -u
MODE="${1:-}"
DEV="${2:-}"
RESULT=/var/lib/pingulinux/usb-sicherung-ergebnis
mkdir -p /var/lib/pingulinux

fail() { echo "# ⚠️ $1"; echo "⚠️ $1" > "$RESULT"; chmod 644 "$RESULT"; exit 1; }

# Nur Wechseldatenträger (USB) zulassen – nie die eingebaute Platte
[ -b "$DEV" ] || fail "Kein gültiges Gerät: $DEV"
# Wechseldatenträger = HOTPLUG oder RM = 1 oder über USB angeschlossen (TRAN=usb),
# beim Gerät selbst oder bei der Platte, zu der die Partition gehört.
PK=$(lsblk -npdo PKNAME "$DEV" 2>/dev/null | tr -d ' ')
EXT=0
for d in "$DEV" $PK; do
    read -r h r t < <(lsblk -dno HOTPLUG,RM,TRAN "$d" 2>/dev/null)
    { [ "$h" = 1 ] || [ "$r" = 1 ] || [ "$t" = usb ]; } && EXT=1
done
[ "$EXT" = 1 ] || fail "Das Gerät ist kein USB-Stick bzw. keine Wechselplatte."
ROOTDEV=$(findmnt -no SOURCE /)
ROOTDISK=$(lsblk -npdo PKNAME "$ROOTDEV" 2>/dev/null | tr -d ' ')
[ "$DEV" != "$ROOTDEV" ] || fail "Das ist die Systemplatte."
[ -z "$ROOTDISK" ] || { [ "$DEV" != "$ROOTDISK" ] && [ "$PK" != "$ROOTDISK" ]; } || fail "Das ist die Systemplatte."

case "$MODE" in
formatieren)
    echo "# Stick wird vorbereitet (formatiert)…"; echo 10
    for m in $(lsblk -nlo MOUNTPOINT "$DEV" | grep -v '^$'); do umount "$m" 2>/dev/null; done
    umount "$DEV" 2>/dev/null
    if mkfs.ext4 -F -q -L PINGU-SICHER "$DEV"; then
        echo 100; echo "# Fertig"; echo "✅ Stick formatiert" > "$RESULT"; chmod 644 "$RESULT"
        exit 0
    fi
    fail "Formatieren hat nicht geklappt."
    ;;
sichern)
    TARGET="${3:-}"; WHAT="${4:-}"
    [ -d "$TARGET" ] || fail "Der Stick ist nicht eingebunden."
    findmnt -no SOURCE "$TARGET" | grep -qx "$DEV" || fail "Der Ordner gehört nicht zu diesem Stick."
    rm -f "$RESULT"
    HOST=$(hostname)
    BASE="$TARGET/Pingulinux-Sicherung/$HOST"
    FSTYPE=$(findmnt -no FSTYPE "$TARGET")
    msgs=()

    if [ "$WHAT" = daten ] || [ "$WHAT" = beides ]; then
        echo "# Größe der eigenen Dateien wird ermittelt…"; echo 2
        NEED=$(du -sb --exclude='.cache' --exclude='.local/share/Trash' /home 2>/dev/null | cut -f1)
        FREE=$(df --output=avail -B1 "$TARGET" | tail -1 | tr -d ' ')
        # nur grob: schon vorhandene Sicherung zählt als Platz
        OLD=$(du -sb "$BASE/Eigene-Dateien" 2>/dev/null | cut -f1)
        if [ $(( ${NEED:-0} - ${OLD:-0} )) -gt "${FREE:-0}" ]; then
            fail "Zu wenig Platz auf dem Stick: nötig etwa $(( NEED / 1024 / 1024 )) MB, frei $(( FREE / 1024 / 1024 )) MB."
        fi
        mkdir -p "$BASE/Eigene-Dateien" || fail "Auf dem Stick lässt sich nichts anlegen (schreibgeschützt?)."
        # Ohne Besitzer und Rechte kopieren: So können die Eltern später jede
        # Datei vom Stick öffnen und zurückkopieren (auch Dateien der Kinder).
        OPTS=(-rltD --no-perms --no-owner --no-group --chmod=Du=rwx,Dgo=rx,Fu=rw,Fgo=r --modify-window=2)
        echo "# Eigene Dateien werden gesichert…"
        START=5; SPAN=$([ "$WHAT" = beides ] && echo 45 || echo 90)
        rsync "${OPTS[@]}" --info=progress2 --no-inc-recursive \
            --exclude='.cache/' --exclude='.local/share/Trash/' --exclude='.local/share/flatpak/' \
            --exclude='.var/app/*/cache/' --exclude='*.tmp' \
            /home/ "$BASE/Eigene-Dateien/" 2>>/var/log/pingulinux-sicherung-usb.log \
          | tr '\r' '\n' | awk -v s="$START" -v w="$SPAN" '
              /%/ { for (i=1;i<=NF;i++) if ($i ~ /%$/) { p=$i; sub("%","",p); printf "%d\n", s + p*w/100; fflush() } }'
        RC=${PIPESTATUS[0]}
        if [ "$RC" = 0 ] || [ "$RC" = 23 ] || [ "$RC" = 24 ]; then
            date '+%d.%m.%Y %H:%M' > "$BASE/Eigene-Dateien/LETZTE-SICHERUNG.txt"
            msgs+=("✅ Eigene Dateien gesichert")
            [ "$RC" != 0 ] && msgs+=("   (einzelne Dateien ließen sich nicht kopieren, Details: /var/log/pingulinux-sicherung-usb.log)")
        else
            msgs+=("⚠️ Eigene Dateien: Fehler (rsync $RC)")
        fi
    fi

    if [ "$WHAT" = system ] || [ "$WHAT" = beides ]; then
        case "$FSTYPE" in
            ext2|ext3|ext4|btrfs|xfs) ;;
            *) msgs+=("⚠️ System: braucht einen Stick im Linux-Format (ext4)"); WHAT=fertig ;;
        esac
    fi
    if [ "$WHAT" = system ] || [ "$WHAT" = beides ]; then
        echo "# System wird gesichert (Timeshift)… das dauert eine Weile"
        if [ "$WHAT" = beides ]; then echo 55; else echo 10; fi
        # Timeshift merkt sich den Stick sonst dauerhaft als Sicherungs-Platte –
        # dann liefe die tägliche Sicherung ins Leere, sobald der Stick ab ist.
        TSCONF=/etc/timeshift/timeshift.json; KEEP=$(mktemp)
        [ -f "$TSCONF" ] && cp -p "$TSCONF" "$KEEP"
        if timeshift --create --scripted --snapshot-device "$DEV" \
               --comments "USB-Sicherung $(date '+%d.%m.%Y')" \
               >>/var/log/pingulinux-sicherung-usb.log 2>&1; then
            msgs+=("✅ System gesichert (Timeshift auf dem Stick)")
        else
            msgs+=("⚠️ System: Timeshift meldet einen Fehler (Details: /var/log/pingulinux-sicherung-usb.log)")
        fi
        [ -s "$KEEP" ] && cp -p "$KEEP" "$TSCONF"; rm -f "$KEEP"
    fi
    sync
    echo 100; echo "# Fertig"
    printf '%s\n' "${msgs[@]}" > "$RESULT"; chmod 644 "$RESULT"
    exit 0
    ;;
*)
    echo "Aufruf: $0 formatieren GERÄT | sichern GERÄT ZIEL daten|system|beides" >&2
    exit 2
    ;;
esac
