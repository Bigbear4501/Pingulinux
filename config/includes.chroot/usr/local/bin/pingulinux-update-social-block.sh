#!/bin/bash
#
# pingulinux-update-social-block.sh  (als root)
# Sperrt Social-Media-Seiten systemweit, solange es mindestens ein
# Kinderkonto unter 13 Jahren gibt. Aenderungen stehen nur zwischen den
# Markierungen in /etc/hosts.

PROFDIR=/var/lib/pingulinux/profiles
BEGIN="# BEGIN pingulinux-social"
END="# END pingulinux-social"
DOMAINS="facebook.com instagram.com tiktok.com snapchat.com twitter.com x.com reddit.com discord.com threads.net"

young=0
for f in "$PROFDIR"/*; do
  [ -f "$f" ] || continue
  u=$(basename "$f")
  id "$u" >/dev/null 2>&1 || { rm -f "$f"; continue; }   # geloeschte Konten
  a=$(cat "$f"); [ "$a" -lt 13 ] 2>/dev/null && young=1
done

# YouTube (normales YouTube; YouTube Kids bleibt ueber youtubekids.com)
YT_BEGIN="# BEGIN pingulinux-youtube"
YT_END="# END pingulinux-youtube"
YT_DOMAINS="youtube.com www.youtube.com m.youtube.com music.youtube.com youtu.be www.youtu.be"

sed -i "/^$BEGIN\$/,/^$END\$/d" /etc/hosts
sed -i "/^$YT_BEGIN\$/,/^$YT_END\$/d" /etc/hosts
if [ "$young" = 1 ]; then
  {
    echo "$BEGIN"
    for d in $DOMAINS; do echo "0.0.0.0 $d"; echo "0.0.0.0 www.$d"; done
    echo "$END"
    echo "$YT_BEGIN"
    for d in $YT_DOMAINS; do echo "0.0.0.0 $d"; done
    echo "$YT_END"
  } >> /etc/hosts
fi
exit 0
