#!/bin/bash
#
# pingulinux-recommended-apps.sh
#
# Zeigt eine Checkliste empfohlener Programme nach Kategorien
# (angelehnt an die Discover-Kategorien) und installiert die
# ausgewählten per apt.

. /usr/local/lib/pingulinux/dialog.sh

SELECTION=$(pd_auswahl "Empfohlene Programme" "Wähle zusätzliche Programme zum Installieren aus:" \
    chromium        "Internet: Chromium (Browser)" aus \
    falkon          "Internet: Falkon (Browser)" aus \
    filezilla       "Internet: FileZilla (FTP)" aus \
    scribus         "Büro: Scribus (Layout/DTP)" aus \
    gimp            "Grafik: GIMP (Bildbearbeitung)" aus \
    inkscape        "Grafik: Inkscape (Vektorgrafik)" aus \
    kdenlive        "Multimedia: Kdenlive (Videoschnitt)" aus \
    anki            "Bildung: Anki (Karteikarten lernen)" aus \
    klavaro         "Bildung: Klavaro (Tastschreiben üben)" aus \
    0ad             "Spiele: 0 A.D. (Strategiespiel)" aus \
    extremetuxracer "Spiele: Extreme Tux Racer" aus \
    geany           "Entwicklung: Geany (einfacher Code-Editor)" aus \
    gparted         "Dienstprogramme: GParted (Partitionen verwalten)" aus \
    bleachbit       "Dienstprogramme: BleachBit (Datenträger aufräumen)" aus)

if [ -z "$SELECTION" ]; then
    exit 0
fi

# Ausgewählte Pakete (eins pro Zeile) in eine Leerzeichen-Liste umwandeln
PACKAGES=$(echo "$SELECTION" | tr -d '"' | tr '\n' ' ')

if [ -n "$PACKAGES" ]; then
    (
        echo "10" ; echo "# Aktualisiere Paketliste..."
        pkexec apt-get update &> /tmp/pingulinux-apt-install.log

        echo "40" ; echo "# Installiere ausgewählte Programme..."
        pkexec apt-get install -y $PACKAGES &>> /tmp/pingulinux-apt-install.log
        echo $? > /tmp/pingulinux-apt-install.rc

        echo "100" ; echo "# Fertig!"
        sleep 1
    ) | pd_fortschritt "Programme werden installiert" "Bitte warten…"

    # Früher wurde hier der Rückgabewert des Fortschrittsfensters geprüft,
    # nicht der von apt – Fehler wurden so als Erfolg gemeldet.
    if [ "$(cat /tmp/pingulinux-apt-install.rc 2>/dev/null)" = 0 ]; then
        pd_info "Fertig" "✅ Die ausgewählten Programme wurden installiert."
    else
        pd_fehler "Fehler" "⚠️ Bei der Installation ist ein Fehler aufgetreten.\n\nDetails: /tmp/pingulinux-apt-install.log"
    fi
fi
