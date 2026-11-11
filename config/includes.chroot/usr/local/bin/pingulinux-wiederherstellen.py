#!/usr/bin/env python3
"""pingulinux-wiederherstellen.py - Sicherungen ansehen und wiederherstellen.

eigene Qt-Oberfläche (KDE-Stil) für Timeshift. Eltern sehen
Timeshift selbst nicht mehr (im Startmenü ausgeblendet), der Unterbau bleibt
Timeshift.

  • Liste aller Sicherungen (Festplatte oder eingesteckter Sicherungs-Stick)
  • „Jetzt sichern“
  • „Diesen Stand wiederherstellen“ (danach Neustart)
  • „Timeshift öffnen“ für Fortgeschrittene

Läuft als angemeldeter Erwachsener. Was root braucht, geht über
pkexec pingulinux-root-helper (Passwort einmal, dann ein paar Minuten gemerkt).
Ersatz: Fehlt PyQt6, startet timeshift-gtk.
"""
import os
import re
import subprocess
import sys
import threading

try:
    from PyQt6.QtCore import Qt, QObject, pyqtSignal
    from PyQt6.QtGui import QIcon
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                                 QLabel, QPushButton, QListWidget, QListWidgetItem, QComboBox,
                                 QMessageBox, QProgressBar)
except ImportError:
    os.execvp("timeshift-gtk", ["timeshift-gtk"])

LOGO = "/usr/share/pingulinux/icons/pingu.png"
LOG = os.path.expanduser("~/.cache/pingulinux-wiederherstellen.log")
HELPER = ["pkexec", "/usr/local/bin/pingulinux-root-helper"]
TAGS = {"O": "von Hand", "D": "täglich", "W": "wöchentlich", "M": "monatlich",
        "H": "stündlich", "B": "beim Start"}
MONATE = ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August",
          "September", "Oktober", "November", "Dezember"]


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def log(r):
    try:
        with open(LOG, "a") as f:
            f.write("$ %s\n%s\n%s\n" % (" ".join(r.args), r.stdout[-4000:], r.stderr[-4000:]))
    except OSError:
        pass


def devices():
    """Festplatte (Standard) plus eingesteckte Sticks mit Linux-Dateisystem."""
    out = [("", "💻  Diese Festplatte (tägliche Sicherung)")]
    src = run(["findmnt", "-no", "SOURCE", "/"]).stdout.strip()
    rootdisk = run(["lsblk", "-npdo", "PKNAME", src]).stdout.strip() if src else ""

    def extern(dev):
        # HOTPLUG oder RM = 1 oder über USB angeschlossen (manche Sticks und
        # Sticks in einer VM melden HOTPLUG=0, aber TRAN=usb)
        f = run(["lsblk", "-dno", "HOTPLUG,RM,TRAN", dev]).stdout.split()
        return "1" in f[:2] or "usb" in f[2:]

    r = run(["lsblk", "-Pnpo", "NAME,FSTYPE,SIZE,LABEL,PKNAME"])
    for line in r.stdout.splitlines():
        d = dict(re.findall(r'(\w+)="([^"]*)"', line))
        if d.get("FSTYPE") not in ("ext2", "ext3", "ext4", "btrfs", "xfs"):
            continue
        if rootdisk and rootdisk in (d.get("NAME"), d.get("PKNAME")):
            continue
        if d.get("NAME") == src:
            continue
        if extern(d["NAME"]) or (d.get("PKNAME") and extern(d["PKNAME"])):
            out.append((d["NAME"], "🔌  %s – %s" % (d.get("LABEL") or "USB-Stick", d.get("SIZE", ""))))
    return out


def nice_date(name):
    m = re.match(r"(\d{4})-(\d{2})-(\d{2})_(\d{2})-(\d{2})", name)
    if not m:
        return name
    y, mo, d, h, mi = m.groups()
    return "%d. %s %s, %s:%s Uhr" % (int(d), MONATE[int(mo) - 1], y, h, mi)


