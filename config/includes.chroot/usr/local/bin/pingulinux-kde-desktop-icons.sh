#!/bin/bash
#
# pingulinux-kde-desktop-icons.sh  (Autostart bei jeder Anmeldung)
#
# 1. KDE: legt „Eigener Ordner“ und „Papierkorb“ auf den Schreibtisch.
#    XFCE zeigt diese beiden Symbole schon von selbst. Weil sich XFCE und KDE
#    denselben Schreibtisch-Ordner teilen, werden die beiden Dateien in XFCE
#    wieder entfernt, sonst wären sie dort doppelt.
# 2. Eltern-Konten (Gruppe sudo): Symbol „Eltern-Kontrollzentrum“ auf dem
#    Schreibtisch, in KDE und XFCE. Kinderkonten bekommen es nicht
#    (und falls es dort doch liegt, wird es entfernt).

DIR=$(xdg-user-dir DESKTOP 2>/dev/null)
[ -n "$DIR" ] && [ "$DIR" != "$HOME" ] || DIR="$HOME/Desktop"
HOMEF="$DIR/pingulinux-eigener-ordner.desktop"
TRASHF="$DIR/pingulinux-papierkorb.desktop"

case ":${XDG_CURRENT_DESKTOP:-}:" in
    *:KDE:*)
        mkdir -p "$DIR"
        cat > "$HOMEF" <<EOT
[Desktop Entry]
Type=Link
Name=Eigener Ordner
Icon=user-home
URL=file://$HOME
EOT
        cat > "$TRASHF" <<'EOT'
[Desktop Entry]
Type=Link
Name=Papierkorb
Icon=user-trash-full
EmptyIcon=user-trash
URL=trash:/
EOT
        ;;
    *:XFCE:*)
        rm -f "$HOMEF" "$TRASHF"
        ;;
esac

# Programm-Symbole, die als Kopie einer Systemdatei auf dem Schreibtisch
# liegen (z. B. YouTube Kids beim Kind), durch eine Verknüpfung ersetzen.
# Grund: Der Kinder-Ordner ist noexec, eine Kopie lässt sich dort nicht als
# „ausführbar“ markieren, KDE verweigert dann den Start. Eine Verknüpfung zu
# /usr/share/applications gilt in KDE von selbst als vertrauenswürdig.
for f in "$DIR"/*.desktop; do
    [ -f "$f" ] && [ ! -L "$f" ] || continue
    src="/usr/share/applications/$(basename "$f")"
    [ -f "$src" ] && grep -q '^Type=Application' "$src" || continue
    ln -sfn "$src" "$f"
done

# „Eltern-Passwort zurücksetzen“ gibt es nur im Live-Modus (vom Stick)
if ! grep -qw 'boot=live' /proc/cmdline 2>/dev/null; then
    rm -f "$DIR/pingulinux-passwort-zuruecksetzen.desktop" "$HOME/Desktop/pingulinux-passwort-zuruecksetzen.desktop"
fi

# Eltern-Kontrollzentrum auf dem Schreibtisch der Eltern
CC_SRC=/usr/share/applications/pingulinux-parental-control.desktop
CC_DST="$DIR/pingulinux-kontrollzentrum.desktop"
if [ -f "$CC_SRC" ] && id -nG | tr ' ' '\n' | grep -qx sudo; then
    mkdir -p "$DIR"
    [ "$(readlink "$CC_DST")" = "$CC_SRC" ] || ln -sfn "$CC_SRC" "$CC_DST"
else
    rm -f "$CC_DST"
fi
exit 0
