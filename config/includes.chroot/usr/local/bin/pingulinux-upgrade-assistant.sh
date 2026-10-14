#!/bin/bash
#
# pingulinux-upgrade-assistant.sh
# Update-Assistent: normale Updates und Wechsel auf eine neue Debian-Version.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
TITLE="Update-Assistent"

if grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    zenity --info --title="$TITLE" --width=420 \
        --text="ℹ️ Im Live-Modus läuft Pingulinux nur im Arbeitsspeicher.\n\nUpdates und ein Versionswechsel sind erst nach der Installation auf die Festplatte möglich."
    exit 0
fi

number() { case "$1" in bookworm) echo 12;; trixie) echo 13;; forky) echo 14;; duke) echo 15;; *) echo "$1";; esac; }

run_with_progress() {  # $1 Text, Rest: Befehl
    local text="$1"; shift
    ( "$@"; echo $? > /tmp/pingulinux-upgrade.rc ) &
    local pid=$!
    ( while kill -0 $pid 2>/dev/null; do echo "# $text"; sleep 2; done; echo 100 ) \
        | zenity --progress --pulsate --auto-close --no-cancel --title="$TITLE" --width=460 --text="$text"
    wait $pid
    return "$(cat /tmp/pingulinux-upgrade.rc 2>/dev/null || echo 1)"
}

CHOICE=$(zenity --list --title="$TITLE" --width=520 --height=300 --hide-header \
    --text="<big><b>Was möchtest du tun?</b></big>" --column="x" \
    --ok-label="Weiter" --cancel-label="Zurück" \
    "🔄  Updates installieren (gleiche Debian-Version)" \
    "🚀  Auf neue Debian-Version wechseln")
[ -z "$CHOICE" ] && exit 0

case "$CHOICE" in
"🔄"*)
    zenity --question --title="$TITLE" --width=420 --ok-label="Starten" --cancel-label="Abbrechen" \
        --text="Alle verfügbaren Updates werden jetzt installiert.\nDas kann einige Minuten dauern. Bitte Gerät am Strom lassen." || exit 0
    if run_with_progress "Updates werden installiert…" pkexec /usr/local/bin/pingulinux-update-worker.sh; then
        zenity --info --title="$TITLE" --width=380 --text="✅ Alles ist auf dem neuesten Stand."
    else
        zenity --error --title="$TITLE" --width=460 --no-markup \
            --text="⚠️ Beim Aktualisieren ist ein Fehler aufgetreten.

Die letzten Zeilen des Protokolls (/var/log/pingulinux-update.log):

$(tail -n 8 /var/log/pingulinux-update.log 2>/dev/null)"
    fi
    ;;
"🚀"*)
    CUR=$(. /etc/os-release; echo "$VERSION_CODENAME")
    NEWC=$(curl -fsS -m 15 https://deb.debian.org/debian/dists/stable/Release 2>/dev/null | sed -n 's/^Codename: //p' | head -1)
    if [ -z "$NEWC" ]; then
        zenity --error --title="$TITLE" --width=420 --text="⚠️ Ich konnte nicht prüfen, ob es eine neue Debian-Version gibt.\nBitte prüfe die Internetverbindung."
        exit 1
    fi
    if [ "$NEWC" = "$CUR" ]; then
        zenity --info --title="$TITLE" --width=420 \
            --text="✅ Du hast schon die neueste Debian-Version: <b>Debian $(number "$CUR") ($CUR)</b>.\n\nNormale Updates bekommst du über „Updates installieren“."
        exit 0
    fi
    zenity --question --title="$TITLE" --width=500 --ok-label="Ja, weiter" --cancel-label="Abbrechen" \
        --text="🚀 Es gibt eine neue Debian-Version:\n\n<b>Debian $(number "$CUR") ($CUR)  →  Debian $(number "$NEWC") ($NEWC)</b>\n\nDer Wechsel dauert 30 bis 90 Minuten.\n• Das Gerät muss am Strom bleiben.\n• Die Internetverbindung muss durchgehend bestehen.\n• Vorher wird eine Sicherung (Timeshift) erstellt.\n\nMöchtest du fortfahren?" || exit 0

    MODE=backup
    run_with_progress "Sicherung und Wechsel auf Debian $(number "$NEWC")… Bitte nicht ausschalten!" pkexec /usr/local/bin/pingulinux-upgrade-worker.sh "$CUR" "$NEWC" backup
    RC=$?
    if [ "$RC" = 20 ]; then
        if zenity --question --title="$TITLE" --width=500 --ok-label="Trotzdem fortfahren" --cancel-label="Abbrechen" \
            --text="⚠️ Die Sicherung konnte nicht erstellt werden.\n\nTipp: Richte zuerst unter „Sicherung und Wiederherstellung“ Timeshift ein.\n\nOhne Sicherung fortzufahren ist riskant. Wirklich weitermachen?"; then
            run_with_progress "Debian $(number "$NEWC") wird installiert… Bitte nicht ausschalten!" pkexec /usr/local/bin/pingulinux-upgrade-worker.sh "$CUR" "$NEWC" nobackup
            RC=$?
        else
            exit 0
        fi
    fi

    if [ "$RC" = 0 ]; then
        zenity --question --title="$TITLE" --width=440 --ok-label="Jetzt neu starten" --cancel-label="Später" \
            --text="✅ Fertig! Pingulinux läuft jetzt auf Debian $(number "$NEWC").\n\nBitte starte den Computer neu." && systemctl reboot
    else
        zenity --error --title="$TITLE" --width=480 --no-markup \
            --text="⚠️ Der Wechsel ist fehlgeschlagen.

Deine alten Paketquellen wurden – wenn möglich – wiederhergestellt.
Du kannst über „Sicherung und Wiederherstellung“ den alten Stand zurückholen.

Die letzten Zeilen des Protokolls (/var/log/pingulinux-upgrade.log):

$(tail -n 8 /var/log/pingulinux-upgrade.log 2>/dev/null)"
    fi
    ;;
esac
