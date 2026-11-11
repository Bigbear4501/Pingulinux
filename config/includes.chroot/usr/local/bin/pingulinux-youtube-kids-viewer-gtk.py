#!/usr/bin/env python3
"""pingulinux-youtube-kids-viewer-gtk.py - ALTE GTK/WebKit-Fassung (nur Ersatz, falls Qt-WebEngine fehlt).

Kein Browser: keine Adressleiste, keine Tabs, kein Rechtsklick-Menü,
keine Entwicklerwerkzeuge. Das Fenster kann nur YouTube Kids anzeigen
(und die Zustimmungs-/Anmeldeseiten, die YouTube Kids selbst braucht).
Links zu anderen Seiten und neue Fenster werden blockiert.

Braucht: gir1.2-webkit2-4.1 und für Videos die GStreamer-Plugins
(gstreamer1.0-plugins-good, gstreamer1.0-plugins-bad, gstreamer1.0-libav).
"""
import gi
gi.require_version("Gtk", "3.0")
gi.require_version("WebKit2", "4.1")
from gi.repository import Gtk, Gdk, WebKit2
from urllib.parse import urlparse

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


def allowed(uri):
    try:
        u = urlparse(uri)
    except ValueError:
        return False
    if u.scheme in ("about", "data", "blob"):
        return True
    if u.scheme != "https":
        return False
    host = (u.hostname or "").lower()
    return any(host == d or host.endswith("." + d) for d in ALLOWED)


class Viewer(Gtk.Window):
    def __init__(self):
        super().__init__(title="YouTube Kids")
        self.set_default_size(1200, 800)
        try:
            self.set_icon_from_file(LOGO)
        except Exception:
            pass

        head = Gtk.HeaderBar(show_close_button=True, title="YouTube Kids")
        self.back = Gtk.Button.new_from_icon_name("go-previous", Gtk.IconSize.BUTTON)
        self.back.set_tooltip_text("Zurück")
        self.back.connect("clicked", lambda *_: self.view.go_back())
        home = Gtk.Button.new_from_icon_name("go-home", Gtk.IconSize.BUTTON)
        home.set_tooltip_text("Zur Startseite")
        home.connect("clicked", lambda *_: self.view.load_uri(START))
        full = Gtk.Button.new_from_icon_name("view-fullscreen", Gtk.IconSize.BUTTON)
        full.set_tooltip_text("Vollbild")
        full.connect("clicked", self.toggle_fullscreen)
        head.pack_start(self.back)
        head.pack_start(home)
        head.pack_end(full)
        self.set_titlebar(head)
        self.is_full = False

        ctx = WebKit2.WebContext.get_default()
        self.view = WebKit2.WebView.new_with_context(ctx)
        s = self.view.get_settings()
        s.set_enable_developer_extras(False)
        s.set_javascript_can_open_windows_automatically(False)
        s.set_enable_media(True)
        s.set_enable_mediasource(True)
        s.set_media_playback_requires_user_gesture(False)

        self.view.connect("decide-policy", self.on_policy)
        self.view.connect("context-menu", lambda *_: True)        # kein Rechtsklick-Menü
        self.view.connect("create", lambda *_: None)              # keine neuen Fenster
        self.view.connect("notify::uri", self.on_uri)
        self.view.connect("load-changed", lambda *_: self.back.set_sensitive(self.view.can_go_back()))
        self.view.connect("enter-fullscreen", lambda *_: False)

        # Im Vollbild ist die Titelleiste weg. Damit man ohne Tastatur
        # (Tablet) wieder herauskommt, liegt dann oben rechts ein Knopf.
        self.exit_btn = Gtk.Button(label="  Vollbild beenden")
        self.exit_btn.set_image(Gtk.Image.new_from_icon_name("view-restore", Gtk.IconSize.LARGE_TOOLBAR))
        self.exit_btn.set_always_show_image(True)
        self.exit_btn.set_halign(Gtk.Align.END)
        self.exit_btn.set_valign(Gtk.Align.START)
        self.exit_btn.set_margin_top(12)
        self.exit_btn.set_margin_end(12)
        self.exit_btn.set_no_show_all(True)
        self.exit_btn.connect("clicked", lambda *_: self.leave_fullscreen())

        overlay = Gtk.Overlay()
        overlay.add(self.view)
        overlay.add_overlay(self.exit_btn)
        self.add(overlay)

        # Esc und F11 beenden das Vollbild auch mit der Tastatur
        self.connect("key-press-event", self.on_key)
        # Fensterzustand verfolgen, auch wenn YouTube Kids selbst ins
        # Vollbild schaltet (Vollbild-Knopf im Video)
        self.connect("window-state-event", self.on_state)
        self.view.load_uri(START)

    def toggle_fullscreen(self, *_):
        if self.is_full:
            self.leave_fullscreen()
        else:
            self.fullscreen()

    def leave_fullscreen(self):
        # Video-Vollbild der Webseite verlassen, dann das Fenster
        self.view.run_javascript("if (document.fullscreenElement) document.exitFullscreen();", None, None, None)
        self.unfullscreen()

    def on_key(self, _win, event):
        if event.keyval in (Gdk.KEY_Escape, Gdk.KEY_F11):
            if self.is_full:
                self.leave_fullscreen()
                return True
            if event.keyval == Gdk.KEY_F11:
                self.fullscreen()
                return True
        return False

    def on_state(self, _win, event):
        self.is_full = bool(event.new_window_state & Gdk.WindowState.FULLSCREEN)
        if self.is_full:
            self.exit_btn.show()
        else:
            self.exit_btn.hide()
        return False

    def on_policy(self, _view, decision, kind):
        if kind == WebKit2.PolicyDecisionType.NEW_WINDOW_ACTION:
            # Links, die ein neues Fenster öffnen wollen: nur erlaubte Seiten,
            # und dann im selben Fenster.
            uri = decision.get_navigation_action().get_request().get_uri()
            decision.ignore()
            if allowed(uri):
                self.view.load_uri(uri)
            return True
        if kind == WebKit2.PolicyDecisionType.NAVIGATION_ACTION:
            action = decision.get_navigation_action()
            uri = action.get_request().get_uri()
            if action.get_navigation_type() == WebKit2.NavigationType.LINK_CLICKED and not allowed(uri):
                decision.ignore()
                return True
        return False

    def on_uri(self, *_):
        # Sicherheitsnetz: Landet die Hauptseite doch woanders, zurück zu YouTube Kids.
        uri = self.view.get_uri()
        if uri and not allowed(uri):
            self.view.stop_loading()
            self.view.load_uri(START)


if __name__ == "__main__":
    win = Viewer()
    win.connect("destroy", Gtk.main_quit)
    win.show_all()
    Gtk.main()
