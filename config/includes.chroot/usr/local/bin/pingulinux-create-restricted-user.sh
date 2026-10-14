#!/bin/bash
#
# pingulinux-create-restricted-user.sh
#
# Läuft mit erhöhten Rechten (über pkexec aufgerufen). Legt einen
# NICHT-Admin-Benutzer an (keine sudo-Gruppe) und sperrt zusätzlich
# den Zugriff auf den Terminal-Emulator für genau dieses Konto
# (über eine Zugriffsrechte-Regel/ACL, andere Konten bleiben
# unberührt).
#
# Aufruf: USERNAME als $1, Passwort wird über stdin eingelesen.

set -e

USERNAME="$1"
AGE="$2"
AVATAR="$3"
PASSWORD=$(cat)

useradd -m -s /bin/bash "$USERNAME"
echo "${USERNAME}:${PASSWORD}" | chpasswd

# Kinder-Konten sollen das Eltern-Kontrollzentrum nicht automatisch
# oeffnen (nur Admin-/Eltern-Konten bekommen den Autostart).
rm -f "/home/${USERNAME}/.config/autostart/pingulinux-parental-control.desktop" \
      "/home/${USERNAME}/Desktop/pingulinux-parental-control.desktop"

# Terminal-Zugriff für genau dieses Konto sperren (kein Admin-Konto
# betroffen, nur dieses neue). Erfordert das Paket "acl".
if command -v setfacl &> /dev/null; then
    setfacl -m u:"${USERNAME}":--- /usr/bin/xfce4-terminal 2>/dev/null || true
fi

# YouTube Kids als Symbol auf dem Desktop des Kindes
mkdir -p "/home/${USERNAME}/Desktop"
cp /usr/share/applications/pingulinux-youtube-kids.desktop "/home/${USERNAME}/Desktop/" 2>/dev/null || true
chmod +x "/home/${USERNAME}/Desktop/pingulinux-youtube-kids.desktop" 2>/dev/null || true
chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/Desktop" 2>/dev/null || true

# Alters-Profil (Bildschirmzeit, Social-Media-Sperre) automatisch setzen
if [ -n "$AGE" ]; then
    /usr/local/bin/pingulinux-apply-age-profile.sh "$USERNAME" "$AGE" || true
fi

# Profilbild (leer = Pingu-Standardbild bleibt)
if [ -n "$AVATAR" ] && [ -f "$AVATAR" ]; then
    /usr/local/bin/pingulinux-set-avatar.sh "$USERNAME" "$AVATAR" || true
fi
