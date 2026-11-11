#!/bin/bash
#
# pingulinux-admin-tool.sh  WERKZEUG
#
# Startet die Verwaltungsprogramme des Eltern-Kontrollzentrums, die
# Administrator-Rechte brauchen. Das Passwort wird in einem Fenster
# abgefragt, auch ohne Terminal.
#
#   bildschirmzeit   Bildschirmzeit der Kinder (eigenes Fenster, sonst Timekpr)
#   bildschirmzeit-timekpr   Timekpr-nExT-Oberfläche (für Fortgeschrittene)
#   firewall         Firewall (KDE plasma-firewall, sonst Gufw)
#   sicherung        Timeshift (Sicherung und Wiederherstellung)
#   konten           Konten-Übersicht (Alter und Bildschirmzeit der Kinder)
#
# Weg 1: pkexec. Das Passwort-Fenster kommt vom Polkit-Agenten der
#        Sitzung (KDE: polkit-kde-agent-1, XFCE: mate-polkit).
# Weg 2: Läuft kein Polkit-Agent, fragt dieses Skript selbst mit einem
#        Fenster (kdialog/zenity) nach dem Passwort und startet das Programm mit sudo.
#        Ohne Agent bricht pkexec sonst still ab ("No authentication agent
#        found"), das war der Fehler im installierten System.
#
# Im Live-System braucht der Live-Benutzer kein Passwort, dort geht Weg 1
# immer ohne Nachfrage.

. /usr/local/lib/pingulinux/dialog.sh

XAUTH="${XAUTHORITY:-$HOME/.Xauthority}"

have_agent() {
    pgrep -f 'polkit-kde-authentication-agent|polkit-mate-authentication-agent|polkit-gnome-authentication-agent|lxpolkit|lxqt-policykit|xfce-polkit' >/dev/null 2>&1
}

sudo_gui() {
    # Passwort im Fenster abfragen und Programm mit sudo starten (3 Versuche).
    local pw try
    for try in 1 2 3; do
        pw=$(pd_passwort "$TITLE" "Passwort eines Erwachsenen:" 2>/dev/null) || return 126
        if printf '%s\n' "$pw" | sudo -k -S -p '' true 2>/dev/null; then
            # sudo merkt sich das Passwort kurz, deshalb kein zweites Mal -S nötig
            printf '%s\n' "$pw" | sudo -S -p '' env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTH" \
                LANG="${LANG:-de_DE.UTF-8}" LANGUAGE="${LANGUAGE:-de_DE:de}" \
                WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" "$@"
            unset pw
            return 0
        fi
        pd_fehler "$TITLE" "Das Passwort stimmt nicht." 2>/dev/null
    done
    unset pw
    return 126
}

gui_root() {
    # Startet ein grafisches Programm als root, mit Passwort-Fenster.
    if have_agent || grep -qw 'boot=live' /proc/cmdline; then
        # LANG mitgeben: pkexec löscht die Umgebung, sonst startet das
        # Programm auf Englisch (z. B. Timekpr-nExT)
        pkexec env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTH" \
            LANG="${LANG:-de_DE.UTF-8}" LANGUAGE="${LANGUAGE:-de_DE:de}" LC_ALL="${LC_ALL:-}" "$@"
    else
        sudo_gui "$@"
    fi
}

