#!/usr/bin/env python3
"""Profilbild-Auswahl: Galerie mit Bildern aus Debian/Plasma plus eigenes Bild.
Gibt den gewaehlten Dateipfad aus (leer = Abbruch)."""
import glob, os, sys
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, GdkPixbuf

NAME = sys.argv[1] if len(sys.argv) > 1 else ""
DIRS = ["/usr/share/pingulinux/avatars", "/usr/share/plasma/avatars",
        "/usr/share/pixmaps/faces", "/usr/share/pixmaps/avatars",
        "/usr/share/gnome-control-center/pixmaps"]
EXT = ("png", "jpg", "jpeg", "svg", "webp")

def collect():
    seen, out = set(), []
    for d in DIRS:
        for root, _, files in os.walk(d):
            for f in sorted(files):
                if f.lower().endswith(EXT):
                    p = os.path.join(root, f)
                    if p not in seen:
                        seen.add(p); out.append(p)
    pingu = "/usr/share/pingulinux/icons/pingu.png"
    if os.path.exists(pingu) and pingu not in out:
        out.insert(0, pingu)
    return out

store = Gtk.ListStore(GdkPixbuf.Pixbuf, str, str)
for p in collect():
    try:
        pb = GdkPixbuf.Pixbuf.new_from_file_at_size(p, 96, 96)
    except Exception:
        continue
    label = os.path.splitext(os.path.basename(p))[0].replace("_", " ")
    store.append([pb, label, p])

dlg = Gtk.Dialog(title="Profilbild" + (" für " + NAME if NAME else ""))
dlg.set_default_size(620, 460)
try:
    dlg.set_icon_from_file("/usr/share/pingulinux/icons/pingu.png")
except Exception:
    pass
dlg.add_button("Eigenes Bild…", 1)
dlg.add_button("Abbrechen", Gtk.ResponseType.CANCEL)
dlg.add_button("Auswählen", Gtk.ResponseType.OK)
dlg.set_default_response(Gtk.ResponseType.OK)

iv = Gtk.IconView.new_with_model(store)
iv.set_pixbuf_column(0); iv.set_text_column(1); iv.set_item_width(110)
iv.set_selection_mode(Gtk.SelectionMode.SINGLE)
iv.connect("item-activated", lambda *a: dlg.response(Gtk.ResponseType.OK))
sw = Gtk.ScrolledWindow(); sw.add(iv); sw.set_vexpand(True)
box = dlg.get_content_area()
box.pack_start(Gtk.Label(label="Wähle ein Bild aus:"), False, False, 8)
box.pack_start(sw, True, True, 0)
dlg.show_all()

result = ""
while True:
    r = dlg.run()
    if r == Gtk.ResponseType.OK:
        sel = iv.get_selected_items()
        if sel:
            result = store[sel[0]][2]; break
        continue
    if r == 1:
        fc = Gtk.FileChooserDialog(title="Eigenes Bild wählen", parent=dlg,
                                   action=Gtk.FileChooserAction.OPEN)
        fc.add_buttons("Abbrechen", Gtk.ResponseType.CANCEL, "Öffnen", Gtk.ResponseType.OK)
        flt = Gtk.FileFilter(); flt.set_name("Bilder")
        for e in EXT + ("bmp", "gif"):
            flt.add_pattern("*." + e)
        fc.add_filter(flt)
        if fc.run() == Gtk.ResponseType.OK:
            result = fc.get_filename(); fc.destroy(); break
        fc.destroy(); continue
    break
dlg.destroy()
print(result)
