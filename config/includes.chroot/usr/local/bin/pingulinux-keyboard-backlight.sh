#!/bin/bash
#
# pingulinux-keyboard-backlight.sh - Tastaturbeleuchtung einstellen

. /usr/local/lib/pingulinux/dialog.sh
TITLE="Tastaturbeleuchtung"

DEV=$(brightnessctl --list --machine-readable 2>/dev/null | awk -F, '$1 ~ /kbd_backlight|keyboard|kbd/ {print $1; exit}')
if [ -z "$DEV" ]; then
    pd_info "$TITLE" "💡 Dieses Gerät hat keine einstellbare Tastaturbeleuchtung.\n\nBei manchen Tastaturen (z. B. Surface Type Cover) stellst du das Licht direkt mit der Funktionstaste an der Tastatur ein."
    exit 0
fi

MAX=$(brightnessctl -d "$DEV" max)
CUR=$(brightnessctl -d "$DEV" get)
PCT=$(( CUR * 100 / MAX ))

NEW=$(pd_regler "$TITLE" "💡 Wie hell soll die Tastatur leuchten?\n(0 = aus, 100 = am hellsten, jetzt: $PCT)" 0 100 10 "$PCT")
[ -z "$NEW" ] && exit 0
brightnessctl -d "$DEV" set "${NEW}%" >/dev/null 2>&1 || \
    pd_fehler "$TITLE" "⚠️ Die Helligkeit konnte nicht geändert werden."
