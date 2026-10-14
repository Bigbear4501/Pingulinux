# Pingulinux OS 🐧

Ein kinderfreundliches Linux-System für Kinder von 2 bis 14 Jahren, basierend auf **Debian 13 („trixie")**.
Maskottchen ist **Pingu**, ein Pinguin mit grüner Kappe und Sonnenbrille.

> **Status: Alpha 2.** Pingulinux ist in früher Entwicklung. Bitte nicht auf dem einzigen Familien-Rechner installieren, sondern zuerst in einer virtuellen Maschine oder auf einem Zweitgerät ausprobieren.

## Was ist drin?

- **Oberfläche:** XFCE (Standard) mit großen, einfachen Symbolen. KDE Plasma ist als zweite, wählbare Sitzung im Login-Menü vorhanden (gedacht für Tablets und Touch).
- **Installer:** Calamares, auf Deutsch.
- **Eltern-Kontrollzentrum:** Bildschirmzeit (Timekpr-nExT), Firewall, Kinderschutz-Filter (DNS), Drucker und Scanner, Sicherung, Benutzerkonten, App Store, Update-Assistent, Systembereinigung, Hilfe und Fehlerdiagnose.
- **Altersprofile:** Beim Anlegen eines Kinderkontos gibst du das Alter an. Bildschirmzeit, erlaubte Programme und Sperren werden automatisch passend gesetzt. Die Kinderkonten haben keine Administrator-Rechte und kein Terminal.
- **Profilbilder** für jedes Konto.
- **Browser:** Firefox mit kinderfreundlicher Startseite (fragFINN) und Kindersuchmaschine (Kiddle). YouTube Kids ist als Web-App mit Eltern-Freigabe eingebunden.
- **Eigener, geprüfter App Store** („Pingulinux App Store"): Debian-Pakete haben Vorrang, Flatpak wird nur angeboten, wenn es kein Debian-Paket gibt.
- **Lernen und Spielen:** GCompris, Tux Paint, Tux Typing, Tux Math, Kalzium, KGeography, Stellarium, Marble, Krita, SuperTuxKart und mehr.
- **Büro:** LibreOffice, Thunderbird.
- **Hardware:** WLAN, Bluetooth und Sound getestet auf Surface Go 2 und MacBook Air. Bildschirmdrehung auf dem Surface Go 2 funktioniert.

## Download

> ⚠️ Die ISO ist rund 4 GB groß und liegt deshalb **nicht** in diesem Repository.

- **ISO-Download (Alpha 2):** [sourceforge.net/projects/pingulinux/files/Alpha2](https://sourceforge.net/projects/pingulinux/files/Alpha2/)
- **SHA256-Prüfsumme:** Datei `SHA256SUMS` im selben Ordner

Prüfsumme nach dem Download prüfen (ISO und `SHA256SUMS` im selben Ordner):

```bash
sha256sum -c SHA256SUMS
```

Erscheint `OK` hinter dem Dateinamen, ist die ISO vollständig und unverändert.

## Ausprobieren

1. ISO herunterladen und Prüfsumme prüfen.
2. In einer virtuellen Maschine (z. B. GNOME Boxes, VirtualBox) starten, oder mit einem Programm wie Balena Etcher auf einen USB-Stick schreiben.
3. Im Live-Modus ausprobieren. Dort braucht das Eltern-Kontrollzentrum kein Passwort.
4. Zum Installieren das Symbol „Pingulinux installieren" benutzen. Auf dem installierten System fragt das Eltern-Kontrollzentrum nach dem Administrator-Passwort.

## Bekannte Einschränkungen (Alpha 2)

- **Soziale Netzwerke und YouTube** sind über die Datei `/etc/hosts` gesperrt. Das gilt **systemweit**, also auch für die Eltern. Eine Sperre pro Konto ist für Alpha 3 geplant.
- **Tablet-Modus:** Nur in der KDE-Sitzung (Wayland) vorgesehen. Noch nicht vollständig getestet.
- **Kinderschutz-Filter (DNS):** Nutzt einen externen DNS-Dienst (CleanBrowsing). Dabei werden DNS-Anfragen an diesen Dienst gesendet. Wer das nicht möchte, kann den Filter im Kontrollzentrum ausschalten.
- **Calamares:** Ein kleiner schwarzer Kasten in der schmalen Seitenleiste des Installers ist ein bekannter, rein optischer Fehler.
- Die ISO ist noch groß (rund 4 GB). Eine schlankere Version ist für 1.0 geplant.

## Fehler melden

Bitte öffne ein [Issue](../../issues) und nenne dabei:

- Was hast du gemacht, und was ist passiert?
- Auf welchem Gerät (Modell, virtuelle Maschine oder echtes Gerät)?
- Die Ausgabe des Programms „Hilfe und Fehlerdiagnose" im Eltern-Kontrollzentrum (falls möglich).

## Aus den Quellen bauen

Pingulinux wird mit [live-build](https://wiki.debian.org/DebianLive) unter Debian 13 gebaut. Dieses Repository enthält die Konfiguration (`config/`) und das Bau-Skript (`rebuild.sh`).

```bash
sudo apt install live-build
git clone https://github.com/Bigbear4501/Pingulinux.git ~/kids-distro
cd ~/kids-distro
sudo lb clean
./rebuild.sh
```

Die fertige ISO liegt danach im Ordner `~/kids-distro`.

## Roadmap

- **Alpha 3:** Mehr Programme im App Store, YouTube-Sperre pro Konto, DNS4EU als Option, Plasma-Optik.
- **Beta 1 (Sicherheit und Stabilität):** Sicherheitsprüfung (Umgehungsversuche, Secure Boot, Dual-Boot), automatische Updates, Liste kompatibler Geräte, einfache Oberfläche für 2- bis 6-Jährige.
- **Beta 2 (Erweiterung und Praxis):** Eltern-Dashboard mit Nutzungsstatistik, App-Listen pro Kind, eigenes Paket-Repository, Plasma-Mobile-Tablet-Image, KDE Connect, Test mit echten Familien.
- **1.0:** Rechtliches (Impressum, Datenschutz, Lizenzen), Release-Prozess mit Signatur, Webseite und Dokumentation, englische Übersetzung, schlankere ISO.

## Lizenz

Die Konfiguration und die Skripte von Pingulinux stehen unter der **GNU General Public License v3.0** (siehe `LICENSE`). Enthaltene Programme stehen unter ihren jeweiligen Lizenzen. Die Firmware-Pakete (`non-free-firmware`) sind nicht frei im Sinne der Debian-Richtlinien.
