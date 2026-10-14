#!/bin/bash
#
# pingulinux-update-worker.sh  (laeuft als root, via pkexec)
# Installiert alle Updates der aktuellen Debian-Version (apt + Flatpak).

LOG=/var/log/pingulinux-update.log
export DEBIAN_FRONTEND=noninteractive
exec >> "$LOG" 2>&1
echo "=== Updates: $(date) ==="

APT=(-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -o DPkg::Lock::Timeout=180)

apt-get "${APT[@]}" update || { echo "FEHLER: apt-get update"; exit 4; }
apt-get "${APT[@]}" upgrade || { echo "FEHLER: apt-get upgrade"; exit 5; }
if command -v flatpak >/dev/null 2>&1; then
    flatpak update -y --system || echo "Hinweis: Flatpak-Update nicht vollstaendig"
fi
echo "=== fertig: $(date) ==="
exit 0
