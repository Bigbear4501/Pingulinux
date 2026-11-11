#!/usr/bin/env python3
"""Pingulinux App Store - zeigt nur kuratierte Programme (Whitelist).

Oberfläche mit Qt6 (sieht aus wie KDE). Die Logik ist dieselbe wie
in der GTK-Fassung:
Installation bevorzugt als Debian-Paket (apt); nur wenn es kein
Debian-Paket gibt, wird die Flatpak-Version von Flathub genutzt.
Installieren und Entfernen braucht das Passwort eines Administrators (pkexec).

Ersatz: Fehlt PyQt6, startet die alte GTK-Fassung (pingulinux-store-gtk.py).
"""
import json
import os
import shlex
import subprocess
import sys
import threading

try:
    from PyQt6.QtCore import Qt, QObject, pyqtSignal, QSize
    from PyQt6.QtGui import QIcon, QFont
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QHBoxLayout, QVBoxLayout,
                                 QListWidget, QListWidgetItem, QLabel, QPushButton, QLineEdit,
                                 QMessageBox, QFrame, QSizePolicy)
except ImportError:
    gtk = "/usr/local/bin/pingulinux-store-gtk.py"
    if os.path.exists(gtk):
        os.execv(sys.executable, [sys.executable, gtk] + sys.argv[1:])
    sys.stderr.write("PyQt6 fehlt (python3-pyqt6)\n")
    sys.exit(1)

CATALOG = "/usr/share/pingulinux/store-apps.json"
LOGO = "/usr/share/pingulinux/icons/pingu.png"
LOG = "/tmp/pingulinux-store.log"


def is_live():
    """Im Live-Modus lassen sich Flatpaks nicht installieren (zu wenig Platz im RAM)."""
    try:
        return "boot=live" in open("/proc/cmdline").read()
    except OSError:
        return False


LIVE = is_live()


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:              # Programm fehlt (z. B. flatpak)
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def apt_installed(pkg):
    r = run(["dpkg-query", "-W", "-f=${Status}", pkg])
    return r.returncode == 0 and "install ok installed" in r.stdout


def flatpak_installed(ref):
    return run(["flatpak", "info", "--system", ref]).returncode == 0


def apt_removal_set(pkg):
    """Simuliert 'apt-get remove' (ohne root) und liefert die Pakete,
    die dabei mit entfernt würden. pkg darf mehrere Namen (Leerzeichen) enthalten."""
    r = run(["apt-get", "-s", "remove"] + pkg.split())
    if r.returncode != 0:
        return None
    return [line.split()[1] for line in r.stdout.splitlines() if line.startswith("Remv ")]


def pick_source(app):
    """Debian-Paket hat immer Vorrang. Flatpak nur, wenn es für das
    Programm gar kein Debian-Paket gibt (Eintrag ohne "apt")."""
    if app.get("apt"):
        return "apt"
    if app.get("flatpak"):
        return "flatpak"
    return None


def apt_pkgs(app):
    """„apt“ darf mehrere Pakete enthalten, z. B. "thunderbird thunderbird-l10n-de"
    (Programm plus deutsche Übersetzung). Das erste ist das Programm."""
    return app["apt"].split()


def is_installed(app):
    if app["_src"] == "apt":
        return apt_installed(apt_pkgs(app)[0])
    if app["_src"] == "flatpak":
        return flatpak_installed(app["flatpak"])
    return False


FALLBACK_ICONS = {"Internet": "applications-internet", "Spiele": "applications-games",
                  "Grafik": "applications-graphics", "Multimedia": "applications-multimedia",
                  "Büro": "applications-office", "Bildung": "applications-education",
                  "Programmieren": "applications-development",
                  "Dienstprogramme": "applications-utilities"}


def pick_icon(app):
    """Programm-Symbol, sonst ein passendes Kategorie-Symbol (statt Fehler-Bild)."""
    names = [app.get("icon") or "", (app.get("icon") or "").split(".")[-1].lower(),
             FALLBACK_ICONS.get(app.get("category"), "applications-other"),
             "applications-science", "application-x-executable"]
    for n in names:
        if n and QIcon.hasThemeIcon(n):
            return QIcon.fromTheme(n)
    return QIcon.fromTheme("application-x-executable")


class Worker(QObject):
    """Meldet das Ende von Installieren/Entfernen aus dem Hintergrund-Thread."""
    finished = pyqtSignal(object, int, str)


