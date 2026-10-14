#!/bin/bash
#
# pingulinux-keyboard-backlight.sh - Tastaturbeleuchtung einstellen

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
TITLE="Tastaturbeleuchtung"

DEV=$(brightnessctl --list --machine-readable 2>/dev/null | awk -F, '$1 ~ /kbd_backlight|keyboard|kbd/ {print $1; exit}')
if [ -z "$DEV" ]; then
    zenity --info --title="$TITLE" --width=420 \
        --text="💡 Dieses Gerät hat keine einstellbare Tastaturbeleuchtung.\n\nBei manchen Tastaturen (z. B. Surface Type Cover) stellst du das Licht direkt mit der Funktionstaste an der Tastatur ein."
    exit 0
fi

MAX=$(brightnessctl -d "$DEV" max)
CUR=$(brightnessctl -d "$DEV" get)
PCT=$(( CUR * 100 / MAX ))

NEW=$(zenity --scale --title="$TITLE" --width=420 \
    --text="💡 Wie hell soll die Tastatur leuchten?\n(0 = aus, 100 = am hellsten)" \
    --min-value=0 --max-value=100 --value="$PCT" --step=10 --ok-label="Einstellen")
[ -z "$NEW" ] && exit 0
brightnessctl -d "$DEV" set "${NEW}%" >/dev/null 2>&1 || \
    zenity --error --title="$TITLE" --width=380 --text="⚠️ Die Helligkeit konnte nicht geändert werden."
