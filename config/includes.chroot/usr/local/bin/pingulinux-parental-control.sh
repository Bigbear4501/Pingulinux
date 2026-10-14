#!/bin/bash
#
# pingulinux-parental-control.sh
#
# Eltern-Kontrollzentrum: passwortgeschütztes Menü, das die
# wichtigsten Verwaltungswerkzeuge bündelt.

# --- Passwort-Abfrage (sudo-Passwort des Nutzers) ---
# Pingulinux-Logo in allen Dialogfenstern
zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
# Im Live-Modus gibt es keine Passwort-Abfrage (Testsystem, Sudo ohne Passwort).
# Auf dem installierten System wird das Administrator-Passwort geprueft.
if ! grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    sudo -k  # bisherigen sudo-Cache verwerfen, damit wirklich neu geprüft wird

    PASSWORD=$(zenity --password --title="Eltern-Kontrollzentrum - Anmeldung" --ok-label="Anmelden" --cancel-label="Abbrechen")
    if [ -z "$PASSWORD" ]; then
        exit 0
    fi

    if ! echo "$PASSWORD" | sudo -S true 2>/dev/null; then
        zenity --error --title="Eltern-Kontrollzentrum" --text="⚠️ Das Passwort stimmt nicht. Bitte versuche es noch einmal." --width=340
        exit 1
    fi
fi

# --- Hauptmenü ---
while true; do
    CHOICE=$(zenity --list \
        --title="Eltern-Kontrollzentrum" \
        --text="<big><b>Hallo! 🐧 Was möchtest du verwalten?</b></big>" \
        --column="Funktion" \
        --width=520 --height=680 --ok-label="Öffnen" --cancel-label="Beenden" --hide-header \
        "⏰  Bildschirmzeit" \
        "🛡️  Firewall und Netzwerk" \
        "🌐  Kinderschutz-Filter ein/aus" \
        "🖨️  Drucker und Scanner" \
        "💾  Sicherung und Wiederherstellung" \
        "👨‍👩‍👧  Benutzerkonten" \
        "🛍️  Pingulinux App Store" \
        "🚀  Update-Assistent (neue Debian-Version)" \
        "🧹  Systembereinigung" \
        "🛠️  Hilfe und Fehlerdiagnose" \
        "❓  Hilfe")

    case "$CHOICE" in
        "⏰  Bildschirmzeit")
            sudo timekpra &
            ;;
        "🛡️  Firewall und Netzwerk")
            sudo gufw &
            ;;
        "🌐  Kinderschutz-Filter ein/aus")
            /usr/local/bin/pingulinux-toggle-dns-filter.sh
            ;;
        "🖨️  Drucker und Scanner")
            system-config-printer &
            ;;
        "💾  Sicherung und Wiederherstellung")
            sudo timeshift-gtk &
            ;;
        "👨‍👩‍👧  Benutzerkonten")
            /usr/local/bin/pingulinux-manage-users.sh &
            ;;
        "🚀  Update-Assistent (neue Debian-Version)")
            /usr/local/bin/pingulinux-upgrade-assistant.sh
            ;;
        "🧹  Systembereinigung")
            /usr/local/bin/pingulinux-cleanup.sh
            ;;
        "🛠️  Hilfe und Fehlerdiagnose")
            /usr/local/bin/pingulinux-diagnose.sh
            ;;
        "🛍️  Pingulinux App Store")
            /usr/local/bin/pingulinux-store.py &
            ;;
        "❓  Hilfe")
            /usr/local/bin/pingulinux-help.sh
            ;;
        *)
            break
            ;;
    esac
done
