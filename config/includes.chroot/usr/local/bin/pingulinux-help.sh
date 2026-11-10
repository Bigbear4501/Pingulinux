#!/bin/bash
#
# pingulinux-help.sh - Hilfe-Menue mit Verknuepfungen zu den Pingulinux-Seiten.
# Die Adressen stehen in /etc/pingulinux/links.conf (leer = noch in Arbeit).

. /usr/local/lib/pingulinux/dialog.sh
TITLE="Hilfe - Pingulinux OS"
source /etc/pingulinux/links.conf 2>/dev/null

open_link() {  # $1 Adresse, $2 Name
    if [ -z "$1" ]; then
        pd_info "$TITLE" "🚧 Die Seite „$2“ ist noch in Arbeit.\n\nSchau bald wieder vorbei!"
    else
        xdg-open "$1" >/dev/null 2>&1 &
    fi
}

while true; do
    CHOICE=$(pd_menue "$TITLE" "<big><b>Wie können wir helfen? 🐧</b></big>" \
        web "🌐  Pingulinux-Webseite" \
        anleitung "📘  Anleitungen" \
        community "💬  Community und Forum" \
        fehler "🐞  Fehler melden" \
        diagnose "🛠️  Fehlerdiagnose starten" \
        datenschutz "🔒  Datenschutz" \
        impressum "📄  Impressum" \
        spenden "❤️  Pingulinux unterstützen" \
        kurzhilfe "ℹ️  Kurzhilfe zum Kontrollzentrum")

    case "$CHOICE" in
        web) open_link "$WEBSEITE" "Pingulinux-Webseite" ;;
        anleitung) open_link "$ANLEITUNGEN" "Anleitungen" ;;
        community) open_link "$COMMUNITY" "Community und Forum" ;;
        fehler) open_link "$FEHLER_MELDEN" "Fehler melden" ;;
        diagnose) /usr/local/bin/pingulinux-diagnose.sh ;;
        datenschutz) open_link "$DATENSCHUTZ" "Datenschutz" ;;
        impressum) open_link "$IMPRESSUM" "Impressum" ;;
        spenden) open_link "$SPENDEN" "Unterstützen" ;;
        kurzhilfe) pd_info "$TITLE" "Pingulinux OS - Eltern-Kontrollzentrum\n\n• Bildschirmzeit: Zeitlimits pro Kind einstellen\n• Firewall: Netzwerk-Zugriffsregeln verwalten\n• Kinderschutz-Filter: Blockiert Erwachsenen-/Gewaltinhalte\n• Drucker und Scanner einrichten\n• Sicherung und Wiederherstellung\n• Benutzerkonten: Kinder mit Alter anlegen\n• Update-Assistent und Systembereinigung\n• App Store: ausgesuchte, kindgeeignete Programme" ;;
        *) break ;;
    esac
done
