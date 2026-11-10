#!/bin/bash
#
# pingulinux-start-calamares.sh
#
# Zeigt zuerst einen Warnhinweis zur Festplatten-Formatierung an.
# Startet Calamares nur, wenn der Nutzer bestätigt. Benennt das
# Fenster im Hintergrund um, da der Fenstertitel "Calamares" fest im
# Programm steckt und nicht über die Branding-Konfiguration änderbar ist.

# Dialog-Fenster (kdialog, sonst zenity) mit Pingulinux-Logo
. /usr/local/lib/pingulinux/dialog.sh
if command -v kdialog >/dev/null 2>&1 || command -v zenity >/dev/null 2>&1; then
    pd_frage "Achtung - Vor der Installation" "Bei der Installation von Pingulinux OS können Daten auf der Festplatte deines Computers gelöscht werden!\n\nBitte sichere wichtige Daten vorher an einem anderen Ort (z.B. USB-Stick).\n\nMöchtest du jetzt mit der Installation fortfahren?" "Ja, fortfahren" "Abbrechen"

    if [ $? -ne 0 ]; then
        # Abgebrochen - Installer nicht starten
        exit 0
    fi

    pd_info "Hinweis zum Benutzerkonto" "Auf der nächsten Seite legst du ein Benutzerkonto an.\n\nDieses erste Konto ist für ein Elternteil gedacht (mit vollen Rechten).\n\nEigene Konten für Kinder kannst du danach jederzeit im Eltern-Kontrollzentrum unter „Benutzerkonten“ anlegen." "Verstanden"
fi

# KDE-Aussehen: früher QT_QPA_PLATFORMTHEME=gtk3 (alter GTK-Desktop). sudo setzt die
# Umgebung zurück, deshalb die KDE-Werte ausdrücklich mitgeben.
# Wie bisher über XWayland (DISPLAY), nur mit KDE-Aussehen.
sudo env QT_QPA_PLATFORMTHEME=kde XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true \
    DISPLAY="$DISPLAY" XAUTHORITY="${XAUTHORITY:-}" LANG="${LANG:-de_DE.UTF-8}" calamares &
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
