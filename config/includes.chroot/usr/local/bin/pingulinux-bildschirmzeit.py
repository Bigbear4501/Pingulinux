#!/usr/bin/env python3
"""pingulinux-bildschirmzeit.py - Bildschirmzeit der Kinder (Eltern-Dashboard).

eigenes Qt-Fenster statt der Timekpr-Oberfläche. Timekpr-nExT
bleibt der Unterbau (es zählt die Zeit und sperrt), ist im Startmenü aber
ausgeblendet.

Pro Kind:
  • heute schon genutzt / heute noch übrig
  • Tageszeit Montag–Freitag und Samstag–Sonntag (in Minuten)
  • erlaubte Uhrzeit (von – bis)
  • „+15 Min. heute“, „+30 Min. heute“ (Extrazeit nur für heute)

Läuft als angemeldeter Erwachsener; Timekpr-Befehle gehen über
pkexec pingulinux-root-helper (Passwort einmal, dann ein paar Minuten gemerkt).
Ersatz: Fehlt PyQt6, öffnet sich die Timekpr-Oberfläche.
"""
import os
import re
import subprocess
import sys

try:
    from PyQt6.QtCore import Qt
    from PyQt6.QtGui import QIcon
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, QHBoxLayout,
                                 QGridLayout, QLabel, QPushButton, QListWidget, QListWidgetItem,
                                 QSpinBox, QGroupBox, QMessageBox, QSplitter)
except ImportError:
    os.execvp("/usr/local/bin/pingulinux-admin-tool.sh",
              ["pingulinux-admin-tool.sh", "bildschirmzeit-timekpr"])

LOGO = "/usr/share/pingulinux/icons/pingu.png"
PROFDIR = "/var/lib/pingulinux/profiles"
HELPER = ["pkexec", "/usr/local/bin/pingulinux-root-helper"]


def run(cmd):
    try:
        return subprocess.run(cmd, capture_output=True, text=True)
    except OSError as e:
        return subprocess.CompletedProcess(cmd, 127, "", str(e))


def kids():
    out = []
    try:
        names = sorted(os.listdir(PROFDIR))
    except OSError:
        return out
    for n in names:
        try:
            age = int(open(os.path.join(PROFDIR, n)).read().strip())
        except (OSError, ValueError):
            continue
        if run(["id", n]).returncode == 0:
            full = ""
            try:
                import pwd
                full = pwd.getpwnam(n).pw_gecos.split(",")[0]
            except KeyError:
                pass
            out.append((n, full or n, age))
    return out


def parse_info(text):
    info = {}
    for line in text.splitlines():
        m = re.match(r"\s*([A-Z_0-9]+)\s*[:=]\s*(.*)$", line)
        if m:
            info[m.group(1)] = m.group(2).strip()
    return info


def first_int(info, *keys):
    for k in keys:
        v = info.get(k)
        if v is not None:
            m = re.match(r"-?\d+", v)
            if m:
                return int(m.group(0))
    return None


