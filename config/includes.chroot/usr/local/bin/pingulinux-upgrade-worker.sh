#!/bin/bash
#
# pingulinux-upgrade-worker.sh  (laeuft als root, Aufruf: ALT NEU)
# Wechselt die Debian-Version: Paketquellen umstellen, aktualisieren.
# Bei Fehler vor dem Upgrade werden die alten Paketquellen zurueckgesetzt.

OLD="$1"; NEW="$2"; MODE="${3:-backup}"   # backup = erst Timeshift-Sicherung, nobackup = ohne
LOG=/var/log/pingulinux-upgrade.log
BAK=/var/backups/pingulinux-sources-$(date +%Y%m%d-%H%M%S)
export DEBIAN_FRONTEND=noninteractive
APT_OPTS=(-y -o Dpkg::Options::=--force-confold -o Dpkg::Options::=--force-confdef -o DPkg::Lock::Timeout=180)

[ -n "$OLD" ] && [ -n "$NEW" ] || { echo "Aufruf: $0 ALT NEU"; exit 2; }
exec >> "$LOG" 2>&1
echo "=== Upgrade $OLD -> $NEW: $(date) ==="

# Sicherung vor dem Wechsel (Code 20 = Sicherung fehlgeschlagen, es wurde noch nichts veraendert)
if [ "$MODE" = "backup" ]; then
    if ! { command -v timeshift >/dev/null 2>&1 && timeshift --create --comments "Vor Debian-Upgrade auf $NEW" --scripted; }; then
        echo "Sicherung fehlgeschlagen"
        exit 20
    fi
fi

mkdir -p "$BAK"
cp -a /etc/apt/sources.list "$BAK/" 2>/dev/null
cp -a /etc/apt/sources.list.d "$BAK/" 2>/dev/null

restore() {
    echo "Fehler - stelle alte Paketquellen wieder her"
    cp -a "$BAK/sources.list" /etc/apt/sources.list 2>/dev/null
    rm -f /etc/apt/sources.list.d/*.sources /etc/apt/sources.list.d/*.list 2>/dev/null
    cp -a "$BAK/sources.list.d/." /etc/apt/sources.list.d/ 2>/dev/null
}

# Nur Debian-Quellen anfassen (keine Flathub-/Fremdquellen)
FILES=$(grep -lE "deb(\.debian\.org|ian\.org)|security\.debian\.org" /etc/apt/sources.list /etc/apt/sources.list.d/* 2>/dev/null)
[ -n "$FILES" ] || { echo "Keine Debian-Paketquellen gefunden"; exit 3; }
for f in $FILES; do sed -i "s/\b$OLD\b/$NEW/g" "$f"; done

apt-get update || { restore; apt-get update; exit 4; }
apt-get "${APT_OPTS[@]}" upgrade --without-new-pkgs || exit 5
apt-get "${APT_OPTS[@]}" full-upgrade || exit 6
apt-get -y autoremove --purge
apt-get clean
command -v flatpak >/dev/null && flatpak update -y --system

sed -i "s/^VERSION_CODENAME=.*/VERSION_CODENAME=$NEW/; s/(\($OLD\)-based)/($NEW-based)/" /etc/os-release
echo "=== fertig: $(date) ==="
exit 0
