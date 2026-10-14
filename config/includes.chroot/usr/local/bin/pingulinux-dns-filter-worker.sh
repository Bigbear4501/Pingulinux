#!/bin/bash
#
# pingulinux-dns-filter-worker.sh  (laeuft als root, via pkexec)
# Aufruf: on | off   - schaltet den CleanBrowsing-Kinderschutz-DNS ein/aus.

RESOLV="/etc/resolv.conf"
NM_CONF="/etc/NetworkManager/conf.d/dns-none.conf"

case "$1" in
off)
    chattr -i "$RESOLV" 2>/dev/null || true
    rm -f "$NM_CONF"
    systemctl restart NetworkManager 2>/dev/null || true
    ;;
on)
    chattr -i "$RESOLV" 2>/dev/null || true
    mkdir -p /etc/NetworkManager/conf.d
    printf '[main]\ndns=none\n' > "$NM_CONF"
    rm -f "$RESOLV"
    cat > "$RESOLV" <<'R'
# Pingulinux OS: CleanBrowsing Family Filter (Kinderschutz-DNS)
nameserver 185.228.168.168
nameserver 185.228.169.168
R
    chattr +i "$RESOLV" 2>/dev/null || true
    systemctl restart NetworkManager 2>/dev/null || true
    ;;
*)
    echo "Aufruf: $0 on|off"; exit 2 ;;
esac
exit 0