case "$1" in
    bildschirmzeit)
        # eigenes Fenster (Qt), Timekpr ist im Menü ausgeblendet
        if python3 -c "import PyQt6.QtWidgets" 2>/dev/null; then
            exec /usr/local/bin/pingulinux-bildschirmzeit.py
        fi
        TITLE="Bildschirmzeit"
        gui_root timekpra
        RC=$?
        ;;
    bildschirmzeit-timekpr)
        # Timekpr-Oberfläche für Fortgeschrittene
        TITLE="Bildschirmzeit"
        gui_root timekpra
        RC=$?
        ;;
    firewall)
        TITLE="Firewall"
        # KDE-Firewall (plasma-firewall, Oberfläche für ufw). Fragt
        # selbst über Polkit nach dem Passwort. Gufw nur noch als Ersatz.
        if command -v kcmshell6 >/dev/null 2>&1 && \
           { ls /usr/lib/*/qt6/plugins/plasma/kcms/systemsettings/kcm_firewall.so >/dev/null 2>&1 || \
             kcmshell6 --list 2>/dev/null | grep -q '^kcm_firewall'; }; then
            kcmshell6 kcm_firewall
            exit 0
        fi
        if ! command -v gufw >/dev/null 2>&1; then
            pd_fehler "$TITLE" "Die Firewall-Einstellungen sind nicht installiert."
            exit 0
        fi
        if have_agent || grep -qw 'boot=live' /proc/cmdline; then
            gufw            # gufw fragt selbst über pkexec nach dem Passwort
        else
            if command -v gufw-pkexec >/dev/null 2>&1; then
                sudo_gui gufw-pkexec
            else
                sudo_gui python3 /usr/share/gufw/gufw/gufw.py
            fi
        fi
        RC=$?
        ;;
    sicherung)
        TITLE="Sicherung und Wiederherstellung"
        STAND=$(cat /var/lib/pingulinux/sicherung-status 2>/dev/null)
        WAHL=$(pd_menue "$TITLE" "<b>💾 Sicherung und Wiederherstellung</b>\n\nTägliche Systemsicherung: ${STAND:-noch nicht gelaufen}" \
            jetzt "💻  System jetzt sichern (auf dieser Festplatte)" \
            usb "🔌  Auf USB-Stick sichern (eigene Dateien und System)" \
            dateien "📁  Eigene Dateien vom Stick zurückholen" \
            timeshift "🕰️  Sicherungen ansehen und System wiederherstellen") || exit 0
        case "$WAHL" in
            jetzt)
                sichern() { pkexec /usr/local/bin/pingulinux-root-helper ts-create >/tmp/pingulinux-sichern-$USER.log 2>&1; }
                if pd_warten "$TITLE" "System wird gesichert … das kann einige Minuten dauern." sichern; then
                    pd_info "$TITLE" "✅ Das System ist gesichert.\n\nDiesen Stand findest du unter „Sicherungen ansehen und System wiederherstellen“."
                else
                    RC=$?
                    if [ "$RC" -eq 126 ] || [ "$RC" -eq 127 ]; then
                        pd_info "$TITLE" "Abgebrochen. Dafür braucht es das Passwort eines Erwachsenen."
                    else
                        pd_fehler "$TITLE" "⚠️ Die Sicherung hat nicht geklappt.\nDetails: /tmp/pingulinux-sichern-$USER.log"
                    fi
                fi
                exit 0 ;;
            usb) exec /usr/local/bin/pingulinux-sicherung-usb.sh ;;
            dateien)
                pd_info "$TITLE" "Stecke den Stick ein. Gleich öffnet sich der Dateimanager.\n\nDie Sicherung liegt auf dem Stick unter\n<b>Pingulinux-Sicherung → $(hostname) → Eigene-Dateien</b>.\nKopiere einfach die Dateien, die du brauchst, zurück in deinen Ordner."
                exec dolphin --new-window "/media/$USER" ;;
            timeshift)
                # eigene Qt-Oberfläche (Timeshift ist im Menü ausgeblendet)
                if python3 -c "import PyQt6.QtWidgets" 2>/dev/null; then
                    exec /usr/local/bin/pingulinux-wiederherstellen.py
                elif command -v timeshift-launcher >/dev/null 2>&1 && { have_agent || grep -qw 'boot=live' /proc/cmdline; }; then
                    timeshift-launcher
                else
                    gui_root timeshift-gtk
                fi ;;
            *) exit 0 ;;
        esac
        RC=$?
        ;;
    konten)
        TITLE="Konten-Übersicht"
        gui_root /usr/local/bin/pingulinux-show-profiles.py
        RC=$?
        ;;
    *)
        echo "Aufruf: $0 bildschirmzeit|bildschirmzeit-timekpr|firewall|sicherung|konten" >&2
        exit 2
        ;;
esac

if [ "$RC" -eq 126 ] || [ "$RC" -eq 127 ]; then
    pd_info "$TITLE" "Abgebrochen. Dafür braucht es das Passwort eines Erwachsenen."
fi
exit 0
