#!/usr/bin/env python3
"""pingulinux-show-profiles.py - Übersicht aller Kinderkonten.

Zeigt für jedes Kinderkonto (Konto ohne Administrator-Rechte):
Alter, Geburtsdatum (falls gespeichert) und die Bildschirmzeit
(Montag bis Freitag, Wochenende, erlaubte Uhrzeiten).

Aufruf:
  pingulinux-show-profiles.py          Fenster (zenity), sonst Tabelle im Terminal
  pingulinux-show-profiles.py --text   immer als Tabelle im Terminal
  pingulinux-show-profiles.py --debug  zusätzlich anzeigen, wo was gefunden wurde

Braucht Administrator-Rechte (startet sich sonst selbst über pkexec neu),
weil Alter und Bildschirmzeit nur für root lesbar sind.

Wo das Alter gespeichert ist, wird gesucht (PINGU_DATA_DIRS, Standard:
/var/lib/pingulinux und /etc/pingulinux). Verstanden werden:
  - Datei pro Konto (Name = Benutzername), Inhalt: Alter ("8"),
    Geburtsdatum ("2017-05", "2017-05-14", "05/2017", "05.2017")
    oder Zeilen wie "BIRTH=2017-05" / "ALTER=8"
  - JSON-Dateien, die den Benutzernamen als Schlüssel enthalten
"""
import datetime, grp, json, os, pwd, re, shutil, subprocess, sys

DATA_DIRS = os.environ.get("PINGU_DATA_DIRS", "/var/lib/pingulinux:/etc/pingulinux").split(":")
TIMEKPR_DIR = os.environ.get("PINGU_TIMEKPR_DIR", "/var/lib/timekpr/config")
DEBUG = "--debug" in sys.argv
TEXT = "--text" in sys.argv
TODAY = datetime.date.today()
DAYS = ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]


def log(*a):
    if DEBUG:
        print("[debug]", *a, file=sys.stderr)


# --- Konten -------------------------------------------------------------------
def admin_names():
    names = set()
    for g in ("sudo", "admin", "wheel"):
        try:
            names |= set(grp.getgrnam(g).gr_mem)
        except KeyError:
            pass
    return names


def child_accounts():
    admins = admin_names()
    kids = []
    for p in pwd.getpwall():
        if p.pw_uid < 1000 or p.pw_uid >= 60000:
            continue
        if p.pw_shell.endswith(("nologin", "false")):
            continue
        if p.pw_name in admins:
            continue
        kids.append(p.pw_name)
    return sorted(kids)


# --- Alter / Geburtsdatum -----------------------------------------------------
def age_from_birth(year, month, day=1):
    try:
        b = datetime.date(year, month, day)
    except ValueError:
        return None
    if b > TODAY:
        return None
    return TODAY.year - b.year - ((TODAY.month, TODAY.day) < (b.month, b.day))


def parse_value(v):
    """Gibt (alter, geburt_text) zurück, oder (None, None)."""
    if v is None:
        return None, None
    if isinstance(v, (int, float)) and 0 <= v < 120:
        return int(v), None
    if isinstance(v, dict):
        for k in ("birth", "geburt", "geburtsdatum", "birthdate", "born", "age", "alter"):
            for key in v:
                if key.lower().startswith(k):
                    a, b = parse_value(v[key])
                    if a is not None:
                        return a, b
        return None, None
    s = str(v).strip()
    if re.fullmatch(r"\d{1,3}", s):
        n = int(s)
        return (n, None) if n < 120 else (None, None)
    m = re.fullmatch(r"(\d{4})-(\d{1,2})(?:-(\d{1,2}))?", s)
    if m:
        y, mo, d = int(m.group(1)), int(m.group(2)), int(m.group(3) or 1)
        return age_from_birth(y, mo, d), s
    m = re.fullmatch(r"(?:(\d{1,2})[./])?(\d{1,2})[./](\d{4})", s)
    if m:
        d, mo, y = int(m.group(1) or 1), int(m.group(2)), int(m.group(3))
        return age_from_birth(y, mo, d), s
    return None, None


