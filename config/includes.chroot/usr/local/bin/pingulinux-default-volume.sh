#!/bin/bash
#
# pingulinux-default-volume.sh
#
# Setzt beim allerersten Login die Lautstärke auf 50% und hebt eine
# eventuelle Stummschaltung auf. Läuft nur EINMAL (Marker-Datei),
# damit spätere manuelle Lautstärke-Änderungen des Nutzers nicht bei
# jedem Login wieder überschrieben werden.

MARKER="$HOME/.config/pingulinux-volume-set"

if [ -f "$MARKER" ]; then
    exit 0
fi

# Auf PulseAudio warten (max. 15 Sekunden)
for i in $(seq 1 15); do
    if pactl info &> /dev/null; then
        break
    fi
    sleep 1
done

pactl set-sink-mute @DEFAULT_SINK@ 0 &> /dev/null
pactl set-sink-volume @DEFAULT_SINK@ 50% &> /dev/null

mkdir -p "$HOME/.config"
touch "$MARKER"
