#!/bin/bash
#
# pingulinux-help.sh - Hilfe-Menue mit Verknuepfungen zu den Pingulinux-Seiten.
# Die Adressen stehen in /etc/pingulinux/links.conf (leer = noch in Arbeit).

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
TITLE="Hilfe - Pingulinux OS"
source /etc/pingulinux/links.conf 2>/dev/null

open_link() {  # $1 Adresse, $2 Name
    if [ -z "$1" ]; then
        zenity --info --title="$TITLE" --width=380 --text="🚧 Die Seite „$2“ ist noch in Arbeit.\n\nSchau bald wieder vorbei!"
    else
        xdg-open "$1" >/dev/null 2>&1 &
    fi
}

while true; do
    CHOICE=$(zenity --list --title="$TITLE" --width=520 --height=520 --hide-header \
        --text="<big><b>Wie können wir helfen? 🐧</b></big>" --column="x" \
        --ok-label="Öffnen" --cancel-label="Zurück" \
        "🌐  Pingulinux-Webseite" \
        "📘  Anleitungen" \
        "💬  Community und Forum" \
        "🐞  Fehler melden" \
        "🛠️  Fehlerdiagnose starten" \
        "🔒  Datenschutz" \
        "📄  Impressum" \
        "❤️  Pingulinux unterstützen" \
        "ℹ️  Kurzhilfe zum Kontrollzentrum")

    case "$CHOICE" in
        "🌐"*) open_link "$WEBSEITE" "Pingulinux-Webseite" ;;
        "📘"*) open_link "$ANLEITUNGEN" "Anleitungen" ;;
        "💬"*) open_link "$COMMUNITY" "Community und Forum" ;;
        "🐞"*) open_link "$FEHLER_MELDEN" "Fehler melden" ;;
        "🛠️"*) /usr/local/bin/pingulinux-diagnose.sh ;;
        "🔒"*) open_link "$DATENSCHUTZ" "Datenschutz" ;;
        "📄"*) open_link "$IMPRESSUM" "Impressum" ;;
        "❤️"*) open_link "$SPENDEN" "Unterstützen" ;;
        "ℹ️"*) zenity --info --title="$TITLE" --width=450 --text="Pingulinux OS - Eltern-Kontrollzentrum\n\n• Bildschirmzeit: Zeitlimits pro Kind einstellen\n• Firewall: Netzwerk-Zugriffsregeln verwalten\n• Kinderschutz-Filter: Blockiert Erwachsenen-/Gewaltinhalte\n• Drucker und Scanner einrichten\n• Sicherung und Wiederherstellung\n• Benutzerkonten: Kinder mit Alter anlegen\n• Update-Assistent und Systembereinigung\n• App Store: ausgesuchte, kindgeeignete Programme" ;;
        *) break ;;
    esac
done
