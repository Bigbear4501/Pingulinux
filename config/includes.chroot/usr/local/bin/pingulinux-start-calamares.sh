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

# KDE-Aussehen: sudo setzt die Umgebung zurück, deshalb die KDE-Werte
# ausdrücklich mitgeben.
KDEENV=(QT_QPA_PLATFORMTHEME=kde XDG_CURRENT_DESKTOP=KDE KDE_FULL_SESSION=true
        LANG="${LANG:-de_DE.UTF-8}")

# Bug b22: Über XWayland kamen Zahlen und Sonderzeichen von der
# Bildschirmtastatur falsch an („1234“ wurde zu „!"§$“) – das Passwort aus
# dem Installer stimmte danach nicht. Darum Calamares unter Wayland direkt
# starten; die Bildschirmtastatur liefert dann echte Zeichen.
# Root darf den Wayland-Zugang des Live-Benutzers benutzen, wenn der Pfad
# vollständig angegeben ist. Klappt das nicht, geht es wie früher über XWayland.
start_wayland() {
    local sock="$WAYLAND_DISPLAY"
    [ -n "$sock" ] || return 1
    case "$sock" in /*) ;; *) sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/$sock" ;; esac
    [ -S "$sock" ] || return 1
    sudo env "${KDEENV[@]}" QT_QPA_PLATFORM=wayland WAYLAND_DISPLAY="$sock" \
        XDG_RUNTIME_DIR=/run/user/0 calamares &
    CALAMARES_PID=$!
    # Stirbt Calamares in den ersten Sekunden, hat Wayland nicht geklappt.
    for _ in 1 2 3 4 5 6; do
        sleep 1
        kill -0 "$CALAMARES_PID" 2>/dev/null || { wait "$CALAMARES_PID"; [ $? -eq 0 ] && exit 0; return 1; }
    done
    return 0
}
start_xwayland() {
    sudo env "${KDEENV[@]}" DISPLAY="$DISPLAY" XAUTHORITY="${XAUTHORITY:-}" calamares &
    CALAMARES_PID=$!
}
sudo mkdir -p -m 700 /run/user/0 2>/dev/null
start_wayland || start_xwayland

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