def parse_text(text):
    text = text.strip()
    a, b = parse_value(text)
    if a is not None:
        return a, b
    found_age, found_birth = None, None
    for line in text.splitlines():
        m = re.match(r"\s*([A-Za-z_äöüÄÖÜ]+)\s*[:=]\s*\"?([^\"#]+)\"?", line)
        if not m:
            continue
        key, val = m.group(1).lower(), m.group(2).strip()
        if key.startswith(("birth", "geburt", "born")):
            a, b = parse_value(val)
            if a is not None:
                found_age, found_birth = a, b
        elif key.startswith(("age", "alter")) and found_age is None:
            a, _ = parse_value(val)
            found_age = a
    return found_age, found_birth


def find_age(user, files):
    # 1. Datei, die genau so heißt wie das Konto (oder konto.irgendwas).
    #    Ein gespeichertes Geburtsdatum hat Vorrang vor einem festen Alter,
    #    weil daraus das aktuelle Alter berechnet wird.
    best = None
    for f in files:
        base = os.path.basename(f)
        if base == user or base.split(".")[0] == user:
            try:
                a, b = parse_text(open(f, encoding="utf-8", errors="replace").read())
            except OSError:
                continue
            log(user, "->", f, "->", a, b)
            if a is None:
                continue
            if b:
                return a, b, f
            if best is None:
                best = (a, b, f)
    if best:
        return best
    # 2. JSON-Dateien mit dem Konto als Schlüssel
    for f in files:
        if not f.endswith(".json"):
            continue
        try:
            data = json.load(open(f, encoding="utf-8"))
        except (OSError, ValueError):
            continue
        if isinstance(data, dict) and user in data:
            a, b = parse_value(data[user])
            log(user, "->", f, "(JSON) ->", a, b)
            if a is not None:
                return a, b, f
    return None, None, None


def all_data_files():
    out = []
    for d in DATA_DIRS:
        for root, _dirs, names in os.walk(d):
            for n in names:
                p = os.path.join(root, n)
                try:
                    if os.path.getsize(p) <= 65536:
                        out.append(p)
                except OSError:
                    pass
    log("durchsuchte Dateien:", len(out))
    return out


# --- Bildschirmzeit (Timekpr-nExT) ----------------------------------------------
def timekpr_info(user):
    text = ""
    if shutil.which("timekpra"):
        r = subprocess.run(["timekpra", "--userinfo", user], capture_output=True, text=True)
        if r.returncode == 0:
            text = r.stdout
    conf = os.path.join(TIMEKPR_DIR, "timekpr.%s.conf" % user)
    if not text and os.path.exists(conf):
        text = open(conf, encoding="utf-8", errors="replace").read()
    info = {}
    for line in text.splitlines():
        m = re.match(r"\s*([A-Z_0-9]+)\s*[:=]\s*(.*)$", line)
        if m:
            info[m.group(1)] = m.group(2).strip()
    return info


def fmt_minutes(sec):
    try:
        m = int(sec) // 60
    except ValueError:
        return "?"
    if m >= 24 * 60:
        return "unbegrenzt"
    return "%d Min." % m


def screen_time(info):
    lim = [x for x in info.get("LIMITS_PER_WEEKDAYS", "").split(";") if x.strip()]
    if len(lim) >= 7:
        wd = sorted(set(fmt_minutes(x) for x in lim[:5]))
        we = sorted(set(fmt_minutes(x) for x in lim[5:7]))
        wd_s = wd[0] if len(wd) == 1 else "unterschiedlich"
        we_s = we[0] if len(we) == 1 else "unterschiedlich"
    else:
        wd_s = we_s = "–"
    hours = info.get("ALLOWED_HOURS_1", "")
    hs = []
    for h in hours.split(";"):
        m = re.match(r"\s*(\d+)", h)
        if m:
            hs.append(int(m.group(1)))
    hours_s = "%d – %d Uhr" % (min(hs), max(hs) + 1) if hs else "–"
    return wd_s, we_s, hours_s


