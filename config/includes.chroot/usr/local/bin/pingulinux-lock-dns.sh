#!/bin/bash
#
# pingulinux-lock-dns.sh
#
# Laeuft bei jedem Boot (systemd-Dienst): setzt den Kinderschutz-DNS, den
# die Eltern gewaehlt haben (/etc/pingulinux/dns-provider: cleanbrowsing,
# dns4eu oder off), und macht /etc/resolv.conf unveraenderlich, damit
# nichts (DHCP, NetworkManager, ...) sie ueberschreibt.

CHOICE=$(cat /etc/pingulinux/dns-provider 2>/dev/null)
case "$CHOICE" in
  off) exit 0 ;;
  dns4eu) exec /usr/local/bin/pingulinux-dns-filter-worker.sh dns4eu ;;
  *) exec /usr/local/bin/pingulinux-dns-filter-worker.sh cleanbrowsing ;;
esac