def fmt(sec):
    if sec is None:
        return "–"
    sec = max(0, sec)
    h, m = divmod(sec // 60, 60)
    return "%d Std. %02d Min." % (h, m) if h else "%d Min." % m


class Window(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Bildschirmzeit")
        self.resize(820, 560)
        if os.path.exists(LOGO):
            self.setWindowIcon(QIcon(LOGO))
        self.user = None

        w = QWidget(); self.setCentralWidget(w)
        v = QVBoxLayout(w)
        v.setContentsMargins(18, 16, 18, 14)
        title = QLabel("⏰  Bildschirmzeit")
        f = title.font(); f.setPointSizeF(f.pointSizeF() * 1.35); f.setBold(True); title.setFont(f)
        v.addWidget(title)

        split = QSplitter()
        v.addWidget(split, 1)

        self.list = QListWidget()
        self.list.setMinimumWidth(200)
        split.addWidget(self.list)

        right = QWidget(); rv = QVBoxLayout(right); rv.setContentsMargins(12, 0, 0, 0)
        self.name = QLabel("")
        f = self.name.font(); f.setPointSizeF(f.pointSizeF() * 1.2); f.setBold(True); self.name.setFont(f)
        rv.addWidget(self.name)

        today = QGroupBox("Heute")
        tg = QGridLayout(today)
        tg.addWidget(QLabel("Schon genutzt:"), 0, 0)
        self.spent = QLabel("–"); tg.addWidget(self.spent, 0, 1)
        tg.addWidget(QLabel("Noch übrig:"), 1, 0)
        self.left = QLabel("–")
        f = self.left.font(); f.setBold(True); self.left.setFont(f)
        tg.addWidget(self.left, 1, 1)
        extra = QHBoxLayout()
        for mins in (15, 30, 60):
            b = QPushButton(QIcon.fromTheme("list-add"), "+%d Min. heute" % mins)
            b.clicked.connect(lambda _=False, m=mins: self.add_today(m))
            extra.addWidget(b)
        tg.addLayout(extra, 2, 0, 1, 2)
        rv.addWidget(today)

        rules = QGroupBox("Regeln")
        rg = QGridLayout(rules)
        rg.addWidget(QLabel("Montag bis Freitag:"), 0, 0)
        self.wd = QSpinBox(); self.wd.setRange(0, 1440); self.wd.setSingleStep(15); self.wd.setSuffix(" Min. am Tag")
        rg.addWidget(self.wd, 0, 1)
        rg.addWidget(QLabel("Samstag und Sonntag:"), 1, 0)
        self.we = QSpinBox(); self.we.setRange(0, 1440); self.we.setSingleStep(15); self.we.setSuffix(" Min. am Tag")
        rg.addWidget(self.we, 1, 1)
        rg.addWidget(QLabel("Erlaubt von:"), 2, 0)
        hrow = QHBoxLayout()
        self.h_from = QSpinBox(); self.h_from.setRange(0, 23); self.h_from.setSuffix(" Uhr")
        self.h_to = QSpinBox(); self.h_to.setRange(1, 24); self.h_to.setSuffix(" Uhr")
        hrow.addWidget(self.h_from); hrow.addWidget(QLabel("bis")); hrow.addWidget(self.h_to); hrow.addStretch(1)
        rg.addLayout(hrow, 2, 1)
        self.save = QPushButton(QIcon.fromTheme("document-save"), "Regeln speichern")
        self.save.clicked.connect(self.save_rules)
        rg.addWidget(self.save, 3, 1, alignment=Qt.AlignmentFlag.AlignRight)
        rv.addWidget(rules)
        rv.addStretch(1)

        self.status = QLabel("")
        self.status.setWordWrap(True)
        rv.addWidget(self.status)
        split.addWidget(right)
        split.setStretchFactor(1, 1)

        bottom = QHBoxLayout()
        expert = QPushButton(QIcon.fromTheme("preferences-system-time"), "Timekpr öffnen")
        expert.setToolTip("Für Fortgeschrittene: alle Einstellungen von Timekpr-nExT")
        expert.clicked.connect(lambda: subprocess.Popen(
            ["/usr/local/bin/pingulinux-admin-tool.sh", "bildschirmzeit-timekpr"]))
        refresh = QPushButton(QIcon.fromTheme("view-refresh"), "Aktualisieren")
        refresh.clicked.connect(self.load)
        bottom.addWidget(refresh); bottom.addStretch(1); bottom.addWidget(expert)
        v.addLayout(bottom)

        self.list.currentRowChanged.connect(self.load)
        self.kids = kids()
        for n, full, age in self.kids:
            it = QListWidgetItem(QIcon.fromTheme("user-identity"), "%s  (%d Jahre)" % (full, age))
            it.setData(Qt.ItemDataRole.UserRole, n)
            self.list.addItem(it)
        if self.kids:
            self.list.setCurrentRow(0)
        else:
            self.name.setText("Es gibt noch keine Kinderkonten.")
            self.status.setText("Kinderkonten legst du im Kontrollzentrum unter „Benutzerkonten“ an.")
            for wdg in (today, rules):
                wdg.setEnabled(False)

    # ---------- Laden / Speichern ----------
    def load(self, *_):
        it = self.list.currentItem()
        if not it:
            return
        self.user = it.data(Qt.ItemDataRole.UserRole)
        self.name.setText(it.text())
        r = run(HELPER + ["tk-info", self.user])
        if r.returncode in (126, 127):
            self.status.setText("Abgebrochen – ohne Eltern-Passwort lässt sich die Bildschirmzeit nicht anzeigen.")
            return
        info = parse_info(r.stdout)
        self.spent.setText(fmt(first_int(info, "ACTUAL_TIME_SPENT_DAY", "TIME_SPENT_DAY")))
        self.left.setText(fmt(first_int(info, "ACTUAL_TIME_LEFT_DAY", "TIME_LEFT_DAY")))
        lim = [x for x in info.get("LIMITS_PER_WEEKDAYS", "").split(";") if x.strip().isdigit()]
        if len(lim) >= 7:
            self.wd.setValue(int(lim[0]) // 60)
            self.we.setValue(int(lim[5]) // 60)
        hours = [int(m.group(1)) for h in info.get("ALLOWED_HOURS_1", "").split(";")
                 for m in [re.match(r"\s*(\d+)", h)] if m]
        if hours:
            self.h_from.setValue(min(hours))
            self.h_to.setValue(max(hours) + 1)
        self.status.setText("" if r.returncode == 0 else "⚠️ Timekpr hat keine Daten geliefert.")

    def save_rules(self):
        if not self.user:
            return
        a, b = self.h_from.value(), self.h_to.value()
        if b <= a:
            QMessageBox.warning(self, "Bildschirmzeit", "„bis“ muss später sein als „von“.")
            return
        hours = ";".join(str(h) for h in range(a, b))
        r1 = run(HELPER + ["tk-limits", self.user, str(self.wd.value() * 60), str(self.we.value() * 60)])
        r2 = run(HELPER + ["tk-hours", self.user, hours]) if r1.returncode == 0 else r1
        self.load()
        if r1.returncode == 0 and r2.returncode == 0:
            self.status.setText("✅ Gespeichert.")
        elif r1.returncode in (126, 127):
            self.status.setText("Abgebrochen – es wurde nichts geändert.")
        else:
            self.status.setText("⚠️ Speichern hat nicht geklappt: " + (r2.stderr or r1.stderr).strip()[:200])

    def add_today(self, mins):
        if not self.user:
            return
        r = run(HELPER + ["tk-extra", self.user, str(mins * 60)])
        if r.returncode == 0:
            self.load()
            self.status.setText("✅ %d Minuten extra für heute." % mins)
        elif r.returncode in (126, 127):
            self.status.setText("Abgebrochen – es wurde nichts geändert.")
        else:
            self.status.setText("⚠️ Hat nicht geklappt: " + r.stderr.strip()[:200])


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("pingulinux-bildschirmzeit")
    win = Window()
    win.show()
    sys.exit(app.exec())
