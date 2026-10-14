#!/bin/bash
#
# pingulinux-remove-installer-if-installed.sh
#
# Entfernt die Calamares-Installer-Verknüpfungen (Desktop-Icon,
# Menüeintrag), sobald erkannt wird, dass es sich um ein FEST
# INSTALLIERTES System handelt (nicht mehr Live-Modus) - dort
# braucht man den Installer ja nicht mehr.


# Live-Modus erkennen: boot=live steht dann in /proc/cmdline
if grep -q "boot=live" /proc/cmdline 2>/dev/null; then
    # Live-System - Installer soll bleiben, nichts tun
    exit 0
fi

# Ab hier: installiertes System - Installer-Verknüpfungen entfernen
sudo /bin/rm -f /usr/share/applications/pingulinux-installer.desktop
sudo /bin/rm -f /usr/share/pingulinux/install-pingulinux.desktop
sudo /bin/rm -f /usr/share/applications/calamares.desktop
sudo /bin/rm -f /usr/share/applications/org.calamares.calamares.desktop
rm -f "$HOME/Desktop/install-pingulinux.desktop" 2>/dev/null

mkdir -p "$HOME/.config"

