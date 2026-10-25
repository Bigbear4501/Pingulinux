#!/bin/bash
#
# pingulinux-toggle-dns-filter.sh
#
# Waehlt den Kinderschutz-DNS-Filter: CleanBrowsing, DNS4EU oder aus.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
RESOLV="/etc/resolv.conf"

if grep -q "185.228.168.168" "$RESOLV" 2>/dev/null; then CUR=cleanbrowsing
elif grep -q "86.54.11.12" "$RESOLV" 2>/dev/null; then CUR=dns4eu
else CUR=off; fi

mark() { [ "$CUR" = "$1" ] && echo TRUE || echo FALSE; }

SEL=$(zenity --list --radiolist --title="Kinderschutz-Filter" --width=560 --height=330 \
    --text="Welcher DNS-Filter soll Erwachsenen- und Gewaltinhalte blockieren?\nDie Auswahl gilt für den ganzen Computer." \
    --column="" --column="Wert" --column="Filter" --hide-column=2 --print-column=2 \
    "$(mark cleanbrowsing)" cleanbrowsing "CleanBrowsing Family (USA-Dienst, Standard)" \
    "$(mark dns4eu)" dns4eu "DNS4EU Kinderschutz (europäischer Dienst, EU-Datenschutz)" \
    "$(mark off)" off "Aus (keine Filterung)") || exit 0
[ -z "$SEL" ] && exit 0
[ "$SEL" = "$CUR" ] && exit 0

case "$SEL" in
  cleanbrowsing) NAME="CleanBrowsing Family" ;;
  dns4eu) NAME="DNS4EU Kinderschutz" ;;
  *) NAME="" ;;
esac

if ERR=$(pkexec /usr/local/bin/pingulinux-dns-filter-worker.sh "$SEL" 2>&1); then
    if [ "$SEL" = off ]; then
        zenity --info --title="Kinderschutz-Filter" --text="Der DNS-Kinderschutz-Filter wurde AUSGESCHALTET.\n\nDas Internet läuft jetzt ohne Inhaltsfilterung." --width=380
    else
        zenity --info --title="Kinderschutz-Filter" --text="Es ist jetzt EINGESCHALTET: $NAME\n\nErwachsenen- und Gewaltinhalte werden blockiert." --width=380
    fi
else
    zenity --error --title="Kinderschutz-Filter" --no-markup --text="⚠️ Der Filter konnte nicht umgestellt werden.

$ERR" --width=420
fi
