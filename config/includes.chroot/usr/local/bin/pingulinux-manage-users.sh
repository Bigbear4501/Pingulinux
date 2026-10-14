#!/bin/bash
#
# pingulinux-manage-users.sh
#
# Einfache Benutzerverwaltung ohne sichtbares Terminal-Fenster.
# Neue Benutzer werden automatisch eingeschränkt angelegt: kein
# Admin-Konto (keine sudo-Gruppe) und ohne Zugriff auf den
# Terminal-Emulator.

# Pingulinux-Logo in allen Dialogfenstern
zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
# Fragt nach einem Profilbild (Galerie). Gibt den Dateipfad aus (leer = Standardbild)
choose_avatar() {
    /usr/local/bin/pingulinux-pick-avatar.py "$1" 2>/dev/null
}

while true; do
    ACTION=$(zenity --list \
        --title="Benutzerkonten verwalten" \
        --column="Aktion" \
        --width=400 --height=250 \
        "Neuen Benutzer anlegen" \
        "Profilbild ändern" \
        "Passwort ändern" \
        "Benutzer löschen")

    case "$ACTION" in
        "Neuen Benutzer anlegen")
            NEWUSER=$(zenity --entry --title="Neuer Benutzer" --text="Name des neuen Benutzerkontos:")
            if [ -z "$NEWUSER" ]; then
                continue
            fi

            PASS1=$(zenity --password --title="Passwort für $NEWUSER festlegen")
            if [ -z "$PASS1" ]; then
                continue
            fi
            PASS2=$(zenity --password --title="Passwort wiederholen")

            if [ "$PASS1" != "$PASS2" ]; then
                zenity --error --title="Fehler" --text="⚠️ Die Passwörter stimmen nicht überein." --width=350
                continue
            fi

            AGE=$(zenity --scale --title="Alter von $NEWUSER" --text="Wie alt ist das Kind?\nDas Alter bestimmt automatisch Bildschirmzeit und Schutzeinstellungen." --min-value=2 --max-value=17 --value=8 --step=1)
            [ -z "$AGE" ] && continue

            AVATAR=$(choose_avatar "$NEWUSER")

            if echo "$PASS1" | pkexec /usr/local/bin/pingulinux-create-restricted-user.sh "$NEWUSER" "$AGE" "$AVATAR"; then
                if [ "$AGE" -lt 13 ]; then
                    SOCIAL="\n• Social-Media-Seiten und normales YouTube sind gesperrt (gilt für den ganzen Computer).\n• YouTube Kids liegt auf dem Desktop (nur mit Eltern-Freigabe)."
                else
                    SOCIAL=""
                fi
                zenity --info --title="Fertig" --text="✅ Benutzerkonto '$NEWUSER' wurde angelegt.\n\n• Eingeschränktes Konto (kein Admin, kein Terminal)\n• Bildschirmzeit automatisch passend für $AGE Jahre$SOCIAL\n\nDie Zeiten kannst du im Kontrollzentrum unter „Bildschirmzeit“ anpassen." --width=450
            else
                zenity --error --title="Fehler" --text="⚠️ Das Benutzerkonto konnte nicht angelegt werden." --width=350
            fi
            ;;
        "Profilbild ändern")
            EXISTING=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
            TARGET=$(echo "$EXISTING" | zenity --list --title="Profilbild ändern" --text="Für wen?" --column="Benutzer" --width=350 --height=300)
            if [ -n "$TARGET" ]; then
                IMG=$(choose_avatar "$TARGET")
                if [ -n "$IMG" ]; then
                    if pkexec /usr/local/bin/pingulinux-set-avatar.sh "$TARGET" "$IMG"; then
                        zenity --info --title="Fertig" --text="✅ Das Profilbild von '$TARGET' wurde geändert.\n\nBeim nächsten Anmelden ist es überall zu sehen." --width=380
                    else
                        zenity --error --title="Fehler" --text="⚠️ Das Profilbild konnte nicht geändert werden." --width=350
                    fi
                fi
            fi
            ;;
        "Passwort ändern")
            EXISTING=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
            TARGET=$(echo "$EXISTING" | zenity --list --title="Passwort ändern" --column="Benutzer" --width=350 --height=300)
            if [ -n "$TARGET" ]; then
                NEWPASS1=$(zenity --password --title="Neues Passwort für $TARGET")
                if [ -z "$NEWPASS1" ]; then
                    continue
                fi
                NEWPASS2=$(zenity --password --title="Passwort wiederholen")
                if [ "$NEWPASS1" != "$NEWPASS2" ]; then
                    zenity --error --title="Fehler" --text="⚠️ Die Passwörter stimmen nicht überein." --width=350
                    continue
                fi
                if ERR=$(printf '%s' "$NEWPASS1" | pkexec /usr/local/bin/pingulinux-set-password.sh "$TARGET" 2>&1); then
                    zenity --info --title="Fertig" --text="✅ Passwort für '$TARGET' wurde geändert." --width=350
                else
                    zenity --error --title="Fehler" --no-markup --text="⚠️ Das Passwort konnte nicht geändert werden.

$ERR" --width=420
                fi
            fi
            ;;
        "Benutzer löschen")
            EXISTING=$(getent passwd | awk -F: '$3 >= 1000 && $3 < 60000 {print $1}')
            TARGET=$(echo "$EXISTING" | zenity --list --title="Benutzer löschen" --column="Benutzer" --width=350 --height=300)
            if [ -n "$TARGET" ]; then
                zenity --question --title="Wirklich löschen?" --text="Benutzer '$TARGET' inklusive Home-Verzeichnis wirklich löschen?" --width=350
                if [ $? -eq 0 ]; then
                    if ERR=$(pkexec /usr/local/bin/pingulinux-delete-user.sh "$TARGET" 2>&1); then
                        zenity --info --title="Fertig" --text="✅ Benutzer '$TARGET' wurde gelöscht." --width=350
                    else
                        zenity --error --title="Fehler" --no-markup --text="⚠️ Der Benutzer konnte nicht gelöscht werden.

$ERR" --width=420
                    fi
                fi
            fi
            ;;
        *)
            break
            ;;
    esac
done
