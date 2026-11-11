#!/bin/bash
#
# pingulinux-update-social-block.sh  (als root)
# Sperrt Social-Media-Seiten und normales YouTube pro Konto: Fuer jedes
# Kinderkonto unter 13 Jahren wird eine Markierungsdatei angelegt. Firefox
# (pingulinux.cfg) erkennt sie und setzt dann die feste Sperrliste
# /usr/share/pingulinux/block-social.pac. Eltern und aeltere Kinder sind
# nicht betroffen. Die frueheren Eintraege in /etc/hosts werden entfernt.

PROFDIR=/var/lib/pingulinux/profiles
MARKDIR=/var/lib/pingulinux/blocksocial

mkdir -p "$MARKDIR"
chmod 755 "$MARKDIR"

# Alte systemweite Sperre aus /etc/hosts entfernen
sed -i '/^# BEGIN pingulinux-social$/,/^# END pingulinux-social$/d' /etc/hosts
sed -i '/^# BEGIN pingulinux-youtube$/,/^# END pingulinux-youtube$/d' /etc/hosts

# Alle Markierungen neu setzen
rm -f "$MARKDIR"/* 2>/dev/null
for f in "$PROFDIR"/*; do
  [ -f "$f" ] || continue
  u=$(basename "$f")
  id "$u" >/dev/null 2>&1 || { rm -f "$f"; continue; }   # geloeschte Konten
  a=$(cat "$f")
  if [ "$a" -lt 13 ] 2>/dev/null; then
    : > "$MARKDIR/$u"
    chmod 644 "$MARKDIR/$u"
  fi
done
exit 0
