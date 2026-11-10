#!/bin/bash
#
# pingulinux-toggle-dns-filter.sh
#
# Waehlt den Kinderschutz-DNS-Filter: CleanBrowsing, DNS4EU oder aus.

. /usr/local/lib/pingulinux/dialog.sh
RESOLV="/etc/resolv.conf"

if grep -q "185.228.168.168" "$RESOLV" 2>/dev/null; then CUR=cleanbrowsing
elif grep -q "86.54.11.12" "$RESOLV" 2>/dev/null; then CUR=dns4eu
else CUR=off; fi

mark() { [ "$CUR" = "$1" ] && echo an || echo aus; }

SEL=$(pd_radio "Kinderschutz-Filter" \
    "Welcher DNS-Filter soll Erwachsenen- und Gewaltinhalte blockieren?\nDie Auswahl gilt für den ganzen Computer." \
    cleanbrowsing "CleanBrowsing Family (USA-Dienst, Standard)" "$(mark cleanbrowsing)" \
    dns4eu "DNS4EU Kinderschutz (europäischer Dienst, EU-Datenschutz)" "$(mark dns4eu)" \
    off "Aus (keine Filterung)" "$(mark off)") || exit 0
[ -z "$SEL" ] && exit 0
[ "$SEL" = "$CUR" ] && exit 0

case "$SEL" in
  cleanbrowsing) NAME="CleanBrowsing Family" ;;
  dns4eu) NAME="DNS4EU Kinderschutz" ;;
  *) NAME="" ;;
esac

if ERR=$(pkexec /usr/local/bin/pingulinux-dns-filter-worker.sh "$SEL" 2>&1); then
    if [ "$SEL" = off ]; then
        pd_info "Kinderschutz-Filter" "Der DNS-Kinderschutz-Filter wurde AUSGESCHALTET.\n\nDas Internet läuft jetzt ohne Inhaltsfilterung."
    else
        pd_info "Kinderschutz-Filter" "Es ist jetzt EINGESCHALTET: $NAME\n\nErwachsenen- und Gewaltinhalte werden blockiert."
    fi
else
    pd_fehler_roh "Kinderschutz-Filter" "⚠️ Der Filter konnte nicht umgestellt werden.

$ERR"
fi
