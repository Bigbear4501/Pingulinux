#!/usr/bin/env python3
"""Pingulinux App Store - zeigt nur kuratierte Programme (Whitelist).

Installation: bevorzugt als Debian-Paket (apt); nur wenn es kein
Debian-Paket gibt, wird die Flatpak-Version von Flathub genutzt.
Installieren braucht das Passwort eines Administrators (pkexec).
"""
import json, subprocess, threading
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

CATALOG = "/usr/share/pingulinux/store-apps.json"
LOGO = "/usr/share/pingulinux/icons/pingu.png"


def run(cmd):
    return subprocess.run(cmd, capture_output=True, text=True)


def apt_candidate(pkg):
    r = run(["apt-cache", "policy", pkg])
    for line in r.stdout.splitlines():
        if line.strip().startswith("Candidate:"):
            return "(none)" not in line
    return False


def apt_installed(pkg):
    r = run(["dpkg-query", "-W", "-f=${Status}", pkg])
    return r.returncode == 0 and "install ok installed" in r.stdout


def flatpak_installed(ref):
    return run(["flatpak", "info", "--system", ref]).returncode == 0


def pick_source(app):
    """Debian-Paket hat immer Vorrang. Flatpak nur, wenn es fuer das
    Programm gar kein Debian-Paket gibt (Eintrag ohne "apt")."""
    if app.get("apt"):
        return "apt"
    if app.get("flatpak"):
        return "flatpak"
    return None


def is_installed(app, src):
    if src == "apt":
        return apt_installed(app["apt"])
    if src == "flatpak":
        return flatpak_installed(app["flatpak"])
    return False


class Store(Gtk.Window):
    def __init__(self):
        super().__init__(title="Pingulinux App Store")
        self.set_default_size(820, 600)
        try:
            self.set_icon_from_file(LOGO)
        except Exception:
            pass
        with open(CATALOG, encoding="utf-8") as f:
            self.apps = json.load(f)
        for a in self.apps:
            a["_src"] = pick_source(a)
        seen, uniq = set(), []
        for a in self.apps:
            keys = {a["name"].lower()}
            if a.get("apt"): keys.add("apt:" + a["apt"])
            if a.get("flatpak"): keys.add("fp:" + a["flatpak"])
            if a["_src"] and not (keys & seen):
                seen |= keys
                uniq.append(a)
        self.apps = uniq
        self.cats = ["Alle"] + sorted({a["category"] for a in self.apps})
        self.busy = False

        box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(box)

        head = Gtk.HeaderBar(show_close_button=True)
        head.set_title("Pingulinux App Store")
        head.set_subtitle("Ausgesuchte Programme für dich")
        self.search = Gtk.SearchEntry(placeholder_text="Suchen…")
        self.search.connect("search-changed", lambda *_: self.refresh())
        head.pack_end(self.search)
        self.set_titlebar(head)

        paned = Gtk.Box(spacing=0)
        box.pack_start(paned, True, True, 0)

        self.catlist = Gtk.ListBox()
        self.catlist.set_size_request(180, -1)
        for c in self.cats:
            row = Gtk.ListBoxRow()
            lab = Gtk.Label(label=c, xalign=0)
            lab.set_margin_top(10); lab.set_margin_bottom(10)
            lab.set_margin_start(14); lab.set_margin_end(14)
            row.add(lab)
            self.catlist.add(row)
        self.catlist.connect("row-selected", lambda *_: self.refresh())
        paned.pack_start(self.catlist, False, False, 0)
        paned.pack_start(Gtk.Separator(orientation=Gtk.Orientation.VERTICAL), False, False, 0)

        sw = Gtk.ScrolledWindow()
        self.applist = Gtk.ListBox(selection_mode=Gtk.SelectionMode.NONE)
        sw.add(self.applist)
        paned.pack_start(sw, True, True, 0)

        self.status = Gtk.Label(label="", xalign=0)
        self.status.set_margin_start(12); self.status.set_margin_bottom(6); self.status.set_margin_top(6)
        box.pack_start(self.status, False, False, 0)

        self.catlist.select_row(self.catlist.get_row_at_index(0))

    def refresh(self):
        for ch in self.applist.get_children():
            self.applist.remove(ch)
        row = self.catlist.get_selected_row()
        cat = self.cats[row.get_index()] if row else "Alle"
        q = self.search.get_text().strip().lower()
        for app in self.apps:
            if cat != "Alle" and app["category"] != cat:
                continue
            if q and q not in (app["name"] + " " + app["summary"]).lower():
                continue
            self.applist.add(self.make_row(app))
        self.applist.show_all()

    def make_row(self, app):
        r = Gtk.ListBoxRow()
        h = Gtk.Box(spacing=14)
        h.set_margin_top(10); h.set_margin_bottom(10)
        h.set_margin_start(14); h.set_margin_end(14)
        img = Gtk.Image.new_from_icon_name(app["icon"], Gtk.IconSize.DIALOG)
        h.pack_start(img, False, False, 0)
        v = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        n = Gtk.Label(xalign=0)
        n.set_markup("<b>%s</b>" % GLib.markup_escape_text(app["name"]))
        quelle = "Debian-Paket" if app["_src"] == "apt" else "Flatpak"
        if app.get("min_age", 0) >= 99:
            quelle += "  ·  nur für Erwachsene"
        elif app.get("min_age"):
            quelle += "  ·  ab %d Jahren" % app["min_age"]
        s = Gtk.Label(label="%s  ·  %s" % (app["summary"], quelle), xalign=0)
        v.pack_start(n, False, False, 0)
        v.pack_start(s, False, False, 0)
        h.pack_start(v, True, True, 0)
        btn = Gtk.Button()
        if is_installed(app, app["_src"]):
            btn.set_label("✓ Installiert")
            btn.set_sensitive(False)
        else:
            btn.set_label("Installieren")
            btn.connect("clicked", self.on_install, app, btn)
        h.pack_end(btn, False, False, 0)
        r.add(h)
        return r

    def on_install(self, _w, app, btn):
        if self.busy:
            return
        self.busy = True
        btn.set_sensitive(False)
        btn.set_label("Bitte warten…")
        self.status.set_text("%s wird installiert – ein Erwachsener muss das Passwort eingeben." % app["name"])
        threading.Thread(target=self.do_install, args=(app,), daemon=True).start()

    def do_install(self, app):
        if app["_src"] == "apt":
            cmd = ["pkexec", "sh", "-c",
                   "export DEBIAN_FRONTEND=noninteractive; apt-get update -qq; "
                   "apt-get install -y %s" % app["apt"]]
        else:
            cmd = ["pkexec", "sh", "-c",
                   "flatpak install -y --system flathub %s; rc=$?; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % app["flatpak"]]
        r = run(cmd)
        with open("/tmp/pingulinux-store.log", "a") as f:
            f.write("$ %s\n%s\n%s\n" % (" ".join(cmd), r.stdout[-3000:], r.stderr[-3000:]))
        GLib.idle_add(self.done, app, r.returncode)

    def done(self, app, rc):
        self.busy = False
        if rc == 0:
            self.status.set_text("✅ %s ist jetzt installiert." % app["name"])
        elif rc in (126, 127):
            self.status.set_text("Abgebrochen – es wurde nichts installiert.")
        else:
            self.status.set_text("⚠️ Installation fehlgeschlagen. Details: /tmp/pingulinux-store.log")
        self.refresh()
        return False


win = Store()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
