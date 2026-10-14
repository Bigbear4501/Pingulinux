#!/bin/bash
#
# pingulinux-wifi-genmon.sh
#
# Zeigt den WLAN-Status im Panel an - aber NUR, wenn kein LAN-Kabel
# aktiv verbunden ist. Ist LAN verfügbar, blendet sich die Anzeige
# aus (leer). Sobald LAN wegfällt, erscheint sie wieder automatisch
# beim nächsten Aktualisierungs-Zyklus.

# WLAN-Funk sicherstellen, falls aus versehentlich deaktiviert
STATE=$(nmcli -t -f WIFI radio 2>/dev/null)
if [ "$STATE" != "enabled" ]; then
    nmcli radio wifi on &> /dev/null
fi

# Prüfen, ob eine LAN(Ethernet)-Verbindung aktiv verbunden ist
LAN_ACTIVE=$(nmcli -t -f TYPE,STATE device 2>/dev/null | grep -c "^ethernet:connected")

if [ "$LAN_ACTIVE" -gt 0 ]; then
    # LAN aktiv - WLAN-Anzeige bewusst (fast) leer lassen.
    # Ein echtes leeres <txt></txt> lässt genmon manchmal auf einen
    # Platzhalter "(genmon)XXX" zurückfallen - ein Leerzeichen umgeht das.
    echo "<txt> </txt>"
    echo "<tool>LAN aktiv - WLAN-Anzeige ausgeblendet</tool>"
    exit 0
fi

CONN=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | grep '^yes:' | cut -d: -f2)

if [ -n "$CONN" ]; then
    TXT="📶 ${CONN}"
    TOOLTIP="WLAN verbunden: ${CONN}"
else
    TXT="📶 Nicht verbunden"
    TOOLTIP="WLAN nicht verbunden - Klicken zum Einrichten"
fi

echo "<txt>${TXT}</txt>"
echo "<tool>${TOOLTIP}</tool>"
echo "<click>nm-connection-editor</click>"
