#!/bin/bash
#
# pingulinux-sicherheitsquelle.sh  (bz22) – läuft als root vor den Updates
#
# Stellt sicher, dass die Debian-Sicherheitsquelle eingetragen ist. Ohne sie
# gäbe es keine Sicherheitsupdates. Fehlt sie, wird sie als eigene Datei
# ergänzt; vorhandene Einträge werden nie verändert.

CODENAME=$(. /etc/os-release 2>/dev/null; echo "${VERSION_CODENAME:-}")
[ -n "$CODENAME" ] || CODENAME=$(sed -n 's/^VERSION_CODENAME=//p' /usr/lib/os-release 2>/dev/null)
[ -n "$CODENAME" ] || CODENAME=trixie
F=/etc/apt/sources.list.d/pingulinux-security.sources

if grep -rqsE "security\.debian\.org|${CODENAME}-security" /etc/apt/sources.list /etc/apt/sources.list.d/ \
   --exclude="$(basename "$F")"; then
    rm -f "$F"          # Debian-eigener Eintrag reicht, keinen doppelten anlegen
    exit 0
fi
cat > "$F" <<SRC
# Pingulinux: Debian-Sicherheitsupdates (automatisch ergänzt, weil kein
# Eintrag gefunden wurde)
Types: deb
URIs: http://security.debian.org/debian-security
Suites: ${CODENAME}-security
Components: main contrib non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SRC
echo "Sicherheitsquelle ergänzt: $F"
exit 0