# --- Ausgabe -------------------------------------------------------------------
def as_session_user(cmd):
    """Fenster als der angemeldete Erwachsene zeigen, nicht als root.

    Die Daten liest das Skript als root. Ein Fenster, das root öffnet,
    kommt aber vor allem unter KDE/Wayland nicht sauber auf den
    Bildschirm (fehlende Rechte am Bildschirm der Sitzung). Deshalb wird
    zenity unter dem Konto gestartet, das das Skript aufgerufen hat.
    """
    if os.geteuid() != 0:
        return cmd
    uid = os.environ.get("PKEXEC_UID") or os.environ.get("SUDO_UID")
    if not uid or uid == "0" or not shutil.which("runuser"):
        return cmd
    try:
        import pwd
        pw = pwd.getpwuid(int(uid))
    except (KeyError, ValueError):
        return cmd
    env = ["env", "HOME=" + pw.pw_dir,
           "XDG_RUNTIME_DIR=" + (os.environ.get("XDG_RUNTIME_DIR") or "/run/user/%s" % uid)]
    for k in ("DISPLAY", "XAUTHORITY", "WAYLAND_DISPLAY"):
        if os.environ.get(k):
            env.append("%s=%s" % (k, os.environ[k]))
    return ["runuser", "-u", pw.pw_name, "--"] + env + cmd


def main():
    if os.geteuid() != 0 and "PINGU_NO_ROOT" not in os.environ:
        if shutil.which("pkexec"):
            env_args = ["env", "DISPLAY=" + os.environ.get("DISPLAY", ""),
                        "XAUTHORITY=" + os.environ.get("XAUTHORITY", ""),
                        "WAYLAND_DISPLAY=" + os.environ.get("WAYLAND_DISPLAY", ""),
                        "XDG_RUNTIME_DIR=" + os.environ.get("XDG_RUNTIME_DIR", "")]
            os.execvp("pkexec", ["pkexec"] + env_args + [sys.executable, os.path.abspath(__file__)] + sys.argv[1:])
        print("Bitte als Administrator starten: sudo %s" % sys.argv[0], file=sys.stderr)
        sys.exit(1)

    files = all_data_files()
    rows = []
    for user in child_accounts():
        age, birth, src = find_age(user, files)
        wd, we, hrs = screen_time(timekpr_info(user))
        rows.append([user,
                     "%d Jahre" % age if age is not None else "nicht gefunden",
                     birth or "–", wd, we, hrs])

    head = ["Konto", "Alter", "Geburtsdatum", "Mo – Fr", "Sa – So", "Erlaubt"]
    gui = not TEXT and shutil.which("zenity") and (os.environ.get("DISPLAY") or os.environ.get("WAYLAND_DISPLAY"))

    if not rows:
        msg = "Es gibt noch keine Kinderkonten."
        if gui:
            subprocess.run(as_session_user(["zenity", "--info", "--title=Kinderkonten", "--text=" + msg, "--width=360"]))
        else:
            print(msg)
        return

    if gui:
        cmd = ["zenity", "--list", "--title=Kinderkonten", "--text=Alter und Bildschirmzeit der Kinderkonten",
               "--width=760", "--height=360"]
        for h in head:
            cmd += ["--column=" + h]
        cmd += ["--ok-label=Schließen", "--cancel-label=Zurück"]
        for r in rows:
            cmd += r
        subprocess.run(as_session_user(cmd))
    else:
        widths = [max(len(str(x)) for x in col) for col in zip(head, *rows)]
        line = lambda r: "  ".join(str(x).ljust(w) for x, w in zip(r, widths))
        print(line(head))
        print("  ".join("-" * w for w in widths))
        for r in rows:
            print(line(r))
        if any(r[1] == "nicht gefunden" for r in rows):
            print("\nHinweis: Für manche Konten wurde kein Alter gefunden. Mit --debug sieht man, welche Dateien durchsucht wurden.")


if __name__ == "__main__":
    main()
