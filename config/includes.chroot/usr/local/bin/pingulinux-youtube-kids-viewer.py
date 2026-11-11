#!/usr/bin/env python3
"""pingulinux-youtube-kids-viewer.py - YouTube Kids in einem eigenen Fenster.

Qt6-WebEngine (KDE-Unterbau) statt WebKit/GTK. Dadurch braucht die
ISO keinen zweiten Browser-Kern mehr.

Kein Browser: keine Adressleiste, keine Tabs, kein Rechtsklick-Menü, keine
Entwicklerwerkzeuge. Das Fenster zeigt nur YouTube Kids (und die
Zustimmungs-/Anmeldeseiten, die YouTube Kids selbst braucht).

Sicherheit:
  * Hauptseite: nur erlaubte Adressen (https), alles andere wird blockiert
  * neue Fenster/Tabs: erlaubte Adressen im selben Fenster, sonst nichts
  * keine Downloads, keine Datei-Auswahl (kein Zugriff auf eigene Dateien)
  * Kamera, Mikrofon, Standort, Benachrichtigungen, Bildschirm teilen: aus
  * kein Rechtsklick-Menü, keine Entwicklerwerkzeuge, kein Remote-Debugging
  * eigenes Profil nur für YouTube Kids (Cookies bleiben, z. B. Zustimmung)

Braucht: python3-pyqt6, python3-pyqt6.qtwebengine
Ersatz: Fehlt Qt-WebEngine, startet die alte GTK-Fassung
(pingulinux-youtube-kids-viewer-gtk.py), falls vorhanden.
"""
import os
import sys
from urllib.parse import urlparse

# Keine Hintertüren über Umgebungsvariablen (Entwicklerwerkzeuge,
# eigene Chromium-Schalter)
for var in ("QTWEBENGINE_REMOTE_DEBUGGING", "QTWEBENGINE_CHROMIUM_FLAGS",
            "QTWEBENGINE_DISABLE_SANDBOX"):
    os.environ.pop(var, None)

try:
    from PyQt6.QtCore import Qt, QUrl, QTimer
    from PyQt6.QtGui import QIcon, QKeySequence, QShortcut, QAction
    from PyQt6.QtWidgets import QApplication, QMainWindow, QToolBar, QPushButton, QWidget, QSizePolicy
    from PyQt6.QtWebEngineWidgets import QWebEngineView
    from PyQt6.QtWebEngineCore import (QWebEnginePage, QWebEngineProfile,
                                       QWebEngineSettings)
except ImportError:
    gtk = "/usr/local/bin/pingulinux-youtube-kids-viewer-gtk.py"
    if os.path.exists(gtk):
        os.execv(sys.executable, [sys.executable, gtk] + sys.argv[1:])
    sys.stderr.write("Qt-WebEngine fehlt (python3-pyqt6.qtwebengine)\n")
    sys.exit(1)

START = "https://www.youtubekids.com/"
LOGO = "/usr/share/pingulinux/icons/pingu.png"

# Seiten, die das Fenster als Hauptseite anzeigen darf.
ALLOWED = (
    "youtubekids.com",          # YouTube Kids selbst
    "consent.youtube.com",      # Cookie-Zustimmung (EU)
    "consent.google.com",
    "accounts.google.com",      # Anmeldung eines Elternteils, falls gewünscht
    "accounts.youtube.com",
)


def allowed(url):
    """url: QUrl oder str"""
    s = url.toString() if isinstance(url, QUrl) else str(url)
    try:
        u = urlparse(s)
    except ValueError:
        return False
    if u.scheme in ("about", "data", "blob"):
        return True
    if u.scheme != "https":
        return False
    host = (u.hostname or "").lower()
    return any(host == d or host.endswith("." + d) for d in ALLOWED)


class Page(QWebEnginePage):
    def __init__(self, profile, window):
        super().__init__(profile, window)
        self.win = window
        self.fullScreenRequested.connect(self.on_fullscreen)
        # Berechtigungen (Kamera, Mikrofon, Standort …) immer ablehnen.
        # Qt ab 6.8: permissionRequested, ältere: featurePermissionRequested
        if hasattr(self, "permissionRequested"):
            self.permissionRequested.connect(lambda perm: perm.deny())
        if hasattr(self, "featurePermissionRequested"):
            self.featurePermissionRequested.connect(self.deny_feature)

    def deny_feature(self, origin, feature):
        try:
            self.setFeaturePermission(origin, feature,
                                      QWebEnginePage.PermissionPolicy.PermissionDeniedByUser)
        except Exception:
            pass

    def acceptNavigationRequest(self, url, nav_type, is_main_frame):
        if not is_main_frame:
            return True            # eingebettete Teile (Videos, Werbung der Seite selbst)
        if allowed(url):
            return True
        # Hauptseite soll woanders hin: blockieren. Wurde nicht geklickt
        # (Weiterleitung), sicherheitshalber zurück zur Startseite.
        if nav_type != QWebEnginePage.NavigationType.NavigationTypeLinkClicked:
            QTimer.singleShot(0, lambda: self.setUrl(QUrl(START)))
        return False

    def createWindow(self, _type):
        # Neue Fenster/Tabs: Adresse abfangen, erlaubte im selben Fenster öffnen
        return Catcher(self.profile(), self)

    def chooseFiles(self, *_):
        return []                  # keine Datei-Auswahl

    def javaScriptConsoleMessage(self, *_):
        pass                       # nichts ins Terminal schreiben

    def on_fullscreen(self, req):
        req.accept()
        if req.toggleOn():
            self.win.showFullScreen()
        else:
            self.win.showNormal()


