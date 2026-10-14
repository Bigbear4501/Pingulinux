#!/bin/bash
#
# pingulinux-apply-age-profile.sh  (als root; Aufruf: BENUTZER ALTER)
# Setzt aus dem Alter automatisch ein Kinderprofil:
#  - Bildschirmzeit (timekpr-next)
#  - merkt sich das Alter, damit der Social-Media-Block aktuell bleibt

USER_NAME="$1"; AGE="$2"
PROFDIR=/var/lib/pingulinux/profiles
LOG=/var/log/pingulinux-profile.log

[ -n "$USER_NAME" ] && [ "$AGE" -ge 0 ] 2>/dev/null || { echo "Aufruf: $0 BENUTZER ALTER"; exit 2; }

mkdir -p "$PROFDIR"
echo "$AGE" > "$PROFDIR/$USER_NAME"

# Alter -> Minuten Mo-Fr, Minuten Sa-So, erlaubte Stunden
if   [ "$AGE" -le 6 ];  then WD=45;  WE=60;  H="8;9;10;11;12;13;14;15;16;17;18"
elif [ "$AGE" -le 9 ];  then WD=60;  WE=90;  H="8;9;10;11;12;13;14;15;16;17;18;19"
elif [ "$AGE" -le 12 ]; then WD=90;  WE=120; H="7;8;9;10;11;12;13;14;15;16;17;18;19;20"
elif [ "$AGE" -le 14 ]; then WD=120; WE=180; H="7;8;9;10;11;12;13;14;15;16;17;18;19;20"
else                         WD=180; WE=240; H="7;8;9;10;11;12;13;14;15;16;17;18;19;20;21"
fi
WDS=$((WD*60)); WES=$((WE*60))

{
  echo "=== $(date): $USER_NAME, Alter $AGE: ${WD}/${WE} Min, Stunden $H ==="
  # timekpr-Dienst kennt neue Konten erst nach einem Neustart/Lauf
  systemctl restart timekpr 2>/dev/null || systemctl restart timekprd 2>/dev/null
  for i in 1 2 3 4 5; do
    timekpra --userinfo "$USER_NAME" >/dev/null 2>&1 && break
    sleep 2
  done
  timekpra --setalloweddays "$USER_NAME" '1;2;3;4;5;6;7'
  timekpra --settimelimits  "$USER_NAME" "$WDS;$WDS;$WDS;$WDS;$WDS;$WES;$WES"
  timekpra --setallowedhours "$USER_NAME" 'ALL' "$H"
} >> "$LOG" 2>&1

/usr/local/bin/pingulinux-update-social-block.sh >> "$LOG" 2>&1
/usr/local/bin/pingulinux-apply-all-ages.py >> "$LOG" 2>&1
exit 0
