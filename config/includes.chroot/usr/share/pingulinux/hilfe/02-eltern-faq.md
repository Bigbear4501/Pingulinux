# Pingulinux OS – Fragen von Eltern

Kurze Antworten auf häufige Fragen. Diese Seite wächst mit der Zeit.

---

## Ich habe mein Eltern-Passwort vergessen. Was jetzt?

Keine Sorge, die Kinderkonten, Fotos und Dokumente bleiben erhalten. Es gibt zwei Wege.

### Weg 1: Ein anderes Eltern-Konto setzt das Passwort neu

Am einfachsten geht es, wenn es auf dem Computer **zwei Eltern-Konten** gibt, zum Beispiel eins für Mama und eins für Papa.

1. Mit dem anderen Eltern-Konto anmelden.
2. Das **Eltern-Kontrollzentrum** öffnen (Symbol auf dem Schreibtisch).
3. **Benutzerkonten** wählen, das Konto mit dem vergessenen Passwort auswählen und ein neues Passwort vergeben.

**Tipp:** Legt gleich nach der Installation für beide Eltern ein eigenes Konto mit Eltern-Rechten an. Dann braucht ihr Weg 2 nie.

### Weg 2: Mit dem Pingulinux-Stick zurücksetzen

Wenn es nur ein Eltern-Konto gibt:

1. Den **Pingulinux-USB-Stick** einstecken (der Stick, mit dem Pingulinux installiert wurde, oder ein neu erstellter).
2. Den Computer vom Stick starten. Pingulinux startet im Live-Modus.
3. Im **Startmenü** unter **System** auf **„Eltern-Passwort zurücksetzen“** klicken.
4. Das Werkzeug findet das installierte Pingulinux von selbst. Das Eltern-Konto auswählen und zweimal das neue Passwort eingeben.
5. Stick abziehen und den Computer neu starten. Jetzt gilt das neue Passwort.

**Gut zu wissen:** Bei einer **verschlüsselten Festplatte** funktioniert Weg 2 nicht.

---

## Kann mein Kind den Stick-Trick auch benutzen?

Wer den Computer vom USB-Stick starten kann, kommt an alles auf der Festplatte heran. Das gilt für jedes Betriebssystem, nicht nur für Pingulinux. Deshalb:

- Im **BIOS/UEFI** ein Passwort setzen.
- Dort den **Start vom USB-Stick abschalten** (oder nur mit Passwort erlauben).
- Den Pingulinux-Stick nicht beim Computer liegen lassen.

Braucht ihr den Stick später selbst (Weg 2), schaltet ihr den USB-Start mit eurem BIOS-Passwort kurz wieder ein.

Wie man ins BIOS kommt, hängt vom Gerät ab. Meist hilft beim Einschalten eine der Tasten **F2**, **Entf**, **F10** oder **Esc**.

---

## Wie sichert Pingulinux unsere Daten?

### Automatisch: das System, jeden Tag

Pingulinux sichert das **System** einmal am Tag von selbst (mit Timeshift) und behält die letzten 5 Stände. Diese Sicherung liegt auf derselben Festplatte. Sie hilft, wenn nach einem Update oder einer Einstellung etwas nicht mehr läuft – nicht aber, wenn die Festplatte kaputtgeht.

**Nicht** automatisch gesichert werden die **eigenen Dateien** (Fotos, Dokumente, Spielstände). Dafür gibt es die Sicherung auf einen USB-Stick.

### Von Hand: auf einen USB-Stick oder eine USB-Platte

1. Stick oder USB-Platte einstecken.
2. **Eltern-Kontrollzentrum → Sicherung und Wiederherstellung → Auf USB-Stick sichern**.
3. Stick auswählen und festlegen, was drauf soll: **Eigene Dateien** und/oder **System**.
4. Passwort eingeben – die Sicherung läuft durch. Danach „Stick auswerfen“.

**Gut zu wissen:**
- Eigene Dateien gehen auf jeden Stick. Auf dem Stick wird nie etwas gelöscht: Was zu Hause gelöscht wurde, bleibt auf dem Stick erhalten.
- Für die **System-Sicherung** braucht der Stick das Linux-Format (ext4). Pingulinux bietet an, den Stick dafür zu formatieren – **dabei wird alles auf dem Stick gelöscht**, und Windows kann ihn danach nicht mehr lesen. Am besten einen eigenen Stick nur für die Sicherung nehmen.
- Wer es regelmäßig macht (z. B. einmal im Monat), ist auch bei einer kaputten Festplatte auf der sicheren Seite.

### Zurückholen

- **Eigene Dateien:** Kontrollzentrum → Sicherung und Wiederherstellung → „Eigene Dateien vom Stick zurückholen“. Der Dateimanager öffnet sich; die Dateien liegen unter *Pingulinux-Sicherung → Name des Computers → Eigene-Dateien* und lassen sich einfach zurückkopieren.
- **System:** Kontrollzentrum → Sicherung und Wiederherstellung → „System wiederherstellen“. Dort einen Stand auswählen – auch einen vom Stick, wenn er eingesteckt ist.

### Pingulinux startet gar nicht mehr – was jetzt?

Auch dann lässt sich eine Sicherung zurückspielen:

1. Den **Pingulinux-USB-Stick** einstecken und den Computer davon starten (Live-Modus).
2. Im Startmenü unter **System** auf **„System retten (Timeshift)“** klicken.
3. Timeshift fragt, wo die Sicherungen liegen: die **eingebaute Festplatte** wählen (oder den Sicherungs-Stick, falls die Festplatte kaputt ist).
4. Einen Stand auswählen, auf **„Wiederherstellen“** klicken und den Anweisungen folgen. Als Ziel die eingebaute Festplatte nehmen.
5. Stick abziehen, neu starten.

Die eigenen Dateien (Fotos, Dokumente) bleiben dabei unverändert. Ist die Festplatte selbst kaputt, hilft nur noch die Sicherung auf dem USB-Stick – deshalb ab und zu „Auf USB-Stick sichern“.
