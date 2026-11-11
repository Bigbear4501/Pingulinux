#!/usr/bin/env python3
"""pingulinux-handbuch.py - Eltern-Handbuch, auch ohne Internet.

Zeigt die Anleitungen aus /usr/share/pingulinux/hilfe/*.md (Fragen von
Eltern, Kontrollzentrum erklärt …) in einem KDE-Fenster: links die Themen,
rechts der Text. Aufruf mit einem Dateinamen öffnet gleich dieses Thema.
Ersatz ohne PyQt6: Textfenster über dialog.sh.
"""
import glob
import os
import subprocess
import sys

HILFE = "/usr/share/pingulinux/hilfe"
LOGO = "/usr/share/pingulinux/icons/pingu.png"


def docs():
    out = []
    for p in sorted(glob.glob(os.path.join(HILFE, "*.md"))):
        title = os.path.basename(p)
        try:
            for line in open(p, encoding="utf-8"):
                if line.startswith("# "):
                    title = line[2:].strip()
                    break
        except OSError:
            continue
        out.append((title, p))
    return out


try:
    from PyQt6.QtCore import Qt, QUrl
    from PyQt6.QtGui import QIcon, QDesktopServices
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QSplitter, QListWidget,
                                 QListWidgetItem, QTextBrowser)
except ImportError:
    d = docs()
    if d:
        want = sys.argv[1] if len(sys.argv) > 1 else ""
        path = next((p for t, p in d if os.path.basename(p) == want), d[0][1])
        subprocess.call(["bash", "-c", '. /usr/local/lib/pingulinux/dialog.sh; pd_textdatei "$1" "$2"',
                         "_", "Eltern-Handbuch", path])
    sys.exit(0)


class Window(QMainWindow):
    def __init__(self, start=""):
        super().__init__()
        self.setWindowTitle("Eltern-Handbuch – Pingulinux OS")
        self.resize(980, 680)
        if os.path.exists(LOGO):
            self.setWindowIcon(QIcon(LOGO))
        split = QSplitter()
        self.setCentralWidget(split)

        self.list = QListWidget()
        self.list.setMinimumWidth(220)
        split.addWidget(self.list)
        self.text = QTextBrowser()
        self.text.setOpenLinks(False)
        self.text.anchorClicked.connect(self.link)
        f = self.text.font(); f.setPointSizeF(f.pointSizeF() * 1.1); self.text.setFont(f)
        self.text.document().setDocumentMargin(18)
        split.addWidget(self.text)
        split.setStretchFactor(1, 1)

        row = 0
        for i, (title, path) in enumerate(docs()):
            it = QListWidgetItem(QIcon.fromTheme("help-contents"), title)
            it.setData(Qt.ItemDataRole.UserRole, path)
            self.list.addItem(it)
            if start and os.path.basename(path) == start:
                row = i
        self.list.currentItemChanged.connect(self.show_doc)
        if self.list.count():
            self.list.setCurrentRow(row)
        else:
            self.text.setMarkdown("Es sind keine Anleitungen vorhanden.")

    def show_doc(self, it, _prev=None):
        if not it:
            return
        try:
            md = open(it.data(Qt.ItemDataRole.UserRole), encoding="utf-8").read()
        except OSError as e:
            md = "Die Anleitung lässt sich nicht öffnen: %s" % e
        self.text.setMarkdown(md)
        self.text.verticalScrollBar().setValue(0)

    def link(self, url):
        name = url.fileName()
        if url.isRelative() and name.endswith(".md"):     # Verweis auf ein anderes Thema
            for i in range(self.list.count()):
                if os.path.basename(self.list.item(i).data(Qt.ItemDataRole.UserRole)) == name:
                    self.list.setCurrentRow(i)
                    return
        QDesktopServices.openUrl(url)


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("pingulinux-handbuch")
    win = Window(sys.argv[1] if len(sys.argv) > 1 else "")
    win.show()
    sys.exit(app.exec())