def snapshots(dev):
    r = run(HELPER + ["ts-list"] + ([dev] if dev else []))
    snaps = []
    for line in r.stdout.splitlines():
        m = re.match(r"^\s*\d+\s+>\s+(\S+)\s*(.*)$", line)
        if not m:
            continue
        name, rest = m.group(1), m.group(2).split()
        tags = []
        while rest and rest[0] in TAGS:
            tags.append(rest.pop(0))
        snaps.append((name, tags, " ".join(rest)))
    snaps.reverse()                     # neueste zuerst
    return snaps, r


class Signals(QObject):
    done = pyqtSignal(str, object)


class Window(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Sicherung und Wiederherstellung")
        self.resize(720, 540)
        if os.path.exists(LOGO):
            self.setWindowIcon(QIcon(LOGO))
        self.sig = Signals()
        self.sig.done.connect(self.finished)

        w = QWidget(); self.setCentralWidget(w)
        v = QVBoxLayout(w)
        v.setContentsMargins(18, 16, 18, 14)
        title = QLabel("💾  Sicherung und Wiederherstellung")
        f = title.font(); f.setPointSizeF(f.pointSizeF() * 1.35); f.setBold(True); title.setFont(f)
        v.addWidget(title)
        hint = QLabel("Pingulinux sichert das System jeden Tag von selbst. Läuft nach einem Update "
                      "oder einer Einstellung etwas nicht mehr, kannst du hier einen älteren Stand "
                      "zurückholen. Eigene Dateien (Fotos, Dokumente) bleiben dabei unverändert.")
        hint.setWordWrap(True)
        v.addWidget(hint)

        row = QHBoxLayout()
        row.addWidget(QLabel("Sicherungen auf:"))
        self.dev = QComboBox()
        for dev, label in devices():
            self.dev.addItem(label, dev)
        self.dev.currentIndexChanged.connect(self.reload)
        row.addWidget(self.dev, 1)
        again = QPushButton(QIcon.fromTheme("view-refresh"), "Neu suchen")
        again.clicked.connect(self.refresh_devices)
        row.addWidget(again)
        v.addLayout(row)

        self.list = QListWidget()
        self.list.setAlternatingRowColors(True)
        self.list.currentRowChanged.connect(self.update_buttons)
        v.addWidget(self.list, 1)

        self.bar = QProgressBar(); self.bar.setRange(0, 0); self.bar.hide()
        v.addWidget(self.bar)
        self.status = QLabel("")
        self.status.setWordWrap(True)
        v.addWidget(self.status)

        btns = QHBoxLayout()
        self.b_now = QPushButton(QIcon.fromTheme("document-save"), "Jetzt sichern")
        self.b_now.clicked.connect(self.backup_now)
        self.b_restore = QPushButton(QIcon.fromTheme("edit-undo"), "Diesen Stand wiederherstellen")
        self.b_restore.clicked.connect(self.restore)
        self.b_expert = QPushButton(QIcon.fromTheme("timeshift"), "Timeshift öffnen")
        self.b_expert.setToolTip("Für Fortgeschrittene: alle Einstellungen von Timeshift")
        self.b_expert.clicked.connect(lambda: subprocess.Popen(["timeshift-launcher"]))
        btns.addWidget(self.b_now)
        btns.addStretch(1)
        btns.addWidget(self.b_expert)
        btns.addWidget(self.b_restore)
        v.addLayout(btns)
        self.busy = False
        self.reload()

    # ---------- Liste ----------
    def refresh_devices(self):
        cur = self.dev.currentData()
        self.dev.blockSignals(True)
        self.dev.clear()
        for dev, label in devices():
            self.dev.addItem(label, dev)
        i = self.dev.findData(cur)
        self.dev.setCurrentIndex(max(i, 0))
        self.dev.blockSignals(False)
        self.reload()

    def reload(self, *_):
        self.list.clear()
        snaps, r = snapshots(self.dev.currentData())
        for name, tags, desc in snaps:
            art = ", ".join(TAGS[t] for t in tags) or "Sicherung"
            text = "%s   ·   %s" % (nice_date(name), desc or art)
            it = QListWidgetItem(QIcon.fromTheme("document-save"), text)
            it.setData(Qt.ItemDataRole.UserRole, name)
            self.list.addItem(it)
        if r.returncode in (126, 127):
            self.status.setText("Abgebrochen – ohne Eltern-Passwort lassen sich die Sicherungen nicht anzeigen.")
            self.update_buttons()
            return
        if not snaps:
            msg = "Noch keine Sicherung vorhanden."
            if r.returncode != 0 and "not" in (r.stdout + r.stderr).lower():
                msg += " (Timeshift ist hier noch nicht eingerichtet.)"
            self.status.setText(msg)
        else:
            self.status.setText("%d Sicherungen gefunden. Die neueste steht oben." % len(snaps))
            self.list.setCurrentRow(0)
        self.update_buttons()

    def update_buttons(self, *_):
        self.b_restore.setEnabled(not self.busy and self.list.currentItem() is not None)
        self.b_now.setEnabled(not self.busy)
        self.dev.setEnabled(not self.busy)

    # ---------- Aktionen ----------
    def start(self, text, cmd, kind):
        self.busy = True
        self.update_buttons()
        self.bar.show()
        self.status.setText(text)

        def work():
            r = run(cmd)
            log(r)
            self.sig.done.emit(kind, r)
        threading.Thread(target=work, daemon=True).start()

    def backup_now(self):
        dev = self.dev.currentData()
        cmd = HELPER + ["ts-create"] + ([dev] if dev else [])
        self.start("Sicherung läuft … das kann einige Minuten dauern.", cmd, "backup")

    def restore(self):
        it = self.list.currentItem()
        if not it:
            return
        name = it.data(Qt.ItemDataRole.UserRole)
        box = QMessageBox(self)
        box.setIcon(QMessageBox.Icon.Warning)
        box.setWindowTitle("Wiederherstellen")
        box.setText("<b>Stand vom %s wiederherstellen?</b>" % nice_date(name))
        box.setInformativeText(
            "Das System wird auf diesen Stand zurückgesetzt. Programme und Einstellungen, "
            "die danach dazugekommen sind, sind dann weg.\n\n"
            "Eigene Dateien (Fotos, Dokumente) bleiben unverändert.\n\n"
            "Bitte alle anderen Programme schließen. Danach startet der Computer neu.")
        ok = box.addButton("Wiederherstellen und neu starten", QMessageBox.ButtonRole.AcceptRole)
        box.addButton("Abbrechen", QMessageBox.ButtonRole.RejectRole)
        box.exec()
        if box.clickedButton() is not ok:
            return
        dev = self.dev.currentData()
        cmd = HELPER + ["ts-restore", name] + ([dev] if dev else [])
        self.start("Wiederherstellung läuft … bitte den Computer nicht ausschalten.", cmd, "restore")

    def finished(self, kind, r):
        self.busy = False
        self.bar.hide()
        if kind == "backup":
            self.reload()
            if r.returncode == 0:
                self.status.setText("✅ Sicherung fertig.")
            else:
                self.status.setText("⚠️ Die Sicherung hat nicht geklappt. Details: " + LOG)
        else:
            if r.returncode == 0:
                QMessageBox.information(self, "Wiederherstellen",
                                        "✅ Fertig. Der Computer startet jetzt neu.")
                subprocess.run(HELPER + ["ts-reboot"])
            else:
                self.status.setText("⚠️ Die Wiederherstellung hat nicht geklappt – es wurde nichts "
                                    "geändert oder nur teilweise. Details: " + LOG)
        self.update_buttons()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("pingulinux-wiederherstellen")
    win = Window()
    win.show()
    sys.exit(app.exec())
