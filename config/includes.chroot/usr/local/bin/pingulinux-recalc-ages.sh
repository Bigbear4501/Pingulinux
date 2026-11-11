#!/bin/bash
# pingulinux-recalc-ages.sh  (als root)
# Das Alter waechst mit: rechnet aus Geburtsmonat und -jahr
# (/var/lib/pingulinux/birth/KONTO) das aktuelle Alter. Hat sich das Alter
# geaendert, wird das Altersprofil neu gesetzt (Bildschirmzeit, Programm-
# und Social-Media-Sperren). Unveraenderte Konten bleiben unberuehrt,
# damit Anpassungen der Eltern nicht ueberschrieben werden.
BIRTHDIR=/var/lib/pingulinux/birth
PROFDIR=/var/lib/pingulinux/profiles
LOG=/var/log/pingulinux-profile.log
[ -d "$BIRTHDIR" ] || exit 0
for f in "$BIRTHDIR"/*; do
  [ -f "$f" ] || continue
  u=$(basename "$f")
  id "$u" >/dev/null 2>&1 || { rm -f "$f"; continue; }
  new=$(/usr/local/bin/pingulinux-age-from-birth.sh "$(cat "$f")") || continue
  old=$(cat "$PROFDIR/$u" 2>/dev/null)
  if [ "$new" != "$old" ]; then
    echo "$(date): $u wird $new Jahre alt (vorher: ${old:-?})" >> "$LOG"
    /usr/local/bin/pingulinux-apply-age-profile.sh "$u" "$new"
  fi
done
exit 0
