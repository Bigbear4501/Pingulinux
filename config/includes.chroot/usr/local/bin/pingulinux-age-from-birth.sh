#!/bin/bash
# pingulinux-age-from-birth.sh GEBURT  (Format JJJJ-MM)
# Gibt das Alter in Jahren aus. Vorsichtig gerechnet: Im Geburtsmonat selbst
# zaehlt das Kind noch als juenger, es wird erst im Folgemonat aelter.
B="$1"
[[ "$B" =~ ^([0-9]{4})-(0[1-9]|1[0-2])$ ]] || exit 2
by=${BASH_REMATCH[1]}; bm=$((10#${BASH_REMATCH[2]}))
y=$(date +%Y); m=$((10#$(date +%m)))
age=$((y - by))
[ "$m" -le "$bm" ] && age=$((age - 1))
[ "$age" -lt 0 ] && age=0
echo "$age"
