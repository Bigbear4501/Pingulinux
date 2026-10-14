#!/bin/bash
#
# pingulinux-start-calamares.sh
#
# Zeigt zuerst einen Warnhinweis zur Festplatten-Formatierung an.
# Startet Calamares nur, wenn der Nutzer bestätigt. Benennt das
# Fenster im Hintergrund um, da der Fenstertitel "Calamares" fest im
# Programm steckt und nicht über die Branding-Konfiguration änderbar ist.

# Pingulinux-Logo in allen Dialogfenstern
zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
if command -v zenity &> /dev/null; then
    zenity --question \
        --title="Achtung - Vor der Installation" \
        --text="Bei der Installation von Pingulinux OS können Daten auf der Festplatte deines Computers gelöscht werden!\n\nBitte sichere wichtige Daten vorher an einem anderen Ort (z.B. USB-Stick).\n\nMöchtest du jetzt mit der Installation fortfahren?" \
        --ok-label="Ja, fortfahren" \
        --cancel-label="Abbrechen" \
        --width=420

    if [ $? -ne 0 ]; then
        # Abgebrochen - Installer nicht starten
        exit 0
    fi

    zenity --info \
        --title="Hinweis zum Benutzerkonto" \
        --text="Auf der nächsten Seite legst du ein Benutzerkonto an.\n\nDieses erste Konto ist für ein Elternteil gedacht (mit vollen Rechten).\n\nEigene Konten für Kinder kannst du danach jederzeit über die Systemeinstellungen zusätzlich anlegen." \
        --ok-label="Verstanden" \
        --width=420
fi

env QT_QPA_PLATFORMTHEME=gtk3 sudo calamares &
CALAMARES_PID=$!

# Im Hintergrund wiederholt versuchen, das Fenster umzubenennen,
# sobald es erscheint (kann ein paar Sekunden dauern, bis es da ist)
(
    for i in $(seq 1 30); do
        if command -v wmctrl &> /dev/null; then
            if wmctrl -l | grep -qi "calamares"; then
                wmctrl -r "Calamares" -N "Pingulinux OS installieren"
                break
            fi
        fi
        sleep 0.5
    done
) &

wait "$CALAMARES_PID"
