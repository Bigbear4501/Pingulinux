#!/bin/bash
#
# pingulinux-lock-dns.sh
#
# Läuft bei jedem Boot (systemd-Dienst): stellt sicher, dass
# /etc/resolv.conf die Kinderschutz-DNS-Server enthält, und macht
# die Datei anschließend unveränderlich, damit nichts (DHCP,
# NetworkManager, etc.) sie überschreiben kann.

RESOLV="/etc/resolv.conf"

chattr -i "$RESOLV" 2>/dev/null || true

cat > "$RESOLV" << 'EOF'
# Pingulinux OS: CleanBrowsing Family Filter (Kinderschutz-DNS)
nameserver 185.228.168.168
nameserver 185.228.169.168
EOF

chattr +i "$RESOLV" 2>/dev/null || true
