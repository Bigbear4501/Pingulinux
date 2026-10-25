# Pingulinux OS 🐧

Ein kinderfreundliches Linux-System für Kinder von 2 bis 14 Jahren, basierend auf **Debian 13 („trixie")**.
Maskottchen ist **Pingu**, ein Pinguin mit grüner Kappe und Sonnenbrille.

> **Status: Alpha 3.** Pingulinux ist in früher Entwicklung. Bitte nicht auf dem einzigen Familien-Rechner installieren, sondern zuerst in einer virtuellen Maschine oder auf einem Zweitgerät ausprobieren.
>
> **„Pingulinux“ ist ein Arbeitstitel.** Vor Version 1.0 wird der Name noch einmal geprüft und kann sich ändern. Das Projekt selbst, die Funktionen und dieses Repository bleiben dabei bestehen.

## Was ist drin?

- **Oberfläche:** XFCE und KDE Plasma, beide im Login-Menü wählbar. KDE ist im Pingulinux-Look eingerichtet (Pingu im Startmenü, Eigener Ordner und Papierkorb auf dem Schreibtisch) und eignet sich auch für Tablets und Touch. Ab Beta 1 wird Pingulinux nur noch KDE verwenden.
- **Installer:** Calamares, auf Deutsch.
- **Eltern-Kontrollzentrum** mit großen Kacheln: Bildschirmzeit (Timekpr-nExT), Firewall, Kinderschutz-Filter (DNS), Drucker und Scanner, Sicherung und Wiederherstellung (Timeshift), Benutzerkonten, Konten-Übersicht, App Store, Update-Assistent, Systembereinigung, Hilfe und Fehlerdiagnose. Alles, was Administrator-Rechte braucht, fragt in einem Fenster nach dem Passwort eines Erwachsenen.
- **Alter wächst mit:** Beim Anlegen eines Kinderkontos gibst du Geburtsmonat und -jahr an. Bildschirmzeit, erlaubte Programme und Sperren passen sich automatisch an, wenn das Kind älter wird. Programme über der Altersgrenze werden im Menü ausgeblendet.
- **Konten-Übersicht:** Alle Kinderkonten mit Alter und Bildschirmzeit auf einen Blick.
- **Sperren pro Konto:** YouTube und soziale Netzwerke sind für Kinder unter 13 Jahren gesperrt, auch im privaten Fenster. Ab 13 und für Eltern sind sie frei.
- **Kinderschutz-Filter (DNS):** Wahlweise CleanBrowsing Family oder DNS4EU (Kinderschutz). Kinder können den DNS-Server nicht selbst ändern.
- **Browser:** Firefox mit kinderfreundlicher Startseite (fragFINN) und Kindersuchmaschine (Kiddle). `about:config` ist gesperrt.
- **YouTube Kids** im eigenen, abgeschotteten Fenster: kein Browser, keine Adressleiste, nur YouTube Kids. Kinder brauchen zum Starten die Freigabe eines Erwachsenen (Passwort). Mit Knopf für Vollbild und „Vollbild beenden“.
- **Eigener, geprüfter App Store** („Pingulinux App Store"): Debian-Pakete haben Vorrang, Flatpak wird nur angeboten, wenn es kein Debian-Paket gibt. Programme lassen sich auch wieder entfernen.
- **Lernen und Spielen:** GCompris, Tux Paint, Tux Typing (auf Deutsch), Tux Math, Kalzium, KGeography, Stellarium, Marble, Krita, SuperTuxKart und mehr. In KDE zusätzlich Gwenview, KWrite, Okular, Spectacle, Ark und KCalc.
- **Büro:** LibreOffice, Thunderbird.
- **Update-Assistent** für normale Updates und für den Wechsel auf eine neue Debian-Version (mit Sicherung per Timeshift). Dazu eine Systembereinigung.
- **Tablets:** Bildschirmdrehung, Touch und Bildschirmtastatur in KDE (nur Deutsch).
- **Firmware** für gängige WLAN-Chips ist dabei, auch für ältere MacBooks (Broadcom).

## Neu in Alpha 3

- Kontrollzentrum als Kacheln, mit Passwort-Fenster für Bildschirmzeit, Firewall und Sicherung
- Neue Kachel „Konten-Übersicht“ (Alter und Bildschirmzeit aller Kinder)
- Alter wächst mit (Geburtsmonat und -jahr statt festem Alter)
- YouTube- und Social-Media-Sperre pro Konto, nach Alter (unter 13 gesperrt)
- YouTube Kids im eigenen Fenster statt in Firefox (weiter mit Eltern-Freigabe)
- `about:config` in Firefox gesperrt
- DNS4EU als Alternative zu CleanBrowsing
- App Store: mehr Programme, Entfernen-Knopf, im Live-Modus Hinweis „Nach der Installation verfügbar“ bei Flatpaks
- KDE im Pingulinux-Look: Pingu im Startmenü, kein Willkommenscenter, kein Discover-Hinweis, nur ein Bluetooth-Symbol, Eigener Ordner und Papierkorb auf dem Schreibtisch, Bildschirmtastatur nur auf Deutsch
- Gesperrte Programme werden im Menü ausgeblendet
- Tux Typing startet auf Deutsch
- WLAN-Firmware für MacBook Air (2011/2012, Broadcom BCM43224)
- Automatische Anmeldung bleibt auch dann aus, wenn sie im Installer angehakt wurde

## Download

> ⚠️ Die ISO ist rund 4 GB groß und liegt deshalb **nicht** in diesem Repository.

<!-- Nach dem Hochladen der Alpha-3-ISO: Link und Prüfsumme hier eintragen. -->
- **ISO-Download (Alpha 3):** [pingulinux-alpha3-amd64.iso](https://sourceforge.net/projects/pingulinux/files/Alpha3/pingulinux-alpha3-amd64.iso/download) (SourceForge)
- **SHA256-Prüfsumme:**

```
PRÜFSUMME-HIER-EINTRAGEN
```

Prüfsumme nach dem Download prüfen (im Ordner mit der ISO):

```bash
sha256sum pingulinux-alpha3-amd64.iso
```

Die angezeigte Zahl muss mit der Prüfsumme oben übereinstimmen. Unter Windows: `certutil -hashfile pingulinux-alpha3-amd64.iso SHA256`.

Ältere Versionen findest du auf [SourceForge](https://sourceforge.net/projects/pingulinux/files/).

## Ausprobieren

1. ISO herunterladen und Prüfsumme prüfen.
2. In einer virtuellen Maschine (z. B. GNOME Boxes, VirtualBox) starten, oder mit einem Programm wie Balena Etcher auf einen USB-Stick schreiben.
3. Im Live-Modus ausprobieren. Dort braucht das Eltern-Kontrollzentrum kein Passwort. Flatpak-Programme lassen sich im Live-Modus nicht installieren, nur im installierten System.
4. Zum Installieren das Symbol „Pingulinux installieren" benutzen. Auf dem installierten System fragt das Eltern-Kontrollzentrum nach dem Administrator-Passwort.

**Getestet auf:** virtuellen Maschinen (GNOME Boxes), MacBook Air 2011/2012 (XFCE und KDE) und Microsoft Surface Go 2 (KDE mit Wayland, Tablet-Modus).

## Bekannte Fehler (Alpha 3)

| Fehler | Auswirkung | Geplant |
|---|---|---|
| Surface und andere Tablets: Die Bildschirmtastatur erscheint im Anmeldebildschirm nicht von selbst. | Lässt sich oben rechts über das Symbol für Barrierefreiheit von Hand öffnen. | Beta 1 (neuer Anmeldebildschirm SDDM) |
| Timekpr-nExT (Bildschirmzeit) erscheint eventuell auf Englisch. | Nur die Sprache, die Funktion ist nicht betroffen. | Beta 1 |
| Installer: Der Haken „Automatisch anmelden“ ist noch sichtbar. | Ohne Wirkung: Die automatische Anmeldung bleibt trotzdem aus. | Beta 1 |
| Installer: kleiner schwarzer Kasten in der Seitenleiste. | Rein optisch. | offen |

## Bekannte Einschränkungen

- **Kinderschutz-Filter (DNS):** Nutzt einen externen DNS-Dienst (CleanBrowsing oder DNS4EU). Dabei werden DNS-Anfragen an diesen Dienst gesendet. Wer das nicht möchte, kann den Filter im Kontrollzentrum ausschalten.
- **`about:config`** ist in Firefox für alle Konten gesperrt, auch für Eltern. Normale Einstellungen gehen weiter über die Firefox-Einstellungen.
- **Flatpaks** lassen sich nur im installierten System installieren, nicht im Live-Modus.
- **Tablet-Modus** gibt es nur in der KDE-Sitzung.
- **Platzhalter-Links:** Im Installer und in `/etc/pingulinux/links.conf` fehlen noch Links für Datenschutz und Impressum. Wird bis 1.0 ergänzt.
- **Größe:** Die ISO ist noch rund 4 GB groß. Eine schlankere Version (Ziel rund 2 GB, Firmware bleibt drin) ist für Beta 2 geplant.

## Fehler melden

Bitte öffne ein [Issue](../../issues) und nenne dabei:

- Was hast du gemacht, und was ist passiert?
- Auf welchem Gerät (Modell, virtuelle Maschine oder echtes Gerät)?
- XFCE oder KDE, Live-Modus oder installiert?
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

### ✅ Alpha 3 (aktuell)
Siehe „Neu in Alpha 3“ oben.

### Beta 1: Sicherheit, nur noch KDE
- **Sicherheitsprüfung:** Umgehungsversuche durch Kinder, Secure Boot, Dual-Boot
- **DNS-Filter vergleichen:** Bietet DNS4EU dieselben Schutzfunktionen wie CleanBrowsing (SafeSearch, VPN-Sperre)? Wenn ja, wird DNS4EU wegen des Datenschutzes der Standard.
- **Automatische Updates**, auch für die eigenen Pingulinux-Programme und die Store-Liste
- **Eigenes Paket-Repository** als Grundlage für diese Updates
- **Liste kompatibler Geräte**
- **Einfache Oberfläche für 2- bis 6-Jährige**
- **Nur noch KDE:** XFCE wird entfernt. Der letzte Stand mit XFCE bleibt im Zweig `xfce-light` erhalten, für eine mögliche Light-Version.
- **Neuer Anmeldebildschirm (SDDM)** mit eingebauter Bildschirmtastatur
- **YouTube Kids ohne Passwort:** Kinder starten es direkt, die Bildschirmzeit begrenzt weiter. Im Kontrollzentrum ein Schalter „nur mit Eltern-Passwort“ für Familien, die es strenger wollen.
- **Eltern-Dashboard** mit Nutzungsstatistik
- **App-Listen pro Kind**
- **App Store:** letzte Programme und Feinschliff

### Beta 2: Praxis
- **Schlankere ISO** (Ziel rund 2 GB, Firmware bleibt drin), vor dem Familientest
- **Test mit echten Familien**
- **Alle bekannten Fehler beheben**, auch die aus dem Familientest

### 1.0
- Name endgültig festlegen
- Rechtliches: Impressum, Datenschutz, Lizenzen
- Release-Prozess mit Prüfsummen, Signatur und Changelog
- Webseite (GitHub Pages) und Dokumentation für Eltern
- Bau-Anleitung aus dem Repository prüfen
- Versionsangaben und Links in Systemdateien und Installer vervollständigen

## Lizenz

Siehe die Datei `LICENSE`. Enthaltene Programme stehen unter ihren jeweiligen Lizenzen. Die Firmware-Pakete (`non-free-firmware`) sind nicht frei im Sinne der Debian-Richtlinien. Die mitgelieferte deutsche Übersetzung von Timekpr-nExT stammt aus dem Timekpr-nExT-Projekt (GPL-3).
