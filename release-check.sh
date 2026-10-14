#!/bin/bash
# Pingulinux: prüft vor einem Release, ob alles eingetragen ist.
# Aufruf im Projektordner: ./release-check.sh
# Optional mit fertiger ISO: ./release-check.sh pingulinux-amd64.hybrid.iso

VERSION="Alpha 2"
FEHLER=0
ok()   { echo "  OK      $1"; }
fail() { echo "  FEHLT   $1"; FEHLER=1; }

echo "== Pingulinux Release-Check ($VERSION) =="

# 1. Version in os-release
OSR=$(grep -rl "PRETTY_NAME" config/includes.chroot*/etc/os-release config/includes.chroot*/usr/lib/os-release 2>/dev/null | head -1)
if [ -n "$OSR" ] && grep -q "$VERSION" "$OSR"; then
  ok "os-release enthält \"$VERSION\" ($OSR)"
else
  fail "os-release ohne \"$VERSION\" (Datei: ${OSR:-nicht gefunden})"
fi

# 2. links.conf vorhanden und gefüllt
LINKS=$(find config -path "*etc/pingulinux/links.conf" 2>/dev/null | head -1)
if [ -z "$LINKS" ]; then
  fail "links.conf nicht gefunden"
else
  for KEY in PRIVACY IMPRINT BUG; do
    if grep -iE "^[^#]*${KEY}[^=]*=\s*\"?https?://" "$LINKS" | grep -vq "example.org"; then
      ok "links.conf: $KEY gesetzt"
    else
      fail "links.conf: $KEY leer oder Platzhalter"
    fi
  done
fi

# 3. Keine example.org-Platzhalter mehr
TREFFER=$(grep -rIl "example\.org" config/ 2>/dev/null | grep -v "/chroot/")
if [ -z "$TREFFER" ]; then
  ok "keine example.org-Links in config/"
else
  fail "example.org noch in:"; echo "$TREFFER" | sed 's/^/            /'
fi

# 4. Projektdateien
for F in LICENSE README.md .gitignore rebuild.sh; do
  [ -f "$F" ] && ok "$F vorhanden" || fail "$F fehlt"
done

# 5. Optional: ISO prüfen und SHA256SUMS erzeugen
if [ -n "$1" ]; then
  if [ -f "$1" ]; then
    (cd "$(dirname "$1")" && sha256sum "$(basename "$1")") > SHA256SUMS
    ok "SHA256SUMS erzeugt:"; sed 's/^/            /' SHA256SUMS
    GROESSE=$(du -h "$1" | cut -f1)
    ok "ISO-Größe: $GROESSE"
  else
    fail "ISO $1 nicht gefunden"
  fi
fi

echo
[ $FEHLER -eq 0 ] && echo "Alles bereit für $VERSION." || echo "Bitte die FEHLT-Punkte erledigen."
exit $FEHLER
