#!/usr/bin/env python3
"""Pingulinux App Store – ALTE GTK-Fassung (nur Ersatz, falls PyQt6 fehlt).

Installation: bevorzugt als Debian-Paket (apt); nur wenn es kein
Debian-Paket gibt, wird die Flatpak-Version von Flathub genutzt.
Installieren und Entfernen braucht das Passwort eines Administrators (pkexec).
"""
import json, shlex, subprocess, threading
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GLib

CATALOG = "/usr/share/pingulinux/store-apps.json"


def is_live():
    """Im Live-Modus lassen sich Flatpaks nicht installieren (zu wenig Platz im RAM)."""
    try:
        return "boot=live" in open("/proc/cmdline").read()
    except OSError:
        return False


LIVE = is_live()
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


def apt_removal_set(pkg):
    """Simuliert 'apt-get remove' (ohne root) und liefert die Pakete,
    die dabei mit entfernt wuerden."""
    r = run(["apt-get", "-s", "remove", pkg])
    if r.returncode != 0:
        return None
    names = []
    for line in r.stdout.splitlines():
        if line.startswith("Remv "):
            names.append(line.split()[1])
    return names


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

    def pick_icon(self, app):
        """Programm-Symbol, sonst ein passendes Kategorie-Symbol (statt Fehler-Bild)."""
        theme = Gtk.IconTheme.get_default()
        for name in (app["icon"], app["icon"].split(".")[-1].lower()):
            if theme.has_icon(name):
                return name
        fallback = {"Internet": "applications-internet", "Spiele": "applications-games",
                    "Grafik": "applications-graphics", "Multimedia": "applications-multimedia",
                    "Büro": "applications-office", "Bildung": "applications-science",
                    "Programmieren": "applications-development",
                    "Dienstprogramme": "applications-utilities"}
        for name in (fallback.get(app["category"], "applications-other"), "application-x-executable"):
            if theme.has_icon(name):
                return name
        return "application-x-executable"

    def make_row(self, app):
        r = Gtk.ListBoxRow()
        h = Gtk.Box(spacing=14)
        h.set_margin_top(10); h.set_margin_bottom(10)
        h.set_margin_start(14); h.set_margin_end(14)
        img = Gtk.Image.new_from_icon_name(self.pick_icon(app), Gtk.IconSize.DIALOG)
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
        if is_installed(app, app["_src"]):
            rm = Gtk.Button(label="Entfernen")
            rm.connect("clicked", self.on_remove, app, rm)
            h.pack_end(rm, False, False, 0)
            ok = Gtk.Label(label="✓ Installiert")
            h.pack_end(ok, False, False, 0)
        elif LIVE and app["_src"] == "flatpak":
            btn = Gtk.Button(label="Nach der Installation verfügbar")
            btn.set_sensitive(False)
            btn.set_tooltip_text("Dieses Programm kommt als Flatpak. Flatpaks lassen sich erst "
                                 "installieren, wenn Pingulinux fest auf dem Computer installiert ist.")
            h.pack_end(btn, False, False, 0)
        else:
            btn = Gtk.Button(label="Installieren")
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
                   "apt-get install -y %s" % shlex.quote(app["apt"])]
        else:
            cmd = ["pkexec", "sh", "-c",
                   "flatpak install -y --system flathub %s; rc=$?; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % shlex.quote(app["flatpak"])]
        self.run_logged(cmd, app, "install")

    def ask(self, text, secondary, question=True):
        d = Gtk.MessageDialog(transient_for=self, modal=True,
                              message_type=Gtk.MessageType.QUESTION if question else Gtk.MessageType.INFO,
                              buttons=Gtk.ButtonsType.NONE, text=text)
        d.format_secondary_text(secondary)
        if question:
            d.add_button("Abbrechen", Gtk.ResponseType.CANCEL)
            d.add_button("Entfernen", Gtk.ResponseType.OK)
        else:
            d.add_button("OK", Gtk.ResponseType.OK)
        resp = d.run()
        d.destroy()
        return resp == Gtk.ResponseType.OK

    def on_remove(self, _w, app, btn):
        if self.busy:
            return
        if app["_src"] == "apt":
            would = apt_removal_set(app["apt"])
            if would is None or app["apt"] not in [p.split(":")[0] for p in would]:
                self.ask("%s kann nicht entfernt werden" % app["name"],
                         "Das Programm gehört zum Grundsystem von Pingulinux.",
                         question=False)
                return
            others = [p for p in would if p.split(":")[0] != app["apt"]]
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
        btn.set_sensitive(False)
        btn.set_label("Bitte warten…")
        self.status.set_text("%s wird entfernt – ein Erwachsener muss das Passwort eingeben." % app["name"])
        threading.Thread(target=self.do_remove, args=(app,), daemon=True).start()

    def do_remove(self, app):
        if app["_src"] == "apt":
            cmd = ["pkexec", "sh", "-c",
                   "export DEBIAN_FRONTEND=noninteractive; "
                   "apt-get remove -y --no-auto-remove %s; rc=$?; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % shlex.quote(app["apt"])]
        else:
            cmd = ["pkexec", "sh", "-c",
                   "flatpak uninstall -y --system %s; rc=$?; "
                   "[ $rc -eq 0 ] && flatpak uninstall -y --system --unused; "
                   "/usr/local/bin/pingulinux-apply-all-ages.py; exit $rc" % shlex.quote(app["flatpak"])]
        self.run_logged(cmd, app, "remove")

    def run_logged(self, cmd, app, action):
        r = run(cmd)
        with open("/tmp/pingulinux-store.log", "a") as f:
            f.write("$ %s\n%s\n%s\n" % (" ".join(cmd), r.stdout[-3000:], r.stderr[-3000:]))
        GLib.idle_add(self.done, app, r.returncode, action)

    def done(self, app, rc, action="install"):
        self.busy = False
        if rc == 0:
            if action == "remove":
                self.status.set_text("✅ %s wurde entfernt." % app["name"])
            else:
                self.status.set_text("✅ %s ist jetzt installiert." % app["name"])
        elif rc in (126, 127):
            self.status.set_text("Abgebrochen – es wurde nichts geändert.")
        elif action == "remove":
            self.status.set_text("⚠️ Entfernen fehlgeschlagen. Details: /tmp/pingulinux-store.log")
        else:
            self.status.set_text("⚠️ Installation fehlgeschlagen. Details: /tmp/pingulinux-store.log")
        self.refresh()
        return False


win = Store()
win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
