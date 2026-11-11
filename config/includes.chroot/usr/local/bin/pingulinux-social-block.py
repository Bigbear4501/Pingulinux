#!/usr/bin/env python3
"""pingulinux-social-block.py  (läuft als root, über systemd)

Sperrt soziale Netzwerke für jedes Kinderkonto unter 13 Jahren.
Erwachsene und Kinder ab 13 sind nicht betroffen.

So funktioniert es:
  - Das Alter jedes Kontos wird aus /var/lib/pingulinux gelesen
    (birth/<konto> = Geburtsdatum hat Vorrang, sonst profiles/<konto> = Alter).
  - Ein kleiner eigener DNS-Dienst (dnsmasq auf 127.0.0.1:5399) beantwortet
    Anfragen für soziale Netzwerke mit "gibt es nicht" und leitet alles andere
    an den normalen DNS-Server weiter (also weiter an den Kinderschutz-Filter).
  - Eine Firewall-Regel (nftables) schickt nur die DNS-Anfragen der Kinder
    unter 13 an diesen Dienst. Verschlüsseltes DNS (DoT, Port 853) wird für
    diese Kinder blockiert, damit die Sperre nicht umgangen werden kann.
  - Läuft beim Start, stündlich und sobald sich ein Alter ändert. So fällt
    die Sperre am 13. Geburtstag automatisch weg.
"""
import datetime, os, pwd, re, subprocess, sys

DATA = os.environ.get("PINGU_DATA", "/var/lib/pingulinux")
RUN = os.environ.get("PINGU_RUN", "/run/pingulinux-social")
RESOLV = os.environ.get("PINGU_RESOLV", "/etc/resolv.conf")
MIN_AGE = 13
PORT = 5399   # nicht 5353, den nutzt Avahi
TABLE = "pingulinux_social"
DRY = "--dry-run" in sys.argv

DOMAINS = [
    "facebook.com", "fb.com", "fb.me", "messenger.com",
    "instagram.com", "cdninstagram.com",
    "tiktok.com", "tiktokv.com", "tiktokcdn.com", "tiktokcdn-eu.com", "musical.ly",
    "snapchat.com", "snap.com",
    "twitter.com", "x.com", "t.co", "twimg.com",
    "reddit.com", "redd.it", "redditmedia.com",
    "discord.com", "discord.gg", "discordapp.com", "discordapp.net",
    "threads.net", "threads.com",
    "pinterest.com", "pinterest.de",
    "tumblr.com", "bsky.app", "twitch.tv",
    "whatsapp.com", "web.whatsapp.com", "telegram.org", "web.telegram.org",
]


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


def kids_under_13():
    uids = []
    names = set()
    for sub in ("birth", "profiles"):
        d = os.path.join(DATA, sub)
        if os.path.isdir(d):
            names |= set(os.listdir(d))
    for name in sorted(names):
        try:
            uid = pwd.getpwnam(name).pw_uid
        except KeyError:
            continue                       # Konto gibt es nicht mehr
        age = None
        b = read(os.path.join(DATA, "birth", name))
        if b:
            age = age_from(b)
        if age is None:
            p = read(os.path.join(DATA, "profiles", name))
            if p:
                age = age_from(p)
        if age is None:
            print("Kein Alter für %s gefunden, vorsichtshalber gesperrt." % name)
            age = 0
        state = "gesperrt" if age < MIN_AGE else "frei"
        print("%-16s %3s Jahre  Social Media: %s" % (name, age, state))
        if age < MIN_AGE:
            uids.append(uid)
    return uids


def upstreams():
    servers = []
    for line in (read(RESOLV) or "").splitlines():
        m = re.match(r"\s*nameserver\s+(\S+)", line)
        if m:
            servers.append(m.group(1))
    return servers or ["185.228.168.168"]   # Rückfall: CleanBrowsing Family


def dnsmasq_conf():
    lines = [
        "# Erzeugt von pingulinux-social-block.py - nicht von Hand ändern",
        "port=%d" % PORT,
        "listen-address=127.0.0.1",
        "listen-address=::1",
        "bind-interfaces",
        "no-resolv",
        "cache-size=1000",
        "domain-needed",
        "pid-file=%s/dnsmasq.pid" % RUN,
        "user=nobody",
        "group=nogroup",
    ]
    lines += ["server=%s" % s for s in upstreams()]
    for d in DOMAINS:
        lines.append("address=/%s/0.0.0.0" % d)
        lines.append("address=/%s/::" % d)
    return "\n".join(lines) + "\n"


def nft_ruleset(uids):
    elems = ", ".join(str(u) for u in uids)
    return """table inet %(t)s {
    set kids {
        typeof meta skuid
        elements = { %(e)s }
    }
    chain dns_redirect {
        type nat hook output priority -100; policy accept;
        meta skuid @kids meta l4proto { tcp, udp } th dport 53 redirect to :%(p)d
    }
    chain block_dot {
        type filter hook output priority 0; policy accept;
        meta skuid @kids tcp dport 853 reject
    }
}
""" % {"t": TABLE, "e": elems, "p": PORT}


def sh(cmd, input_text=None, quiet=False):
    if DRY:
        print("[dry-run] " + " ".join(cmd))
        return 0
    err = subprocess.DEVNULL if quiet else None
    return subprocess.run(cmd, input=input_text, text=True, stderr=err).returncode


def main():
    uids = kids_under_13()
    sh(["nft", "delete", "table", "inet", TABLE], quiet=True)   # alte Regeln weg
    if not uids:
        print("Kein Kind unter 13: keine Social-Media-Sperre aktiv.")
        sh(["systemctl", "stop", "pingulinux-social-dns.service"])
        return 0
    os.makedirs(RUN, exist_ok=True)
    conf = dnsmasq_conf()
    if DRY:
        print(conf)
        print(nft_ruleset(uids))
    else:
        with open(os.path.join(RUN, "dnsmasq.conf"), "w") as f:
            f.write(conf)
    sh(["systemctl", "restart", "pingulinux-social-dns.service"])
    rc = sh(["nft", "-f", "-"], nft_ruleset(uids))
    if rc != 0:
        print("Firewall-Regel konnte nicht gesetzt werden.", file=sys.stderr)
        return 1
    print("Social-Media-Sperre aktiv für %d Konto/Konten." % len(uids))
    return 0


if __name__ == "__main__":
    sys.exit(main())
