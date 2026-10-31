# Rückschein Code → Design · 31.10.2026 (von Johannes freigegeben: „Ja, rein“)

Antwort auf `lieferung-an-code/AN-CODE-3110.md` (MASTER 2910). Master 2910 ist in Code übernommen (`main` d678e10c), die 13 neuen Tokens ebenfalls (159a9bd8). Belege beziehen sich auf `main` ab 2978c3d9.

## F1 · `where` im Lieferschein — Ja
- Code liest `where` nirgends. Kein Skript im Repo liest den Lieferschein; `utils/check.py` prüft in `DESIGN/` nur `MANIFEST.json` und die ZIP-Hashes.
- Schema und Prüfer sind Designs Briefwerkzeug (`DESIGN/brief/`), seit dem Rebuild 27.10. nicht mehr in Code. Die Änderung gehört in Designs Kopie:
  - `delivery.schema.json:22` zusätzlich `contract/<name>.json|txt` zulassen.
  - `check_delivery.py:88-92`: Einträge ohne `:Zeile` nur auf „Datei liegt im Export“ prüfen.
  - Dann T8 → `contract/changes.json`, T1 → die vier Token-Dateien, T7 → `akte.json`, `werte-abgleich.json`. Der Platzhalter `ALFA Mail.dc.html:289` entfällt.

## F2 · „Aus Projektordner“
1. **Quelle:** nur Google Drive. Projekte sind die direkten Unterordner des gewählten Projektordners (Einstellungen › Google › „Projektordner“: Laufwerk, dann Ordner). Airtable, ClickUp, lokale Ordner sind keine Quelle; ein Projekt-Modul gibt es noch nicht (Projekte entstehen später in der App, Entscheidung 29.10.).
2. **Ebenen:** Projektliste, darunter beliebig tief; je Ebene Ordner vor Dateien, Ordner öffnet die nächste Ebene, Datei hängt sich an den Entwurf. Kopf „Projekt · Ordner“. Kein „zurück“, keine Suche. Google-Formate (Docs, Sheets, Slides) werden ausgeblendet.
3. **Höchstzahl:** `count.projectFilesMax` = 8 ab Ebene 2 (Ordner und Dateien zusammen); Rest als Zeile „{n} weitere im Projektordner“ ohne Aktion. Die Projektliste ist ungekappt (Drive liefert bis 2000 je Ordner); das Menü scrollt nicht. Ordnerzeilen zeigen die Zahl der Einträge, Dateizeilen die Größe.
4. **Texte** (`mail.projectFiles.*`): „Kein Projektordner gewählt“ + „Projektordner wählen …“; „Lädt …“; „Keine Dateien“ (auch bei leerer Projektliste); „Ordner nicht geladen“ + „Erneut versuchen“; „{n} weitere im Projektordner“. Toasts: „Anhang nicht geladen“, „Nicht gesichert · Projektordner nicht erreichbar“, „PDF nicht gesichert“.
5. **Fehler** werden nicht unterschieden (offline, abgemeldet, keine Berechtigung → alle „Ordner nicht geladen“). Die Projektliste kommt aus dem Zwischenspeicher des Abgleichs.
6. **Gegen den Bogen:** Texte und Ablauf wie `alfa-bausteine.js:144-152`. Abweichung: Bogen hat genau drei Menüs (Projekt, Ordner mit Zahl, Datei; Kappung nur bei Dateien), Code geht beliebig tief und kappt jede Ebene unter dem Projekt. Ohne verbundenes Google-Konto mit Dateien fehlt der Eintrag ganz.
- **Gebraucht von Design:** drei Ebenen oder beliebig tief? Weg zu den Einträgen über 8 (Scrollen, „alle zeigen“)? Getrennte Fehlertexte (offline / abgemeldet / keine Berechtigung)?

## F3 · Hub N27–N31, N33
- **N27 Katalog:** keine Kategorien im Modell. Merkmale für Filter: Zustand (6), Firma/persönlich (Airtable, sevDesk, DHL Firma; Rest persönlich), Zugangsart (Browser, Passwort, Schlüssel, E-Mail+Schlüssel), versorgte Bereiche (Mail, Kontakte, Dateien). 8 Dienstkacheln + Schlüssel-Inventar. Aktionen: Hinzufügen, Neu verbinden, Prüfen, Trennen. „Verwalten“ gibt es nicht.
- **N28 Clockodo:** lesbar Kunden (id, Name, aktiv), Projekte (id, Kunde, Name, aktiv), Leistungen (id, Name, aktiv), Einträge (id, Kunde, Projekt, Leistung, Text, Beginn, Sekunden, abrechenbar). Kein Nutzer-Abruf, nur Feld „Clockodo-Nutzer“ (optionale Zahl). Schreiben (Eintrag anlegen/löschen) ist gebaut, aber nicht verdrahtet.
- **N28 Airtable:** liest und schreibt Datensätze einer Base und Tabelle; Feldwerte Text, Liste, Zahl, Ja/Nein, leer. Basen, Tabellen, Felder lassen sich nicht abrufen; die Namen kommen aus der Firmenkonfiguration (16 Base-, 26 Tabellen-, 15 Feldschlüssel). Schreiben nur laut Erlaubnisliste.
- **N29 Mitteilungen:** gebaut sind nur „neue Mail“ (Anzahl, mit Ton), der To-Do-Alarm des Assistenten und der Blob-Punkt bei fertiger Antwort. Pro Dienst nur der Abgleich-Takt (Automatisch, Aus, Manuell, 30 s, 1/5/15/30 min, 1 h). Keine Mitteilungsarten, kein Mitteilungstakt, kein „stumm“. Meldbare Ereignisse im Hub: Abgleich fertig / fehlgeschlagen (mit Hinweis), neue Daten je Art.
- **N30 Dateiorte:** wählbar nur ein Projektordner in Google Drive (Mein Drive oder geteiltes Laufwerk). Mac, Dropbox, Server gibt es nicht; Ordnerrollen auch nicht. Rückmeldungen: „Projektordner abgeglichen · gerade eben“ / „Abgleich fehlgeschlagen · Projektordner nicht erreichbar“ + Wiederholen. Mail-Anhänge lokal: an/aus, Obergrenze 1/5/10/25 GB/keine, Ordner Standard oder eigener. Vorlagen: fester Ordner, nicht wählbar.
- **N31 Detailbericht:** je Fehler vorhanden: Art (vorübergehend, Anmeldung, abgelehnt), Anbieter, Status, Code, Servertext, Zusatzfelder; im Log Zeit, Ereignis (Anmeldung, Prüfung, Abgleich, Erneuerung, Schreiben), Bereich; bis 100 Einträge je Anschluss. Angezeigt wird heute nur „Fehler · Text (Status)“ und „Letzter Fehler … · letzter Erfolg …“. Eine Anfragekennung liest kein Dienst. „Eingeschränkt“ ist kein Zustand (es gibt: verbunden, verbindet, gleicht ab, nicht verbunden, Fehler, Schlüsselbund nicht lesbar).
- **N33 Kontaktquellen:** vier: Google-Kontakte (je Google-Konto, Name + E-Mail), Airtable-Kunden (wenn Base, Tabelle, E-Mail-Feld konfiguriert), Adressen aus Mails, eigene Kontakte (lokal). iCloud/macOS-Kontakte gibt es nicht. Mehrere zugleich: ja, zusammengeführt nach Adresse, erster Name gewinnt. Je Quelle ein Schalter (Standard an) und ein Zwischenspeicher. Zustände Laden/Leer/Fehler je Quelle sind nicht modelliert.

