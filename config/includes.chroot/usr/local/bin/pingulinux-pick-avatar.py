#!/usr/bin/env python3
"""Profilbild-Auswahl: Galerie mit Bildern aus Debian/Plasma plus eigenes Bild.
Gibt den gewählten Dateipfad aus (leer = Abbruch).

Beta 1: Qt6-Oberfläche (KDE-Stil). Ersatz: pingulinux-pick-avatar-gtk.py
"""
import os
import sys

try:
    from PyQt6.QtCore import Qt, QSize
    from PyQt6.QtGui import QIcon, QPixmap
    from PyQt6.QtWidgets import (QApplication, QDialog, QVBoxLayout, QLabel, QListWidget,
                                 QListWidgetItem, QDialogButtonBox, QFileDialog, QPushButton)
except ImportError:
    gtk = "/usr/local/bin/pingulinux-pick-avatar-gtk.py"
    if os.path.exists(gtk):
        os.execv(sys.executable, [sys.executable, gtk] + sys.argv[1:])
    sys.exit(1)

NAME = sys.argv[1] if len(sys.argv) > 1 else ""
DIRS = ["/usr/share/pingulinux/avatars", "/usr/share/plasma/avatars",
        "/usr/share/pixmaps/faces", "/usr/share/pixmaps/avatars",
        "/usr/share/gnome-control-center/pixmaps"]
EXT = ("png", "jpg", "jpeg", "svg", "webp")
PINGU = "/usr/share/pingulinux/icons/pingu.png"


def collect():
    seen, out = set(), []
    for d in DIRS:
        for root, _, files in os.walk(d):
            for f in sorted(files):
                if f.lower().endswith(EXT):
                    p = os.path.join(root, f)
                    if p not in seen:
                        seen.add(p)
                        out.append(p)
    if os.path.exists(PINGU) and PINGU not in out:
        out.insert(0, PINGU)
    return out


class Picker(QDialog):
    def __init__(self):
        super().__init__()
        self.result_path = ""
        self.setWindowTitle("Profilbild" + (" für " + NAME if NAME else ""))
        if os.path.exists(PINGU):
            self.setWindowIcon(QIcon(PINGU))
        self.resize(640, 480)
        lay = QVBoxLayout(self)
        lay.addWidget(QLabel("Wähle ein Bild aus:"))

        self.view = QListWidget()
        self.view.setViewMode(QListWidget.ViewMode.IconMode)
        self.view.setIconSize(QSize(96, 96))
        self.view.setGridSize(QSize(120, 130))
        self.view.setResizeMode(QListWidget.ResizeMode.Adjust)
        self.view.setMovement(QListWidget.Movement.Static)
        self.view.setWordWrap(True)
        for p in collect():
            pm = QPixmap(p)
            if pm.isNull():
                continue
            pm = pm.scaled(96, 96, Qt.AspectRatioMode.KeepAspectRatio,
                           Qt.TransformationMode.SmoothTransformation)
            label = os.path.splitext(os.path.basename(p))[0].replace("_", " ")
            it = QListWidgetItem(QIcon(pm), label)
            it.setData(Qt.ItemDataRole.UserRole, p)
            self.view.addItem(it)
        if self.view.count():
            self.view.setCurrentRow(0)
        self.view.itemActivated.connect(lambda *_: self.choose())
        lay.addWidget(self.view, 1)

        bb = QDialogButtonBox()
        own = QPushButton(QIcon.fromTheme("document-open"), "Eigenes Bild…")
        bb.addButton(own, QDialogButtonBox.ButtonRole.ActionRole)
        bb.addButton("Abbrechen", QDialogButtonBox.ButtonRole.RejectRole)
        okb = bb.addButton("Auswählen", QDialogButtonBox.ButtonRole.AcceptRole)
        okb.setDefault(True)
        own.clicked.connect(self.own_image)
        bb.accepted.connect(self.choose)
        bb.rejected.connect(self.reject)
        lay.addWidget(bb)

    def choose(self):
        it = self.view.currentItem()
        if it:
            self.result_path = it.data(Qt.ItemDataRole.UserRole)
            self.accept()

    def own_image(self):
        pat = " ".join("*." + e for e in EXT + ("bmp", "gif"))
        path, _ = QFileDialog.getOpenFileName(self, "Eigenes Bild wählen",
                                              os.path.expanduser("~"), "Bilder (%s)" % pat)
        if path:
            self.result_path = path
            self.accept()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    dlg = Picker()
    dlg.exec()
    print(dlg.result_path)
