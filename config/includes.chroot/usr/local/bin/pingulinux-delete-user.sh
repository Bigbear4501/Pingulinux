#!/bin/bash
#
# pingulinux-delete-user.sh  (als root, via pkexec)
# Aufruf: BENUTZER
# Loescht ein Konto samt Home-Ordner und raeumt alle Pingulinux-Reste auf
# (Altersprofil, Programmsperren, Bildschirmzeit, Profilbild, Hosts-Sperre).

U="$1"
CALLER_UID="${PKEXEC_UID:-}"

[ -n "$U" ] || { echo "Es wurde kein Konto angegeben."; exit 2; }
UID_N=$(id -u "$U" 2>/dev/null) || { echo "Das Konto '$U' gibt es nicht."; exit 3; }
if [ "$UID_N" -lt 1000 ] || [ "$UID_N" -ge 60000 ]; then
    echo "Dieses Konto darf hier nicht gelöscht werden."; exit 3
fi
if [ -n "$CALLER_UID" ] && [ "$UID_N" = "$CALLER_UID" ]; then
    echo "Du kannst nicht das Konto löschen, mit dem du gerade angemeldet bist."; exit 3
fi
# Nie das letzte Administrator-Konto loeschen
if id -nG "$U" | tr ' ' '\n' | grep -qx sudo; then
    ADMINS=$(getent group sudo | cut -d: -f4 | tr ',' '\n' | grep -c .)
    if [ "$ADMINS" -le 1 ]; then
        echo "Das ist das einzige Administrator-Konto und darf nicht gelöscht werden."; exit 3
    fi
fi

# Programmsperren (ACLs) des Kontos entfernen, damit eine spaetere neue
# Benutzer-Nummer nicht versehentlich gesperrt wird
python3 - "$U" <<'PY' 2>/dev/null
import json, os, shutil, subprocess, sys
user = sys.argv[1]
cmds = {"/usr/bin/xfce4-terminal"}
for src in ("/usr/share/pingulinux/store-apps.json", "/usr/share/pingulinux/app-ages.json"):
    try:
        for e in json.load(open(src, encoding="utf-8")):
            if e.get("cmd"):
                cmds.add(e["cmd"])
    except Exception:
        pass
for cmd in cmds:
    path = cmd if cmd.startswith("/") else shutil.which(cmd, path="/usr/bin:/usr/games:/usr/local/bin:/bin")
    if path and os.path.exists(path):
        subprocess.run(["setfacl", "-x", "u:%s" % user, os.path.realpath(path)], capture_output=True)
PY

# Angemeldete Sitzungen und Prozesse des Kontos beenden
loginctl terminate-user "$U" >/dev/null 2>&1
pkill -KILL -u "$U" >/dev/null 2>&1
sleep 1

# Konto loeschen
if ! OUT=$(deluser --remove-home "$U" 2>&1); then
    if ! OUT2=$(userdel -r -f "$U" 2>&1); then
        echo "Das Konto konnte nicht gelöscht werden:"
        echo "$OUT"; echo "$OUT2"
        exit 4
    fi
fi

# Reste aufraeumen
rm -f "/var/lib/pingulinux/profiles/$U"
rm -f "/var/lib/AccountsService/users/$U" "/var/lib/AccountsService/icons/$U"
rm -f /var/lib/timekpr/config/timekpr."$U".conf /var/lib/timekpr/work/"$U".* 2>/dev/null
rm -rf "/var/mail/$U" 2>/dev/null

# Hosts-Sperre aktualisieren (faellt weg, wenn kein Kind unter 13 mehr da ist)
/usr/local/bin/pingulinux-update-social-block.sh >/dev/null 2>&1
systemctl restart timekpr >/dev/null 2>&1 || systemctl restart timekprd >/dev/null 2>&1
exit 0
