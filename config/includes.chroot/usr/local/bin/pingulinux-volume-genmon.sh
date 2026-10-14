#!/bin/bash
#
# pingulinux-volume-genmon.sh
#
# Zeigt die aktuelle Lautstärke im Panel an (via genmon-Plugin) und
# öffnet bei Klick Pavucontrol zum Einstellen. Ersatz für das in
# trixie derzeit defekte xfce4-pulseaudio-plugin.

VOL=$(pactl get-sink-volume @DEFAULT_SINK@ 2>/dev/null | grep -oP '\d+%' | head -1)
MUTE=$(pactl get-sink-mute @DEFAULT_SINK@ 2>/dev/null | awk '{print $2}')

if [ "$MUTE" = "yes" ]; then
    TXT="🔇 Stumm"
else
    TXT="🔊 ${VOL:-?}"
fi

echo "<txt>${TXT}</txt>"
echo "<tool>Lautstärke: ${VOL:-unbekannt} - Klicken zum Einstellen</tool>"
echo "<click>pavucontrol</click>"
