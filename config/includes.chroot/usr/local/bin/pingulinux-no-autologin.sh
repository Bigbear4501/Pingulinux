#!/bin/bash
#
# pingulinux-no-autologin.sh  (läuft als root beim Start, vor dem Anmeldebildschirm)
# Auf einem Kinder-PC soll sich niemand automatisch anmelden, sonst landet
# ein Kind nach dem Einschalten direkt im Elternkonto mit Admin-Rechten.
# Der Installer (Calamares) bietet aber einen Haken "Automatisch anmelden".
# Dieses Skript entfernt eine solche Einstellung bei jedem Start wieder.
# Im Live-Modus passiert nichts: Dort meldet sich der Live-Benutzer
# absichtlich automatisch an.
# Gilt für SDDM ([Autologin] User=) und, falls noch vorhanden, LightDM.

grep -q "boot=live" /proc/cmdline 2>/dev/null && exit 0

# SDDM
for f in ${PINGU_SDDM_FILES:-/etc/sddm.conf /etc/sddm.conf.d/*.conf}; do
    [ -f "$f" ] || continue
    if grep -qE '^[[:space:]]*User[[:space:]]*=[[:space:]]*[^[:space:]]' "$f" && grep -q '^\[Autologin\]' "$f"; then
        # nur User= im Abschnitt [Autologin] auskommentieren
        awk '
            /^\[/ { sec=$0 }
            sec=="[Autologin]" && $0 ~ /^[[:space:]]*User[[:space:]]*=/ { print "#" $0 " (von Pingulinux abgeschaltet)"; next }
            { print }
        ' "$f" > "$f.pingu-tmp" && cat "$f.pingu-tmp" > "$f" && rm -f "$f.pingu-tmp"
        echo "Automatische Anmeldung abgeschaltet in $f"
    fi
done

# LightDM (ältere Installationen)
for f in ${PINGU_LIGHTDM_FILES:-/etc/lightdm/lightdm.conf /etc/lightdm/lightdm.conf.d/*.conf}; do
    [ -f "$f" ] || continue
    if grep -qE '^[[:space:]]*autologin-user[[:space:]]*=' "$f"; then
        sed -i -E 's/^([[:space:]]*)autologin-user[[:space:]]*=.*/\1#autologin-user= (von Pingulinux abgeschaltet)/' "$f"
        echo "Automatische Anmeldung abgeschaltet in $f"
    fi
done
exit 0
