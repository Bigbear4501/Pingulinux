#!/usr/bin/env python3
"""pingulinux-media-access.py  (läuft als root, über systemd)

Kamera und Mikrofon erst ab 10 Jahren.

So funktioniert es:
  - Eine udev-Regel (72-pingulinux-media.rules) gibt Kameras (/dev/video*)
    und die Aufnahme-Seite der Soundkarten (/dev/snd/pcm…c) nur noch der
    Gruppe „pingumedia“ frei. Lautsprecher und Kopfhörer sind nicht betroffen,
    Ton hören geht für alle.
  - Dieses Skript legt fest, wer in der Gruppe ist: alle Erwachsenen-Konten
    und Kinder ab 10. Kinder unter 10 (oder ohne bekanntes Alter) nicht.
  - Läuft beim Start, täglich und sobald sich ein Alter ändert. Am
    10. Geburtstag kommt das Kind automatisch in die Gruppe (wirkt ab der
    nächsten Anmeldung).
"""
import datetime, grp, os, pwd, re, subprocess, sys

DATA = os.environ.get("PINGU_DATA", "/var/lib/pingulinux")
GROUP = "pingumedia"
MIN_AGE = 10
DRY = "--dry-run" in sys.argv


def today():
    t = os.environ.get("PINGU_TODAY")
    return datetime.date.fromisoformat(t) if t else datetime.date.today()


def age_from(text):
    s = text.strip()
    m = re.fullmatch(r"(\d{4})-(\d{1,2})(?:-(\d{1,2}))?", s)
    if m:
        y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3) or 1)
        t = today()
        return t.year - y - ((t.month, t.day) < (mo, d))
    if re.fullmatch(r"\d{1,3}", s):
        return int(s)
    return None


def read(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            return f.read()
    except OSError:
        return None


def kid_age(name):
    """Alter eines Kinderkontos, 0 wenn unbekannt; None wenn kein Kind."""
    b = read(os.path.join(DATA, "birth", name))
    p = read(os.path.join(DATA, "profiles", name))
    if b is None and p is None:
        return None
    age = age_from(b) if b else None
    if age is None and p:
        age = age_from(p)
    return age if age is not None else 0


def sh(cmd):
    if DRY:
        print("[dry-run] " + " ".join(cmd))
        return
    subprocess.run(cmd, check=False)


def main():
    try:
        members = set(grp.getgrnam(GROUP).gr_mem)
    except KeyError:
        if DRY:
            members = set()
        else:
            subprocess.run(["groupadd", "--system", GROUP], check=False)
            members = set()
    for pw in pwd.getpwall():
        if not (1000 <= pw.pw_uid < 60000):
            continue
        # nur echte Anmelde-Konten (Ordner unter /home, normale Shell)
        if not pw.pw_dir.startswith("/home/") or pw.pw_shell.endswith(("nologin", "false")):
            continue
        age = kid_age(pw.pw_name)
        allowed = age is None or age >= MIN_AGE
        label = "Erwachsen" if age is None else "%d Jahre" % age
        print("%-16s %-10s Kamera/Mikrofon: %s" % (pw.pw_name, label, "frei" if allowed else "gesperrt"))
        if allowed and pw.pw_name not in members:
            sh(["gpasswd", "-a", pw.pw_name, GROUP])
        elif not allowed and pw.pw_name in members:
            sh(["gpasswd", "-d", pw.pw_name, GROUP])


if __name__ == "__main__":
    main()
