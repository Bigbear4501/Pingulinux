#!/bin/bash
#
# trust-desktop-icons.sh
#
# XFCE/Thunar zeigt bei .desktop-Dateien auf dem Desktop standardmäßig
# eine "Nicht vertrauenswürdiger Launcher"-Warnung, bis der Nutzer einmal
# manuell "Vertrauen & starten" klickt. Dieses Skript markiert alle
# eigenen Desktop-Icons beim Login automatisch als vertrauenswürdig,
# damit z.B. der Calamares-Installer ohne diese Zwischenwarnung startet.

DESKTOP_DIR="$HOME/Desktop"

# Desktop-Ordner notfalls anlegen (falls live-config ihn nicht erzeugt hat)
mkdir -p "$DESKTOP_DIR"

# Unser eigenes Icon aktiv wiederherstellen, falls es fehlt.
# live-config baut den Desktop-Ordner bei jedem Boot neu auf und kann
# dabei unser Icon überschreiben/entfernen - deshalb liegt eine
# unangetastete Sicherheitskopie an einem festen Systempfad.
OWN_ICON_SOURCE="/usr/share/pingulinux/install-pingulinux.desktop"
OWN_ICON_TARGET="$DESKTOP_DIR/install-pingulinux.desktop"

if [ -f "$OWN_ICON_SOURCE" ] && [ ! -f "$OWN_ICON_TARGET" ]; then
    cp "$OWN_ICON_SOURCE" "$OWN_ICON_TARGET"
fi

# Unerwünschte, automatisch nachgenerierte Icons löschen (z.B. von
# calamares-settings-debian, das trotz Entfernung im System manchmal
# beim Login erneut auf den Desktop kopiert wird)
UNWANTED_NAMES=(
    "calamares-install-debian.desktop"
    "debian-installer-launcher.desktop"
    "livewelcome.desktop"
)

for name in "${UNWANTED_NAMES[@]}"; do
    if [ -f "$DESKTOP_DIR/$name" ]; then
        rm -f "$DESKTOP_DIR/$name"
    fi
done

for f in "$DESKTOP_DIR"/*.desktop; do
    [ -f "$f" ] || continue
    chmod +x "$f"
    if command -v gio &> /dev/null && command -v sha256sum &> /dev/null; then
        checksum=$(sha256sum "$f" | awk '{print $1}')
        gio set -t string "$f" metadata::xfce-exe-checksum "$checksum" 2>/dev/null || true
        # Zusätzlich das ältere Attribut setzen (schadet nicht, falls
        # eine andere Xfce/Thunar-Version das stattdessen prüft)
        gio set "$f" metadata::trusted true 2>/dev/null || true
    fi
done
