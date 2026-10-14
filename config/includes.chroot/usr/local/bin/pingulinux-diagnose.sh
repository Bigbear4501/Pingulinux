#!/bin/bash
#
# pingulinux-diagnose.sh - Hilfe und Fehlerdiagnose
# Prueft das System, zeigt eine verstaendliche Zusammenfassung und
# speichert einen Bericht (ohne Passwoerter) zum Weitergeben.

zenity() { command zenity --window-icon=/usr/share/pingulinux/icons/pingu.png "$@"; }
REPORT="$HOME/Pingulinux-Diagnose.txt"
SUMMARY=$(mktemp)
ok()   { echo "✅ $1" >> "$SUMMARY"; }
warn() { echo "⚠️ $1" >> "$SUMMARY"; }

# --- Kurzpruefungen ---
if ping -c1 -W3 1.1.1.1 >/dev/null 2>&1; then ok "Internetverbindung ist da"; else warn "Keine Internetverbindung (WLAN/LAN prüfen)"; fi
if getent hosts debian.org >/dev/null 2>&1; then ok "Namensauflösung (DNS) funktioniert"; else warn "Webadressen lassen sich nicht auflösen (DNS)"; fi
if grep -q "185.228.168.168" /etc/resolv.conf 2>/dev/null; then ok "Kinderschutz-Filter ist EIN"; else warn "Kinderschutz-Filter ist AUS"; fi

USED=$(df --output=pcent / | tail -1 | tr -dc '0-9')
if [ "${USED:-0}" -ge 90 ]; then warn "Festplatte fast voll (${USED}%) – Systembereinigung starten"; else ok "Festplatte hat genug Platz (${USED}% belegt)"; fi

MEMFREE=$(awk '/MemAvailable/ {printf "%d", $2/1024}' /proc/meminfo)
if [ "${MEMFREE:-0}" -lt 300 ]; then warn "Wenig freier Arbeitsspeicher (${MEMFREE} MB)"; else ok "Arbeitsspeicher ok (${MEMFREE} MB frei)"; fi

FAILED=$(systemctl --failed --no-legend 2>/dev/null | wc -l)
if [ "$FAILED" -gt 0 ]; then warn "$FAILED Systemdienst(e) fehlgeschlagen"; else ok "Alle Systemdienste laufen"; fi

if command -v upower >/dev/null && upower -e 2>/dev/null | grep -q battery; then
    PCT=$(upower -i "$(upower -e | grep battery | head -1)" | awk '/percentage/ {print $2}')
    ok "Akku: $PCT"
fi
if lsusb 2>/dev/null | grep -qi "printer"; then ok "Drucker per USB erkannt"; fi
if ls /sys/class/leds/*kbd_backlight* >/dev/null 2>&1; then ok "Tastaturbeleuchtung vorhanden"; fi
if [ -n "$(xinput list 2>/dev/null | grep -i touch)" ]; then ok "Touchscreen erkannt"; else echo "ℹ️ Kein Touchscreen erkannt" >> "$SUMMARY"; fi

# --- ausfuehrlicher Bericht ---
{
  echo "=== Pingulinux Diagnose $(date) ==="
  echo; echo "--- System ---"; cat /etc/os-release | head -4; uname -r
  echo; echo "--- Hardware ---"
  (cat /sys/class/dmi/id/sys_vendor /sys/class/dmi/id/product_name) 2>/dev/null
  lscpu | grep -i "model name"; free -h | head -2
  echo; echo "--- PCI/USB ---"; lspci 2>/dev/null | head -30; lsusb 2>/dev/null
  echo; echo "--- Netzwerk ---"; nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null; cat /etc/resolv.conf
  echo; echo "--- Platz ---"; df -h / /home 2>/dev/null
  echo; echo "--- Fehlgeschlagene Dienste ---"; systemctl --failed --no-legend 2>/dev/null
  echo; echo "--- Letzte Fehler (diese Sitzung) ---"; journalctl -p err -b --no-pager -n 40 2>/dev/null
  echo; echo "--- Firmware-Meldungen ---"; dmesg 2>/dev/null | grep -i "firmware" | tail -15
} > "$REPORT" 2>&1

zenity --text-info --title="Hilfe und Fehlerdiagnose" --width=560 --height=440 \
    --ok-label="Schließen" --cancel-label="Bericht öffnen" \
    --filename="$SUMMARY" \
    --font="Sans 12"
[ $? -eq 1 ] && xdg-open "$REPORT" >/dev/null 2>&1 &
zenity --info --title="Hilfe und Fehlerdiagnose" --width=460 \
    --text="📄 Ein ausführlicher Bericht liegt in deinem Ordner:\n<b>Pingulinux-Diagnose.txt</b>\n\nDen kannst du an die Pingulinux-Community schicken, wenn etwas nicht klappt. Er enthält keine Passwörter." 
rm -f "$SUMMARY"
