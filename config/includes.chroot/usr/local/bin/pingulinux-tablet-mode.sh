#!/bin/bash
#
# pingulinux-tablet-mode.sh - Tablet-Modus an/aus:
# Bildschirmtastatur (Onboard), grosse Symbole, Touch-freundliche Leiste.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
TITLE="Tablet-Modus"
STATE="$HOME/.config/pingulinux-tablet-mode"

# Setzt einen xfconf-Wert (legt ihn an, falls er noch nicht existiert)
xset_int() { xfconf-query -c "$1" -p "$2" -n -t int -s "$3" 2>/dev/null || xfconf-query -c "$1" -p "$2" -s "$3" 2>/dev/null; }

# Alle vorhandenen Leisten (panel-1, panel-2, ...) anpassen
set_panels() {
    local size="$1" icon="$2" p
    for p in $(xfconf-query -c xfce4-panel -p /panels -l 2>/dev/null | grep -oE '^/panels/panel-[0-9]+' | sort -u); do
        xset_int xfce4-panel "$p/size" "$size"
        xset_int xfce4-panel "$p/icon-size" "$icon"
    done
    # Leiste neu laden, damit die Aenderung sofort sichtbar wird
    xfce4-panel -r >/dev/null 2>&1 &
}

if [ -f "$STATE" ]; then
    zenity --question --title="$TITLE" --width=400 --ok-label="Ausschalten" --cancel-label="Anlassen" \
        --text="📱 Der Tablet-Modus ist <b>eingeschaltet</b>.\n\nMöchtest du ihn ausschalten?" || exit 0
    rm -f "$STATE"
    pkill onboard 2>/dev/null
    xset_int xsettings /Gtk/CursorThemeSize 24
    xset_int xsettings /Xft/DPI 96
    set_panels 32 0
    zenity --info --title="$TITLE" --width=360 --text="✅ Tablet-Modus ist aus."
else
    zenity --question --title="$TITLE" --width=420 --ok-label="Einschalten" --cancel-label="Abbrechen" \
        --text="📱 Tablet-Modus einschalten?\n\n• Bildschirmtastatur zum Tippen\n• größere Leiste und Symbole zum Antippen" || exit 0
    touch "$STATE"
    xset_int xsettings /Gtk/CursorThemeSize 48
    xset_int xsettings /Xft/DPI 130
    set_panels 56 40
    if command -v onboard >/dev/null; then
        (onboard >/dev/null 2>&1 &)
        MSG="✅ Tablet-Modus ist an."
    else
        MSG="⚠️ Tablet-Modus ist an, aber die Bildschirmtastatur (Onboard) ist nicht installiert."
    fi
    zenity --info --title="$TITLE" --width=380 --text="$MSG"
fi
