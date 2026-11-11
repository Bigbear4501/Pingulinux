#!/bin/bash
#
# pingulinux-plasma-first-run.sh
# Richtet beim ersten Start der KDE-Plasma-Sitzung eines Kontos die
# Pingulinux-Optik ein: Hintergrund, helles Farbschema, grosse Taskleiste
# mit den wichtigsten Kinder-Programmen. Laeuft pro Konto nur einmal.

MARK="$HOME/.config/pingulinux-plasma-setup-done"
[ -f "$MARK" ] && exit 0

# Warten, bis die Plasma-Oberflaeche bereit ist
for i in $(seq 1 30); do
    dbus-send --session --print-reply --dest=org.kde.plasmashell /PlasmaShell org.freedesktop.DBus.Introspectable.Introspect >/dev/null 2>&1 && break
    sleep 1
done
sleep 3

WALL=/usr/share/backgrounds/pingulinux/wallpaper.png
command -v plasma-apply-wallpaperimage >/dev/null && plasma-apply-wallpaperimage "$WALL" >/dev/null 2>&1
command -v plasma-apply-colorscheme >/dev/null && plasma-apply-colorscheme BreezeLight >/dev/null 2>&1

JS='
var ps = panels();
for (var i = 0; i < ps.length; i++) {
  var p = ps[i];
  p.height = 56;
  var ws = p.widgets();
  for (var j = 0; j < ws.length; j++) {
    var w = ws[j];
    if (w.type == "org.kde.plasma.icontasks" || w.type == "org.kde.plasma.taskmanager") {
      w.currentConfigGroup = ["General"];
      w.writeConfig("launchers", [
        "applications:firefox-esr.desktop",
        "applications:org.kde.dolphin.desktop",
        "applications:tuxpaint.desktop",
        "applications:org.kde.gcompris.desktop",
        "applications:gcompris-qt.desktop",
        "applications:org.kde.krita.desktop",
        "applications:pingulinux-youtube-kids.desktop"
      ]);
      w.reloadConfig();
    }
  }
}
'
dbus-send --session --dest=org.kde.plasmashell --type=method_call /PlasmaShell org.kde.PlasmaShell.evaluateScript "string:$JS" >/dev/null 2>&1

touch "$MARK"
exit 0
