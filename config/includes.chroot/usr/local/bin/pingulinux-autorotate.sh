#!/bin/bash
#
# pingulinux-autorotate.sh - dreht Bildschirm und Touch automatisch
# (nur auf Geraeten mit Lagesensor, z. B. Surface Go). Auf Geraeten
# ohne Sensor beendet sich das Skript sofort.

command -v monitor-sensor >/dev/null || exit 0
sleep 5   # Sensor-Dienst erst hochfahren lassen

OUT=$(xrandr --query | awk '/ connected primary| connected [0-9]/ {print $1; exit}')
[ -n "$OUT" ] || exit 0

rotate() {
    local rot="$1" matrix="$2"
    xrandr --output "$OUT" --rotate "$rot"
    xinput list --name-only | grep -iE "touch|ipts|elan|goodix" | while read -r dev; do
        xinput set-prop "$dev" "Coordinate Transformation Matrix" $matrix 2>/dev/null
    done
}

monitor-sensor 2>/dev/null | while read -r line; do
    case "$line" in
        *"Accelerometer orientation changed: normal"*)    rotate normal   "1 0 0 0 1 0 0 0 1" ;;
        *"Accelerometer orientation changed: left-up"*)   rotate left     "0 -1 1 1 0 0 0 0 1" ;;
        *"Accelerometer orientation changed: right-up"*)  rotate right    "0 1 0 -1 0 1 0 0 1" ;;
        *"Accelerometer orientation changed: bottom-up"*) rotate inverted "-1 0 1 0 -1 1 0 0 1" ;;
    esac
done
