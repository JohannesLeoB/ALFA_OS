# Code → Design · Stand 2 · 31.10.2026 (von Johannes freigegeben: „Ok“)

Stand `main` 71ae93dc. Gebaut nach MASTER 2910 (`DESIGN/ALFA Design Master 2026-10-31.zip`).

## Gebaut
- **L1 bis L4** (5be9c08a): Logos je Art nach der Größenregel 2910 (voll 100 %, breit minus step8, Bildmarke Kachel 44 → 24, Dienstkopf 56 → 32), Grundfarben claudeClay, sevdeskRed, clockodoBlue, dhlYellow, sonst sheet. Dienstkopf ohne Haarlinie. Assistent: Bereichszeile nur mit Verlauf und nur mit dem Papierkorb, „Ohne Projekt“ ist entfernt. Mail: Kontotitel füllt die Zeile (Hilfe und Rechtsklick auf der ganzen Zeile). **Offen: L5, L6.**
- **Später senden** (4f030817): „Mehr“ › Später senden mit Heute 18:00, Morgen 8:00, Montag 8:00, Eigene Zeit …; Ordner „Später senden“ nur mit Inhalt; Zeilen „Geplant · {when}“ oder „Nicht gesendet · ALFA war …“ mit Jetzt senden, Bearbeiten, Planung aufheben. Geplant wird nur lokal; versendet wird nur, solange ALFA läuft.
- **Mailingliste:** Banner im Lesebogen, „Abmelden“ als Halte-Bestätigung (One-Click nach RFC 8058, sonst Mail an die mailto-Adresse), „Website aufrufen“, wenn es nur eine Web-Adresse gibt.
- **Verfassen · Senden widerrufen:** Aus, 10, 20, 30 s; Standard 10 s.
- **Konto anlegen mit Serversuche:** Adresse und Anbieter, Fortfahren, „Server werden gesucht“, dann „Server gefunden“ oder „Keine Server gefunden“ mit Feldern von Hand.

## Fragen an Design
1. **„Absendername“ und „Name in Mail“** (B3): Worin unterscheiden sich die beiden Zeilen? „Absendername“ ist nicht gebaut.
2. **Toast während der Widerrufzeit:** Der Bogen zeigt „Sendet …“, Code zeigt „Gesendet“. Bitte den Key liefern.
3. **Abmelden schlägt fehl:** Es gibt keinen Fehlertext. Code öffnet dann die Website, falls es eine gibt.
4. **Konto von Hand:** Für „Server Eingang“, „Port“, „Verschlüsselung“, „Server Ausgang“ und „Passwort Ausgang“ fehlen Keys; Code zeigt die bisherigen IMAP-Felder. Gibt es ein eigenes Passwort für den Ausgang?
5. **Einstellungskachel:** Das Innenmaß ist im Bogen step12, im Code step8. Die gewählte Kachel ist im Vertrag `inverse`, im Code `ink`. Was gilt? Der Token `size.tileLogoSize` (18) wird nicht mehr gelesen.
6. **Assistent ohne Claude-Schlüssel:** Code zeigt „Claude antwortet gerade nicht. In den Einstellungen neu verbinden.“ (`shell.assistantPanel.failed`), auch wenn noch nie verbunden war. Gibt es dafür einen eigenen Zustand mit eigenem Text?

## Offen von Design
- Der Bogen Bestätigen (fehlt in der Teillieferung 2910).
- Bereich A des Assistenten (`AN-DESIGN-3110-assistent-mail.md`); der Code dafür wartet geparkt.
- Teamansichten T1 bis T4 (`AN-DESIGN-3110-rollen.md`); die Logik wartet geparkt.
- Aufträge M1 bis M9 (`70923d34`) und R1 bis R5 (`8af1a29c`).
