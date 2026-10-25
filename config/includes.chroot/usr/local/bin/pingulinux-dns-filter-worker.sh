#!/bin/bash
#
# pingulinux-dns-filter-worker.sh  (laeuft als root, via pkexec)
# Aufruf: cleanbrowsing | dns4eu | off    (on = cleanbrowsing)
# Stellt den Kinderschutz-DNS ein und merkt sich die Wahl in
# /etc/pingulinux/dns-provider (gilt auch nach dem Neustart).

RESOLV="/etc/resolv.conf"
NM_CONF="/etc/NetworkManager/conf.d/dns-none.conf"
CHOICE="/etc/pingulinux/dns-provider"

P="$1"; [ "$P" = "on" ] && P=cleanbrowsing
case "$P" in
off)
    chattr -i "$RESOLV" 2>/dev/null || true
    rm -f "$NM_CONF"
    mkdir -p /etc/pingulinux; echo off > "$CHOICE"
    systemctl restart NetworkManager 2>/dev/null || true
    ;;
cleanbrowsing|dns4eu)
    chattr -i "$RESOLV" 2>/dev/null || true
    mkdir -p /etc/NetworkManager/conf.d /etc/pingulinux
    printf '[main]\ndns=none\n' > "$NM_CONF"
    echo "$P" > "$CHOICE"
    rm -f "$RESOLV"
    if [ "$P" = dns4eu ]; then
        cat > "$RESOLV" <<'R'
# Pingulinux OS: DNS4EU Kinderschutz (EU-Dienst)
nameserver 86.54.11.12
nameserver 86.54.11.212
R
    else
        cat > "$RESOLV" <<'R'
# Pingulinux OS: CleanBrowsing Family Filter (Kinderschutz-DNS)
nameserver 185.228.168.168
nameserver 185.228.169.168
R
    fi
    chattr +i "$RESOLV" 2>/dev/null || true
    systemctl restart NetworkManager 2>/dev/null || true
    ;;
*)
    echo "Aufruf: $0 cleanbrowsing|dns4eu|off"; exit 2 ;;
esac
exit 0