class Store(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Pingulinux App Store")
        self.resize(900, 620)
        if os.path.exists(LOGO):
            self.setWindowIcon(QIcon(LOGO))

        with open(CATALOG, encoding="utf-8") as f:
            apps = json.load(f)
        seen, self.apps = set(), []
        for a in apps:
            a["_src"] = pick_source(a)
            keys = {a["name"].lower()}
            if a.get("apt"):
                keys.add("apt:" + a["apt"].split()[0])
            if a.get("flatpak"):
                keys.add("fp:" + a["flatpak"])
            if a["_src"] and not (keys & seen):
                seen |= keys
                self.apps.append(a)
        self.cats = ["Alle"] + sorted({a["category"] for a in self.apps})
        self.busy = False
        self.worker = Worker()
        self.worker.finished.connect(self.done)

        central = QWidget()
        self.setCentralWidget(central)
        outer = QVBoxLayout(central)
        outer.setContentsMargins(0, 0, 0, 0)
        outer.setSpacing(0)

        # Kopf: Titel, Untertitel, Suche
        head = QWidget()
        hl = QHBoxLayout(head)
        hl.setContentsMargins(16, 12, 16, 12)
        titles = QVBoxLayout()
        t = QLabel("Pingulinux App Store")
        f = t.font(); f.setPointSizeF(f.pointSizeF() * 1.4); f.setBold(True); t.setFont(f)
        titles.addWidget(t)
        titles.addWidget(QLabel("Ausgesuchte Programme für dich"))
        hl.addLayout(titles)
        hl.addStretch(1)
        self.search = QLineEdit()
        self.search.setPlaceholderText("Suchen…")
        self.search.setClearButtonEnabled(True)
        self.search.setMinimumWidth(240)
        self.search.textChanged.connect(self.refresh)
        hl.addWidget(self.search)
        outer.addWidget(head)
        line = QFrame(); line.setFrameShape(QFrame.Shape.HLine); line.setFrameShadow(QFrame.Shadow.Sunken)
        outer.addWidget(line)

        body = QHBoxLayout()
        body.setContentsMargins(0, 0, 0, 0)
        self.catlist = QListWidget()
        self.catlist.setFixedWidth(190)
        self.catlist.setStyleSheet("QListWidget::item { padding-left: 12px; }")
        for c in self.cats:
            it = QListWidgetItem(c)
            it.setSizeHint(QSize(180, 40))
            self.catlist.addItem(it)
        self.catlist.currentRowChanged.connect(self.refresh)
        body.addWidget(self.catlist)

        self.applist = QListWidget()
        self.applist.setSelectionMode(QListWidget.SelectionMode.NoSelection)
        self.applist.setVerticalScrollMode(QListWidget.ScrollMode.ScrollPerPixel)
        body.addWidget(self.applist, 1)
        outer.addLayout(body, 1)

        self.status = QLabel("")
        self.status.setContentsMargins(14, 6, 14, 8)
        outer.addWidget(self.status)

        self.catlist.setCurrentRow(0)

    # ---------- Liste ----------
    def refresh(self, *_):
        self.applist.clear()
        row = self.catlist.currentRow()
        cat = self.cats[row] if row >= 0 else "Alle"
        q = self.search.text().strip().lower()
        for app in self.apps:
            if cat != "Alle" and app["category"] != cat:
                continue
            if q and q not in (app["name"] + " " + app["summary"]).lower():
                continue
            w = self.make_row(app)
            it = QListWidgetItem()
            it.setSizeHint(w.sizeHint())
            self.applist.addItem(it)
            self.applist.setItemWidget(it, w)

    def make_row(self, app):
        w = QWidget()
        h = QHBoxLayout(w)
        h.setContentsMargins(14, 10, 14, 10)
        h.setSpacing(14)
        icon = QLabel()
        icon.setPixmap(pick_icon(app).pixmap(48, 48))
        icon.setFixedSize(52, 52)
        h.addWidget(icon)

        v = QVBoxLayout()
        v.setSpacing(2)
        name = QLabel(app["name"])
        f = name.font(); f.setBold(True); name.setFont(f)
        quelle = "Debian-Paket" if app["_src"] == "apt" else "Flatpak"
        if app.get("min_age", 0) >= 99:
            quelle += "  ·  nur für Erwachsene"
        elif app.get("min_age"):
            quelle += "  ·  ab %d Jahren" % app["min_age"]
        sub = QLabel("%s  ·  %s" % (app["summary"], quelle))
        sub.setWordWrap(True)
        sub.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        v.addWidget(name)
        v.addWidget(sub)
        h.addLayout(v, 1)

        if is_installed(app):
            h.addWidget(QLabel("✓ Installiert"))
            rm = QPushButton(QIcon.fromTheme("edit-delete"), "Entfernen")
            rm.clicked.connect(lambda _=False, a=app, b=rm: self.on_remove(a, b))
            h.addWidget(rm)
        elif LIVE and app["_src"] == "flatpak":
            btn = QPushButton("Nach der Installation verfügbar")
            btn.setEnabled(False)
            btn.setToolTip("Dieses Programm kommt als Flatpak. Flatpaks lassen sich erst "
                           "installieren, wenn Pingulinux fest auf dem Computer installiert ist.")
            h.addWidget(btn)
        else:
            btn = QPushButton(QIcon.fromTheme("download"), "Installieren")
            btn.clicked.connect(lambda _=False, a=app, b=btn: self.on_install(a, b))
            h.addWidget(btn)
        return w

    # ---------- Fragen ----------
    def ask(self, text, secondary, question=True):
        box = QMessageBox(self)
        box.setWindowTitle("Pingulinux App Store")
        box.setText("<b>%s</b>" % text.replace("&", "&amp;").replace("<", "&lt;"))
        box.setInformativeText(secondary)
        if question:
            box.setIcon(QMessageBox.Icon.Question)
            ok = box.addButton("Entfernen", QMessageBox.ButtonRole.AcceptRole)
            box.addButton("Abbrechen", QMessageBox.ButtonRole.RejectRole)
        else:
            box.setIcon(QMessageBox.Icon.Information)
            ok = box.addButton("OK", QMessageBox.ButtonRole.AcceptRole)
        box.exec()
        return box.clickedButton() is ok

    # ---------- Installieren / Entfernen ----------
    def on_install(self, app, btn):
        if self.busy:
            return
        self.busy = True
        btn.setEnabled(False)
        btn.setText("Bitte warten…")
        self.status.setText("%s wird installiert – ein Erwachsener muss das Passwort eingeben." % app["name"])
        if app["_src"] == "apt":
            cmd = ["pkexec", "sh", "-c",
                   "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; "
                   "apt-get install -y %s" % " ".join(shlex.quote(p) for p in apt_pkgs(app))]
        else:
            cmd = ["pkexec", "sh", "-c",
                   "flatpak install -y --system flathub %s; rc=$?; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % shlex.quote(app["flatpak"])]
        threading.Thread(target=self.run_logged, args=(cmd, app, "install"), daemon=True).start()

    def on_remove(self, app, btn):
        if self.busy:
            return
        if app["_src"] == "apt":
            pkgs = apt_pkgs(app)
            would = apt_removal_set(" ".join(pkgs))
            if would is None or pkgs[0] not in [p.split(":")[0] for p in would]:
                self.ask("%s kann nicht entfernt werden" % app["name"],
                         "Das Programm gehört zum Grundsystem von Pingulinux.", question=False)
                return
            others = [p for p in would if p.split(":")[0] not in pkgs]
            if others:
                self.ask("%s kann nicht einzeln entfernt werden" % app["name"],
                         "Dabei würden auch andere Programme oder Systemteile entfernt:\n%s"
                         % ", ".join(others[:12]) + (" …" if len(others) > 12 else ""),
                         question=False)
                return
        if not self.ask("%s entfernen?" % app["name"],
                        "Das Programm wird für alle Konten entfernt. Gespeicherte Dateien "
                        "(zum Beispiel Bilder oder Dokumente) bleiben erhalten. "
                        "Ein Erwachsener muss gleich das Passwort eingeben."):
            return
        self.busy = True
        btn.setEnabled(False)
        btn.setText("Bitte warten…")
        self.status.setText("%s wird entfernt – ein Erwachsener muss das Passwort eingeben." % app["name"])
        if app["_src"] == "apt":
            cmd = ["pkexec", "sh", "-c",
                   "export DEBIAN_FRONTEND=noninteractive; "
                   "apt-get remove -y --no-auto-remove %s; rc=$?; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc"
                   % " ".join(shlex.quote(p) for p in apt_pkgs(app))]
        else:
            cmd = ["pkexec", "sh", "-c",
                   "flatpak uninstall -y --system %s; rc=$?; "
                   "[ $rc -eq 0 ] && flatpak uninstall -y --system --unused; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % shlex.quote(app["flatpak"])]
        threading.Thread(target=self.run_logged, args=(cmd, app, "remove"), daemon=True).start()

    def run_logged(self, cmd, app, action):
        r = run(cmd)
        try:
            with open(LOG, "a") as f:
                f.write("$ %s\n%s\n%s\n" % (" ".join(cmd), r.stdout[-3000:], r.stderr[-3000:]))
        except OSError:
            pass
        self.worker.finished.emit(app, r.returncode, action)   # zurück in den Haupt-Thread

    def done(self, app, rc, action):
        self.busy = False
        if rc == 0:
            self.status.setText(("✅ %s wurde entfernt." if action == "remove"
                                 else "✅ %s ist jetzt installiert.") % app["name"])
        elif rc in (126, 127):
            self.status.setText("Abgebrochen – es wurde nichts geändert.")
        elif action == "remove":
            self.status.setText("⚠️ Entfernen fehlgeschlagen. Details: " + LOG)
        else:
            self.status.setText("⚠️ Installation fehlgeschlagen. Details: " + LOG)
        self.refresh()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("pingulinux-store")
    app.setDesktopFileName("pingulinux-store")
    win = Store()
    win.show()
    sys.exit(app.exec())
