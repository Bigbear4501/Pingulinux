#!/bin/bash
#
# kids-welcome.sh
#
# Läuft standardmäßig bei JEDEM Login (via Autostart-Desktop-Datei).
# Fragt eine Altersstufe ab und setzt darauf basierend:
#   - Wallpaper
#   - Sichtbarkeit bestimmter Menü-Kategorien (via gsettings/xfconf)
#
# Falls der Nutzer "Nicht mehr anzeigen" wählt, wird eine Marker-Datei
# angelegt und der Dialog erscheint ab dann nicht mehr. Diese Marker-Datei
# kann jederzeit manuell gelöscht werden, um den Dialog wieder zu aktivieren:
#   rm ~/.config/kids-distro-welcome-done

MARKER="$HOME/.config/kids-distro-welcome-done"

if [ -f "$MARKER" ]; then
    exit 0
fi

# Einfache GTK-Dialogauswahl über zenity (muss im Paketset enthalten sein)
if ! command -v zenity &> /dev/null; then
    echo "zenity nicht gefunden, überspringe Willkommens-Dialog." >&2
    exit 0
fi

AGE_GROUP=$(zenity --list \
    --title="Willkommen bei Pingulinux OS!" \
    --text="Hallo! Für wen wird dieser Computer eingerichtet?" \
    --radiolist \
    --column="Wahl" --column="Altersgruppe" \
    TRUE "Klein (2-6 Jahre)" \
    FALSE "Mittel (7-11 Jahre)" \
    FALSE "Groß (12-14 Jahre)" \
    --width=400 --height=250)

case "$AGE_GROUP" in
    "Klein (2-6 Jahre)")
        PROFILE="klein"
        ;;
    "Mittel (7-11 Jahre)")
        PROFILE="mittel"
        ;;
    "Groß (12-14 Jahre)")
        PROFILE="gross"
        ;;
    *)
        PROFILE="mittel"  # Fallback, falls Dialog abgebrochen wird
        ;;
esac

# Profil-Datei schreiben, die andere Skripte/Panels auslesen können
mkdir -p "$HOME/.config/kids-distro"
echo "PROFILE=$PROFILE" > "$HOME/.config/kids-distro/profile.conf"

# Wallpaper je nach Profil setzen (Pfade anpassen, sobald Assets feststehen)
WALLPAPER="/usr/share/kids-distro/wallpapers/${PROFILE}.jpg"
if [ -f "$WALLPAPER" ]; then
    xfconf-query -c xfce4-desktop -p /backdrop/screen0/monitor0/workspace0/last-image -s "$WALLPAPER" 2>/dev/null
fi

# Menü-Kategorien je nach Profil anpassen: Beispiel für "klein" =
# nur Education + Graphics, kein Office, kein freier Browser-Zugriff
if [ "$PROFILE" = "klein" ]; then
    xfconf-query -c xfce4-whiskermenu -p /category-visible-office -s false --create --type bool 2>/dev/null
fi

# Nachfragen, ob dieser Dialog künftig unterdrückt werden soll.
# "Nicht mehr anzeigen" (OK-Button) legt die Marker-Datei an.
# "Beim nächsten Login wieder zeigen" (Cancel-Button) lässt alles offen.
if zenity --question \
    --title="Pingulinux OS" \
    --text="Soll dieser Assistent beim nächsten Login wieder erscheinen?" \
    --ok-label="Nicht mehr anzeigen" \
    --cancel-label="Beim nächsten Login wieder zeigen" \
    --width=380; then
    touch "$MARKER"
fi
# Falls "Beim nächsten Login wieder zeigen" gewählt wurde, wird KEIN Marker
# angelegt -> das Skript läuft beim nächsten Login erneut von vorne.
