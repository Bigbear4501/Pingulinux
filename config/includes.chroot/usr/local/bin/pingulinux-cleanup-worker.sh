#!/bin/bash
#
# pingulinux-cleanup-worker.sh  (laeuft als root, via pkexec)
# Raeumt ungenutzte Pakete, Zwischenspeicher, alte Protokolle und
# doppelte Programme (Debian-Paket UND Flatpak) auf.

export DEBIAN_FRONTEND=noninteractive
apt-get -y -o DPkg::Lock::Timeout=180 autoremove --purge || exit 4
apt-get -y clean
command -v flatpak >/dev/null && flatpak uninstall --unused -y --system
journalctl --vacuum-time=7d
python3 - <<'P'
import json, subprocess
try:
    apps = json.load(open("/usr/share/pingulinux/store-apps.json", encoding="utf-8"))
except Exception:
    apps = []
for a in apps:
    apt, fp = a.get("apt"), a.get("flatpak")
    if not (apt and fp):
        continue
    deb = subprocess.run(["dpkg-query", "-W", "-f=${Status}", apt], capture_output=True, text=True)
    if "install ok installed" in deb.stdout and subprocess.run(["flatpak", "info", "--system", fp], capture_output=True).returncode == 0:
        print("Doppelt: Flatpak %s wird entfernt (Debian-Paket %s bleibt)" % (fp, apt))
        subprocess.run(["flatpak", "uninstall", "-y", "--system", fp])
P
exit 0
