#!/bin/bash
set -e
cd ~/kids-distro
lb config --distribution trixie \
  --archive-areas "main contrib non-free-firmware" \
  --debian-installer none \
  --bootappend-live "boot=live components quiet splash locales=de_DE.UTF-8 keyboard-layouts=de tz=Europe/Berlin"
sudo lb build 2>&1 | tee build.log
