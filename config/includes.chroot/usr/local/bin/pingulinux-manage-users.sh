#!/bin/bash
#
# pingulinux-manage-users.sh
#
# Einfache Benutzerverwaltung ohne sichtbares Terminal-Fenster.
# Neue Benutzer werden automatisch eingeschränkt angelegt: kein
# Admin-Konto (keine sudo-Gruppe) und ohne Zugriff auf den
# Terminal-Emulator.

# Dialog-Fenster (kdialog, sonst zenity) mit Pingulinux-Logo
. /usr/local/lib/pingulinux/dialog.sh
# Fragt nach einem Profilbild (Galerie). Gibt den Dateipfad aus (leer = Standardbild)
choose_avatar() {
    /usr/local/bin/pingulinux-pick-avatar.py "$1" 2>/dev/null
}
# Auswahl eines Benutzerkontos (Name wie im Anmeldebildschirm, dahinter der Benutzername)
pick_user() {
    local args=() u name
    while IFS=: read -r u _ uid _ gecos _; do
        [ "$uid" -ge 1000 ] && [ "$uid" -lt 60000 ] || continue
        name="${gecos%%,*}"
        args+=("$u" "${name:-$u} ($u)")
    done < <(getent passwd)
    pd_menue "$1" "Für wen?" "${args[@]}"
}

while true; do
    ACTION=$(pd_menue "Benutzerkonten verwalten" "Was möchtest du tun?" \
        "Neuen Benutzer anlegen" "➕  Neuen Benutzer anlegen" \
        "Profilbild ändern" "🖼️  Profilbild ändern" \
        "Passwort ändern" "🔑  Passwort ändern" \
        "Benutzer löschen" "🗑️  Benutzer löschen")

    case "$ACTION" in
        "Neuen Benutzer anlegen")
            NEWUSER=$(pd_eingabe "Neuer Benutzer" "Name des neuen Benutzerkontos:")
            if [ -z "$NEWUSER" ]; then
                continue
            fi

            PASS1=$(pd_passwort "Neuer Benutzer" "Passwort für $NEWUSER festlegen:")
            if [ -z "$PASS1" ]; then
                continue
            fi
            PASS2=$(pd_passwort "Neuer Benutzer" "Passwort wiederholen:")

            if [ "$PASS1" != "$PASS2" ]; then
                pd_fehler "Fehler" "⚠️ Die Passwörter stimmen nicht überein."
                continue
            fi

            YNOW=$(date +%Y)
            YEARS=$(seq "$YNOW" -1 $((YNOW - 17)) | paste -sd'|')
            # Geburtsmonat und -jahr (zwei kleine Auswahlfenster)
            BMON_NAME=$(pd_combo "Geburtstag von $NEWUSER" "In welchem Monat wurde $NEWUSER geboren?\nDas Alter bestimmt automatisch Bildschirmzeit und Schutzeinstellungen und wächst mit dem Kind mit." \
                "Januar" Januar Februar März April Mai Juni Juli August September Oktober November Dezember) || continue
            # shellcheck disable=SC2086
            BYEAR=$(pd_combo "Geburtstag von $NEWUSER" "In welchem Jahr wurde $NEWUSER geboren?" "$((YNOW - 6))" ${YEARS//|/ }) || continue
            case "$BMON_NAME" in
                Januar) BMON=01;; Februar) BMON=02;; "März") BMON=03;; April) BMON=04;; Mai) BMON=05;; Juni) BMON=06;;
                Juli) BMON=07;; August) BMON=08;; September) BMON=09;; Oktober) BMON=10;; November) BMON=11;; Dezember) BMON=12;;
                *) pd_fehler "Fehler" "⚠️ Bitte Geburtsmonat und -jahr auswählen."; continue;;
            esac
            case "$BYEAR" in [0-9][0-9][0-9][0-9]) ;; *) pd_fehler "Fehler" "⚠️ Bitte Geburtsmonat und -jahr auswählen."; continue;; esac
            BIRTH="$BYEAR-$BMON"
            AGE=$(/usr/local/bin/pingulinux-age-from-birth.sh "$BIRTH")

            AVATAR=$(choose_avatar "$NEWUSER")

            if echo "$PASS1" | pkexec /usr/local/bin/pingulinux-create-restricted-user.sh "$NEWUSER" "$BIRTH" "$AVATAR"; then
                if [ "$AGE" -lt 13 ]; then
                    SOCIAL="\n• Social-Media-Seiten und normales YouTube sind gesperrt (gilt nur für dieses Konto, im Firefox).\n• YouTube Kids liegt auf dem Desktop."
                else
                    SOCIAL=""
                fi
                pd_info "Fertig" "✅ Benutzerkonto '$NEWUSER' wurde angelegt.\n\n• Eingeschränktes Konto (kein Admin, kein Terminal)\n• Bildschirmzeit automatisch passend für $AGE Jahre (wächst mit dem Kind mit)$SOCIAL\n\nDie Zeiten kannst du im Kontrollzentrum unter „Bildschirmzeit“ anpassen."
            else
                pd_fehler "Fehler" "⚠️ Das Benutzerkonto konnte nicht angelegt werden."
            fi
            ;;
        "Profilbild ändern")
            TARGET=$(pick_user "Profilbild ändern")
            if [ -n "$TARGET" ]; then
                IMG=$(choose_avatar "$TARGET")
                if [ -n "$IMG" ]; then
                    if pkexec /usr/local/bin/pingulinux-set-avatar.sh "$TARGET" "$IMG"; then
                        pd_info "Fertig" "✅ Das Profilbild von '$TARGET' wurde geändert.\n\nBeim nächsten Anmelden ist es überall zu sehen."
                    else
                        pd_fehler "Fehler" "⚠️ Das Profilbild konnte nicht geändert werden."
                    fi
                fi
            fi
            ;;
        "Passwort ändern")
            TARGET=$(pick_user "Passwort ändern")
            if [ -n "$TARGET" ]; then
                NEWPASS1=$(pd_passwort "Passwort ändern" "Neues Passwort für $TARGET:")
                if [ -z "$NEWPASS1" ]; then
                    continue
                fi
                NEWPASS2=$(pd_passwort "Neuer Benutzer" "Passwort wiederholen:")
                if [ "$NEWPASS1" != "$NEWPASS2" ]; then
                    pd_fehler "Fehler" "⚠️ Die Passwörter stimmen nicht überein."
                    continue
                fi
                if ERR=$(printf '%s' "$NEWPASS1" | pkexec /usr/local/bin/pingulinux-set-password.sh "$TARGET" 2>&1); then
                    pd_info "Fertig" "✅ Passwort für '$TARGET' wurde geändert."
                else
                    pd_fehler_roh "Fehler" "⚠️ Das Passwort konnte nicht geändert werden.

$ERR"
                fi
            fi
            ;;
        "Benutzer löschen")
            TARGET=$(pick_user "Benutzer löschen")
            if [ -n "$TARGET" ]; then
                if pd_frage "Wirklich löschen?" "Benutzer '$TARGET' mit allen eigenen Dateien wirklich löschen?" "Löschen" "Abbrechen"; then
                    if ERR=$(pkexec /usr/local/bin/pingulinux-delete-user.sh "$TARGET" 2>&1); then
                        pd_info "Fertig" "✅ Benutzer '$TARGET' wurde gelöscht."
                    else
                        pd_fehler_roh "Fehler" "⚠️ Der Benutzer konnte nicht gelöscht werden.

$ERR"
                    fi
                fi
            fi
            ;;
        *)
            break
            ;;
    esac
done