### Daten je Dienst
| Dienst | Anmeldung | Felder | Prüfung | Fehler |
|---|---|---|---|---|
| Google | Browser (OAuth), persönlich | – | Token → Konto → Gmail-Labels | Anbieter, Status, Google-Code, Text |
| Mail-Konten | Passwort bzw. Outlook-OAuth, persönlich | 11 (Name, Adresse, Art, Eingang/Ausgang Host/Port/Sicherheit, Benutzer, Passwort); Voreinstellungen Ionos, GMX, Web.de, iCloud, Fastmail, Andere | Anmeldung am Server | IMAP-Code, SMTP-Status/Code, Serverzeile |
| ClickUp | Schlüssel, persönlich | token | Benutzer abrufen | nur HTTP-Status |
| Clockodo | E-Mail + Schlüssel, persönlich | email, key, user (opt.) | Einträge von heute | nur Status |
| Claude | Schlüssel, persönlich | key, Modell (opt.) | Ein-Token-Anfrage | nur Status (auch 429/529) |
| Airtable | Base + Schlüssel, Firma | base, token | Datensatzabruf | Status (Text wird verworfen) |
| sevDesk | Schlüssel, Firma | token | Buchhaltungsversion | nur Status |
| DHL | Schlüssel, Firma | key, shipKey, secret, user, password, billing | nur Tracking-Schlüssel | Sendungszustände: Erfasst, Im Transport, In Zustellung, Zugestellt, Problem, Unbekannt |
| Happa Happa | – | – | – | kein Eintrag, kein Client; Zugang unbekannt |

## F4 · Live-Abweichungen
| | Stand |
|---|---|
| L1 Logos | teilweise. Im Bundle nur Clockodo und DHL (`Assets.xcassets`); `material/icons` ist nicht im Repo. Google, Mail-Konten, ClickUp, Claude, Airtable, sevDesk zeigen Buchstaben. Offen: Bilddateien der übrigen Logos (bitte als SVG/PNG liefern), Farbgründe `claudeClay`, `sevdeskRed`, `clockodoBlue`, Größenregel je Logoart. Code baut das als Nächstes. |
| L2 Dienstkopf | gebaut (30.10.). Abweichung zum Vertrag 2910: Haarlinie bei nicht breiten Logos, `logoMark` 32 und `logoWideInset` fehlen. Wird nachgezogen. |
| L3 „Ohne Projekt“ | offen, wird entfernt. |
| L4 Titel linke Mail-Bahn | anders gebaut: füllt die Zeile nicht, Rechtsklick nur am Text. Wird nachgezogen. |
| L5 | DHL gebaut (eine Kachel, sechs Felder). Happa Happa offen (Zugang fehlt). |
| L6 Hinweis über dem Assistenten | Verweilhinweis gebaut wie entschieden; er schweigt bei offenem Assistenten nicht und hängt zusätzlich am Abgleich-Knopf. Entscheidung bei Johannes. |
| L7 | gebaut (Gruppe Dateiordner). |
| L8 | teilweise: Ich-Karte gebaut, „Bild wählen“ und Teams fehlen. |
| L9 | für Dateiordner gebaut; Identität und Firmendaten zeigen noch Untertitel, die der Vertrag nicht kennt. |

## Offen, weil Code es nicht hergibt
- Kategorien je Dienst (N27), Mitteilungsarten/-takt/stumm (N29), Ortswahl außer Drive und Ordnerrollen (N30), Anfragekennung und „eingeschränkt“ (N31), Kontaktquellen iCloud/macOS und Zustände je Quelle (N33): nicht gebaut; erst mit Entscheidung und Bogen.
- Echte Beispielwerte aus Clockodo/Airtable-Antworten: in der App sind die Schlüssel noch nicht eingetragen.
- Happa Happa: Zugang, Felder, Prüfung unbekannt.
