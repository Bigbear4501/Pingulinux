#!/bin/bash
set -e
cd ~/kids-distro
lb config --distribution trixie \
  --archive-areas "main contrib non-free-firmware" \
  --debian-installer none \
  --firmware-chroot false \
  --bootappend-live "boot=live components quiet splash locales=de_DE.UTF-8 keyboard-layouts=de tz=Europe/Berlin plymouth.debug live-config.username=pingu live-config.user-fullname=Pingu-Live-User noeject"
sudo lb build 2>&1 | tee build.log
