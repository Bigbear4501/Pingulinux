#!/usr/bin/env python3
"""Sperrt Programme je nach Alter fuer jedes Kinderkonto (per ACL).

Fuer jedes Konto in /var/lib/pingulinux/profiles wird ein Programm
gesperrt, wenn das Alter unter "min_age" liegt, und sonst freigegeben.
Laeuft als root (nach Profil-Anlegen, App-Installation, Paket-Updates).
"""
import json, os, shutil, subprocess

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


def main():
    ents = entries()
    for user, age in users():
        for cmd, min_age in ents.items():
            path = cmd if cmd.startswith("/") else shutil.which(cmd, path="/usr/bin:/usr/games:/usr/local/bin:/bin")
            if not path or not os.path.exists(path):
                continue
            real = os.path.realpath(path)
            if age < min_age:
                subprocess.run(["setfacl", "-m", "u:%s:---" % user, real], capture_output=True)
            else:
                subprocess.run(["setfacl", "-x", "u:%s" % user, real], capture_output=True)


main()
