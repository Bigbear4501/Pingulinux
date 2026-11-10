#!/usr/bin/env python3
"""Sperrt Programme je nach Alter fuer jedes Kinderkonto (per ACL).

Fuer jedes Konto in /var/lib/pingulinux/profiles wird ein Programm
gesperrt, wenn das Alter unter "min_age" liegt, und sonst freigegeben.
Gesperrte Programme werden zusaetzlich im Startmenue des Kontos ausgeblendet
(Datei ~/.local/share/applications/NAME.desktop mit NoDisplay=true).
Laeuft als root (nach Profil-Anlegen, App-Installation, Paket-Updates).
"""
import glob, json, os, pwd, re, shlex, shutil, subprocess

PROFDIR = "/var/lib/pingulinux/profiles"
SOURCES = ["/usr/share/pingulinux/app-ages.json", "/usr/share/pingulinux/store-apps.json"]


def users():
    if not os.path.isdir(PROFDIR):
        return
    for name in os.listdir(PROFDIR):
        try:
            age = int(open(os.path.join(PROFDIR, name)).read().strip())
        except Exception:
            continue
        if subprocess.run(["id", name], capture_output=True).returncode == 0:
            yield name, age


def entries():
    seen = {}
    for src in SOURCES:
        try:
            for e in json.load(open(src, encoding="utf-8")):
                if e.get("cmd") and "min_age" in e:
                    seen[e["cmd"]] = e["min_age"]
        except Exception:
            pass
    return seen


APPDIR = "/usr/share/applications"
MARK = "X-Pingulinux-Hidden=true"


def desktop_files_for(real):
    """Menue-Eintraege (Dateinamen), deren Programm 'real' ist."""
    found = []
    for df in glob.glob(os.path.join(APPDIR, "*.desktop")):
        try:
            text = open(df, encoding="utf-8", errors="replace").read()
        except Exception:
            continue
        m = re.search(r"^Exec=(.*)$", text, re.M)
        if not m:
            continue
        try:
            parts = shlex.split(m.group(1))
        except ValueError:
            continue
        while parts and (parts[0] == "env" or "=" in parts[0]):
            parts.pop(0)
        if not parts:
            continue
        exe = parts[0]
        exe = exe if exe.startswith("/") else shutil.which(exe, path="/usr/bin:/usr/games:/usr/local/bin:/bin")
        if exe and os.path.realpath(exe) == real:
            n = re.search(r"^Name=(.*)$", text, re.M)
            found.append((os.path.basename(df), n.group(1) if n else os.path.basename(df)))
    return found


def set_hidden(user, fname, name, hide):
    try:
        pw = pwd.getpwnam(user)
    except KeyError:
        return
    d = os.path.join(pw.pw_dir, ".local/share/applications")
    f = os.path.join(d, fname)
    if hide:
        if os.path.exists(f) and MARK not in open(f, errors="replace").read():
            return  # eigene Datei des Nutzers nicht anfassen
        os.makedirs(d, exist_ok=True)
        with open(f, "w", encoding="utf-8") as fh:
            fh.write("[Desktop Entry]\nType=Application\nName=%s\nNoDisplay=true\nHidden=true\n%s\n" % (name, MARK))
        for path in (os.path.join(pw.pw_dir, ".local"), os.path.join(pw.pw_dir, ".local/share"), d, f):
            try:
                os.chown(path, pw.pw_uid, pw.pw_gid)
            except OSError:
                pass
    elif os.path.exists(f) and MARK in open(f, errors="replace").read():
        os.remove(f)


def flatpak_entries():
    """Flatpak-Programme: Kennung -> Mindestalter."""
    out = {}
    try:
        for e in json.load(open("/usr/share/pingulinux/store-apps.json", encoding="utf-8")):
            if e.get("flatpak") and "min_age" in e:
                out[e["flatpak"]] = e["min_age"]
    except Exception:
        pass
    return out


FP_APPS = "/var/lib/flatpak/app"
FP_DESKTOP = "/var/lib/flatpak/exports/share/applications"


def main():
    ents = entries()
    fps = flatpak_entries()
    for user, age in users():
        # Terminal (Konsole) ist fuer Kinderkonten immer gesperrt
        for term in ("/usr/bin/konsole",):
            if os.path.exists(term):
                subprocess.run(["setfacl", "-m", "u:%s:---" % user, os.path.realpath(term)], capture_output=True)
        for cmd, min_age in ents.items():
            path = cmd if cmd.startswith("/") else shutil.which(cmd, path="/usr/bin:/usr/games:/usr/local/bin:/bin")
            if not path or not os.path.exists(path):
                continue
            real = os.path.realpath(path)
            locked = age < min_age
            if locked:
                subprocess.run(["setfacl", "-m", "u:%s:---" % user, real], capture_output=True)
            else:
                subprocess.run(["setfacl", "-x", "u:%s" % user, real], capture_output=True)
            for fname, name in desktop_files_for(real):
                set_hidden(user, fname, name, locked)
        # Flatpak-Programme: Programmordner sperren (verhindert das Starten)
        # und Menueeintrag ausblenden
        for ref, min_age in fps.items():
            appdir = os.path.join(FP_APPS, ref)
            if not os.path.isdir(appdir):
                continue
            locked = age < min_age
            if locked:
                subprocess.run(["setfacl", "-m", "u:%s:---" % user, appdir], capture_output=True)
            else:
                subprocess.run(["setfacl", "-x", "u:%s" % user, appdir], capture_output=True)
            set_hidden(user, ref + ".desktop", ref, locked)


main()