class Catcher(QWebEnginePage):
    """Unsichtbare Seite für „neues Fenster“: liest nur die Adresse."""

    def __init__(self, profile, main_page):
        super().__init__(profile, main_page)
        self.main = main_page

    def acceptNavigationRequest(self, url, *_):
        if allowed(url):
            self.main.setUrl(url)
        QTimer.singleShot(0, self.deleteLater)
        return False


class Viewer(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("YouTube Kids")
        self.resize(1200, 800)
        if os.path.exists(LOGO):
            self.setWindowIcon(QIcon(LOGO))

        data = os.path.join(os.path.expanduser("~"), ".local/share/pingulinux/youtube-kids")
        os.makedirs(data, exist_ok=True)
        profile = QWebEngineProfile("pingulinux-youtube-kids", QApplication.instance())
        profile.setPersistentStoragePath(os.path.join(data, "storage"))
        profile.setCachePath(os.path.join(data, "cache"))
        profile.setHttpAcceptLanguage("de-DE,de;q=0.9")
        profile.downloadRequested.connect(lambda item: item.cancel())   # keine Downloads

        self.page = Page(profile, self)
        s = self.page.settings()
        A = QWebEngineSettings.WebAttribute
        for attr, on in (
            ("JavascriptCanOpenWindows", False),
            ("JavascriptCanAccessClipboard", False),
            ("LocalContentCanAccessRemoteUrls", False),
            ("LocalContentCanAccessFileUrls", False),
            ("AllowRunningInsecureContent", False),
            ("AllowGeolocationOnInsecureOrigins", False),
            ("PluginsEnabled", False),
            ("PdfViewerEnabled", False),
            ("ScreenCaptureEnabled", False),
            ("FullScreenSupportEnabled", True),
            ("PlaybackRequiresUserGesture", False),
        ):
            if hasattr(A, attr):
                s.setAttribute(getattr(A, attr), on)

        self.view = QWebEngineView(self)
        self.view.setPage(self.page)
        self.view.setContextMenuPolicy(Qt.ContextMenuPolicy.NoContextMenu)
        self.setCentralWidget(self.view)

        bar = QToolBar(self)
        bar.setMovable(False)
        bar.setContextMenuPolicy(Qt.ContextMenuPolicy.PreventContextMenu)
        self.addToolBar(bar)
        self.back = QAction(QIcon.fromTheme("go-previous"), "Zurück", self)
        self.back.triggered.connect(self.view.back)
        home = QAction(QIcon.fromTheme("go-home"), "Zur Startseite", self)
        home.triggered.connect(lambda: self.view.setUrl(QUrl(START)))
        bar.addAction(self.back)
        bar.addAction(home)
        spacer = QWidget()
        spacer.setSizePolicy(QSizePolicy.Policy.Expanding, QSizePolicy.Policy.Preferred)
        bar.addWidget(spacer)
        full = QAction(QIcon.fromTheme("view-fullscreen"), "Vollbild", self)
        full.triggered.connect(self.toggle_fullscreen)
        bar.addAction(full)
        self.bar = bar
        self.view.urlChanged.connect(lambda *_: self.back.setEnabled(self.view.history().canGoBack()))

        # Im Vollbild: Knopf oben rechts zum Beenden (Tablet ohne Tastatur)
        self.exit_btn = QPushButton(QIcon.fromTheme("view-restore"), "  Vollbild beenden", self)
        self.exit_btn.setStyleSheet("QPushButton{padding:8px 14px;font-size:15px;}")
        self.exit_btn.clicked.connect(self.leave_fullscreen)
        self.exit_btn.hide()

        for key in ("Esc", "F11"):
            QShortcut(QKeySequence(key), self, activated=lambda k=key: self.on_key(k))

        self.view.setUrl(QUrl(START))

    def toggle_fullscreen(self):
        if self.isFullScreen():
            self.leave_fullscreen()
        else:
            self.showFullScreen()

    def leave_fullscreen(self):
        # Video-Vollbild der Webseite verlassen, dann das Fenster
        self.page.runJavaScript("if (document.fullscreenElement) document.exitFullscreen();")
        self.showNormal()

    def on_key(self, key):
        if self.isFullScreen():
            self.leave_fullscreen()
        elif key == "F11":
            self.showFullScreen()

    def changeEvent(self, ev):
        super().changeEvent(ev)
        if not hasattr(self, "exit_btn"):
            return                 # Fenster wird noch aufgebaut
        full = self.isFullScreen()
        self.bar.setVisible(not full)
        self.exit_btn.setVisible(full)
        if full:
            self.place_exit()

    def resizeEvent(self, ev):
        super().resizeEvent(ev)
        if hasattr(self, "exit_btn") and self.exit_btn.isVisible():
            self.place_exit()

    def place_exit(self):
        self.exit_btn.adjustSize()
        self.exit_btn.move(self.width() - self.exit_btn.width() - 12, 12)
        self.exit_btn.raise_()


if __name__ == "__main__":
    app = QApplication(sys.argv)
    app.setApplicationName("pingulinux-youtube-kids")
    app.setDesktopFileName("pingulinux-youtube-kids")
    win = Viewer()
    win.show()
    sys.exit(app.exec())
