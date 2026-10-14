#!/bin/bash
#
# pingulinux-recommended-apps.sh
#
# Zeigt eine Checkliste empfohlener Programme nach Kategorien
# (angelehnt an die Discover-Kategorien) und installiert die
# ausgewählten per apt.

SELECTION=$(zenity --list --checklist \
    --title="Empfohlene Programme" \
    --text="Wähle zusätzliche Programme zum Installieren aus:" \
    --width=600 --height=550 \
    --column="✓" --column="Kategorie" --column="Programm" --column="Paket" \
    --print-column=4 --hide-column=4 \
    FALSE "Internet"        "Chromium (Browser)"          chromium \
    FALSE "Internet"        "Falkon (Browser)"            falkon \
    FALSE "Internet"        "FileZilla (FTP)"             filezilla \
    FALSE "Büro"            "Scribus (Layout/DTP)"        scribus \
    FALSE "Grafik"          "GIMP (Bildbearbeitung)"      gimp \
    FALSE "Grafik"          "Inkscape (Vektorgrafik)"     inkscape \
    FALSE "Multimedia"      "Kdenlive (Videoschnitt)"     kdenlive \
    FALSE "Bildung"         "Anki (Karteikarten lernen)"  anki \
    FALSE "Bildung"         "Klavaro (Tastschreiben üben)" klavaro \
    FALSE "Spiele"          "0 A.D. (Strategiespiel)"     0ad \
    FALSE "Spiele"          "Extreme Tux Racer"           extremetuxracer \
    FALSE "Entwicklung"     "Geany (einfacher Code-Editor)" geany \
    FALSE "Dienstprogramme" "GParted (Partitionen verwalten)" gparted \
    FALSE "Dienstprogramme" "BleachBit (Datenträger aufräumen)" bleachbit \
    )

if [ -z "$SELECTION" ]; then
    exit 0
fi

# Ausgewählte Pakete (durch | getrennt) in eine Leerzeichen-Liste umwandeln
PACKAGES=$(echo "$SELECTION" | tr '|' ' ')

if [ -n "$PACKAGES" ]; then
    (
        echo "10" ; echo "# Aktualisiere Paketliste..."
        pkexec apt-get update &> /tmp/pingulinux-apt-install.log

        echo "40" ; echo "# Installiere ausgewählte Programme..."
        pkexec apt-get install -y $PACKAGES &>> /tmp/pingulinux-apt-install.log
        INSTALL_EXIT=$?

        echo "100" ; echo "# Fertig!"
        sleep 1

        exit $INSTALL_EXIT
    ) | zenity --progress \
        --title="Programme werden installiert" \
        --text="Bitte warten..." \
        --width=400 \
        --auto-close \
        --no-cancel

    if [ $? -eq 0 ]; then
        zenity --info --title="Fertig" --text="Die ausgewählten Programme wurden erfolgreich installiert." --width=350
    else
        zenity --error --title="Fehler" --text="Bei der Installation ist ein Fehler aufgetreten.\n\nDetails: /tmp/pingulinux-apt-install.log" --width=400
    fi
fi
