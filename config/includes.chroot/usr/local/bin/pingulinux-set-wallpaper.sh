#!/bin/bash
#
# pingulinux-set-wallpaper.sh
#
# Setzt das Pingulinux-Wallpaper unabhängig vom tatsächlichen Monitor-
# Namen. Auf echter Hardware (z.B. Mac-Laptops) legt xfdesktop einen
# zusätzlichen Monitor-Eintrag mit dem echten xrandr-Ausgangsnamen an
# (z.B. "monitoreDP-1", passend zu "eDP-1" von xrandr) - dieser Eintrag
# erscheint aber oft ERST verzögert nach dem Login, nicht sofort beim
# Start. Daher: xrandr direkt abfragen (zuverlässige Quelle, keine
# Verzögerung) UND zusätzlich einen zweiten, späteren Durchlauf machen,
# um auch verzögert erscheinende Properties zu erwischen.

MARKER="$HOME/.config/pingulinux-wallpaper-set"

if [ -f "$MARKER" ]; then
    exit 0
fi

WALLPAPER="/usr/share/backgrounds/pingulinux/wallpaper.png"

apply_wallpaper_everywhere() {
    # Alle ".../workspaceN/"-Pfade sammeln (unabhängig vom Monitor-Namen)
    xfconf-query -c xfce4-desktop -p /backdrop -l 2>/dev/null | grep -oE '.*workspace[0-9]+' | sort -u | while read -r ws_path; do
        xfconf-query -c xfce4-desktop -p "${ws_path}/backdrop-cycle-enable" -n -t bool -s false 2>/dev/null || \
            xfconf-query -c xfce4-desktop -p "${ws_path}/backdrop-cycle-enable" -s false 2>/dev/null

        xfconf-query -c xfce4-desktop -p "${ws_path}/last-image" -n -t string -s "$WALLPAPER" 2>/dev/null || \
            xfconf-query -c xfce4-desktop -p "${ws_path}/last-image" -s "$WALLPAPER" 2>/dev/null

        xfconf-query -c xfce4-desktop -p "${ws_path}/image-style" -n -t int -s 5 2>/dev/null || \
            xfconf-query -c xfce4-desktop -p "${ws_path}/image-style" -s 5 2>/dev/null
    done

    xfconf-query -c xfce4-desktop -p /backdrop -l 2>/dev/null | grep -E "last-single-image|image-path" | while read -r prop_path; do
        xfconf-query -c xfce4-desktop -p "$prop_path" -s "$WALLPAPER" 2>/dev/null
    done

    xfconf-query -c xfce4-desktop -p /backdrop -l 2>/dev/null | grep "image-show" | while read -r prop_path; do
        xfconf-query -c xfce4-desktop -p "$prop_path" -s true 2>/dev/null
    done

    # Direkt über xrandr den tatsächlichen Ausgangsnamen ermitteln
    # (zuverlässige Quelle, unabhängig von xfdesktop-Timing) und die
    # Property PROAKTIV erzwingen, auch falls sie noch nicht existiert.
    if command -v xrandr &> /dev/null; then
        xrandr --query 2>/dev/null | grep " connected" | cut -d' ' -f1 | while read -r output_name; do
            monitor_path="/backdrop/screen0/monitor${output_name}/workspace0"
            xfconf-query -c xfce4-desktop -p "${monitor_path}/backdrop-cycle-enable" -n -t bool -s false 2>/dev/null || \
                xfconf-query -c xfce4-desktop -p "${monitor_path}/backdrop-cycle-enable" -s false 2>/dev/null
            xfconf-query -c xfce4-desktop -p "${monitor_path}/last-image" -n -t string -s "$WALLPAPER" 2>/dev/null || \
                xfconf-query -c xfce4-desktop -p "${monitor_path}/last-image" -s "$WALLPAPER" 2>/dev/null
            xfconf-query -c xfce4-desktop -p "${monitor_path}/image-style" -n -t int -s 5 2>/dev/null || \
                xfconf-query -c xfce4-desktop -p "${monitor_path}/image-style" -s 5 2>/dev/null
        done
    fi

    # Rückfalloption: gängige Standard-Pfade direkt erzwingen
    for monitor_path in \
        "/backdrop/screen0/monitor0/workspace0/last-image" \
        "/backdrop/screen0/monitoreDP-1/workspace0/last-image"
    do
        xfconf-query -c xfce4-desktop -p "$monitor_path" -n -t string -s "$WALLPAPER" 2>/dev/null || \
            xfconf-query -c xfce4-desktop -p "$monitor_path" -s "$WALLPAPER" 2>/dev/null
    done

    xfdesktop --reload 2>/dev/null || true
}

# Auf xfdesktop warten (max. 20 Sekunden)
for i in $(seq 1 20); do
    if xfconf-query -c xfce4-desktop -p /backdrop -l 2>/dev/null | grep -q "workspace0"; then
        break
    fi
    sleep 1
done

# Erster Durchlauf sofort
apply_wallpaper_everywhere

# Zweiter, verzögerter Durchlauf im Hintergrund - fängt Properties ab,
# die xfdesktop erst nach ein paar Sekunden zusätzlich anlegt
(
    sleep 8
    apply_wallpaper_everywhere
    sleep 7
    apply_wallpaper_everywhere
) &

mkdir -p "$HOME/.config"
touch "$MARKER"
