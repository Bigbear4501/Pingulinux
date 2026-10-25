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

            YNOW=$(date +%Y)
            YEARS=$(seq "$YNOW" -1 $((YNOW - 17)) | paste -sd'|')
            FORM=$(zenity --forms --title="Geburtstag von $NEWUSER" --width=380 \
                --text="Wann wurde das Kind geboren?\nDas Alter bestimmt automatisch Bildschirmzeit und Schutzeinstellungen und wächst mit dem Kind mit." \
                --add-combo="Geburtsmonat" --combo-values="Januar|Februar|März|April|Mai|Juni|Juli|August|September|Oktober|November|Dezember" \
                --add-combo="Geburtsjahr" --combo-values="$YEARS" --separator=";")
            [ -z "$FORM" ] && continue
            BMON_NAME="${FORM%%;*}"; BYEAR="${FORM##*;}"
            case "$BMON_NAME" in
                Januar) BMON=01;; Februar) BMON=02;; "März") BMON=03;; April) BMON=04;; Mai) BMON=05;; Juni) BMON=06;;
                Juli) BMON=07;; August) BMON=08;; September) BMON=09;; Oktober) BMON=10;; November) BMON=11;; Dezember) BMON=12;;
                *) zenity --error --title="Fehler" --text="⚠️ Bitte Geburtsmonat und -jahr auswählen." --width=350; continue;;
            esac
            case "$BYEAR" in [0-9][0-9][0-9][0-9]) ;; *) zenity --error --title="Fehler" --text="⚠️ Bitte Geburtsmonat und -jahr auswählen." --width=350; continue;; esac
            BIRTH="$BYEAR-$BMON"
            AGE=$(/usr/local/bin/pingulinux-age-from-birth.sh "$BIRTH")

            AVATAR=$(choose_avatar "$NEWUSER")

            if echo "$PASS1" | pkexec /usr/local/bin/pingulinux-create-restricted-user.sh "$NEWUSER" "$BIRTH" "$AVATAR"; then
                if [ "$AGE" -lt 13 ]; then
                    SOCIAL="\n• Social-Media-Seiten und normales YouTube sind gesperrt (gilt nur für dieses Konto, im Firefox).\n• YouTube Kids liegt auf dem Desktop (nur mit Eltern-Freigabe)."
                else
                    SOCIAL=""
                fi
                zenity --info --title="Fertig" --text="✅ Benutzerkonto '$NEWUSER' wurde angelegt.\n\n• Eingeschränktes Konto (kein Admin, kein Terminal)\n• Bildschirmzeit automatisch passend für $AGE Jahre (wächst mit dem Kind mit)$SOCIAL\n\nDie Zeiten kannst du im Kontrollzentrum unter „Bildschirmzeit“ anpassen." --width=450
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
