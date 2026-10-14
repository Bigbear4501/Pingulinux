#!/bin/bash
#
# pingulinux-toggle-dns-filter.sh
#
# Schaltet den CleanBrowsing-Kinderschutz-DNS-Filter ein oder aus.

# Pingulinux-Logo in allen Dialogfenstern
zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
RESOLV="/etc/resolv.conf"
NM_CONF="/etc/NetworkManager/conf.d/dns-none.conf"

if grep -q "185.228.168.168" "$RESOLV" 2>/dev/null; then
    # Aktuell AN -> ausschalten
    if ERR=$(pkexec /usr/local/bin/pingulinux-dns-filter-worker.sh off 2>&1); then
        zenity --info --title="Kinderschutz-Filter" --text="Der DNS-Kinderschutz-Filter wurde AUSGESCHALTET.\n\nDas Internet läuft jetzt ohne Inhaltsfilterung." --width=350
    else
        zenity --error --title="Kinderschutz-Filter" --no-markup --text="⚠️ Der Filter konnte nicht ausgeschaltet werden.

$ERR" --width=400
    fi
else
    # Aktuell AUS -> einschalten
    if ERR=$(pkexec /usr/local/bin/pingulinux-dns-filter-worker.sh on 2>&1); then
        zenity --info --title="Kinderschutz-Filter" --text="Der DNS-Kinderschutz-Filter wurde EINGESCHALTET.\n\nErwachsenen-/Gewaltinhalte werden jetzt blockiert." --width=350
    else
        zenity --error --title="Kinderschutz-Filter" --no-markup --text="⚠️ Der Filter konnte nicht eingeschaltet werden.

$ERR" --width=400
    fi
fi
