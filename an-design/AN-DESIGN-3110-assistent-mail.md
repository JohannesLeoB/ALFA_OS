# Aufträge an Design – Assistent, Mail, Team, 31.10. (von Johannes am 31.10. freigegeben: „ja schreib“)

Grundlage: Master 28.10. Gebaut wird nur, was ein Bogen trägt. Alles hier hat im Master keinen Bogen und wartet auf Design. Die Skizze „Assistent in der ALFA-Shell“ hat Johannes; sie zeigt Funktionen, keine Form.

## A Assistent

### A1 Voller Bereich „Assistent“ (Menüeintrag, Bahnen wie Mail)
- **Ist:** Nur der Mini-Chat im Blob (N37, ALFA Shell :89 ff.). SPEC.md :16 und :90: „Der Assistent wird später ein voller Bereich mit Menüeintrag.“
- **Gebraucht:** Links Verläufe („Allgemein“ und je Projekt einer), Mitte Chat, rechts eine Bahn „Kontext“ mit Dateien im Verlauf, Quellen der Antwort, Wissensvorschlägen.

### A2 Übergang Blob → Bereich
- **Gebraucht:** „Im Assistenten öffnen“ im Blob-Panel; derselbe Verlauf läuft im Bereich weiter. Der Code hat dafür schon einen gemeinsamen Verlauf (ein ChatState).

### A3 Eingaben
- Text bis 120 000 Zeichen (`count.chatTextCharacterLimit`).
- Dateien (Bilder, PDF, Dokumente) bis 20 MB je Datei (`count.chatDocumentByteLimit`), per Büroklammer oder Ziehen. Zustände: ausstehend, gesendet, zu groß, nicht lesbar, nicht unterstützt.
- Bereichszeile: „Allgemein“ oder Projekt; Modell automatisch.

### A4 Ausgaben im Verlauf (Bauteile, die einzeln gezeichnet werden müssen)
| Baustein | Bestätigung |
|---|---|
| Antworttext (gestreamt), Aktivitätszeile, Quellenzeile | – |
| Schätzung mit Aufschlüsselung (min/mittel/max, Sicherheit, Belege) | – |
| Mail-Entwurf | ja |
| Kontakt-Vorschlag (Google, Airtable) | ja |
| Termin-Vorschlag, Kalender-Link | ja |
| Aufgaben-Änderung (ClickUp) | ja |
| Warenkorb-Vorschlag (Katalog/Lager) | ja |
| Erzeugte Datei (Text, CSV, PDF) mit Öffnen und Sichern, optional ins Projekt | ja, fürs Projekt |
| Wissensvorschlag (Firmen- oder Preiswissen mit Quelle und Zitat) | Freigabe durch Admin |
| Drive-Dateien (Liste) | – |
| Nicht lesbar | – |

### A5 Wissen
- **Code kann schon (Branch `JO/assistant-core`, nicht verdrahtet):** Einträge mit Art (Firma, Preis), Aussage, Betrag/Einheit, Quelle mit Zitat, Zustand vorgeschlagen/freigegeben/abgelehnt.
- **Gebraucht:** Liste offener Vorschläge und freigegebener Einträge mit Quellen; Freigeben/Ablehnen nur für Admin; der Vorschlag als Karte im Verlauf.

### A6 Zustände
- Ruhe, Eingabe, Denkt, Verlauf, Fehler abnehmen (heute nur Entwurf).
- N38: Blob, wenn der Assistent ganz aus ist.
- Assistent von der Firma ausgeschaltet: eigener Satz statt „Der Assistent ist ausgeschaltet.“ (heute wird `assistant.engine.policyOff` wiederverwendet).

## T Team (ersetzt R1 und R3 in Teilen)

Die Logik ist neu gebaut (Branch `JO/charming-elgamal-44e5b6`, nicht verdrahtet):
- Die Teamliste ist eine Datei „ALFA Team/team.json“ in einem beliebigen geteilten Ordner (Drive, iCloud, Dropbox, Netzlaufwerk). Kein Dienst wie Airtable nötig.
- Zwei Rollen: Admin und Team. Allein heißt: alles frei, nichts einrichten.
- Admin wird nur, wessen Adresse per Google- oder Microsoft-Anmeldung bestätigt ist.
- **Entfällt gegenüber R1 bis R5:** Touch ID zum Entsperren, „Erlaubte Modelle“ (das Modell-Routing bleibt unverändert), „Verläufe löschen nach N Tagen“.

### T1 Team teilen und beitreten
- „Team teilen“ mit Ordnerwahl (nur das legt die Datei an), „Team beitreten“ mit Ordnerwahl, „Team verlassen“.

### T2 Teamliste
- Personen mit Mail, Name, Rolle; Person anlegen, Rolle ändern; der letzte Admin bleibt.

### T3 Zustände
- Konflikt („jemand hat die Teamliste gleichzeitig geändert, neu geladen“), Ordner nicht erreichbar (letzter Stand gilt), Datei nicht lesbar, unbekannte Einträge.

### T4 Gesperrte Zeilen
- Wie R2: Zeilenform „von der Firma festgelegt“ für gesperrte Kategorien, Dateien im Chat und die Zugriffsstufe.

## M Mail und Einstellungen

Im Code stand „Endgültig löschen?“ zunächst an Stellen ohne Bogen; zurückgebaut auf die Zeilen-Pill im Papierkorb (Master). Gebraucht wird eine Entscheidung und, wo gewollt, ein Bogen für:
- **M1** Lesekopf: „Endgültig löschen“ für eine Mail im Papierkorb, mit Bestätigung im Kopf; dazu Entf im Lesestapel. Heute zeigt der Lesekopf im Papierkorb keinen Lösch-Slot.
- **M2** Kontextmenü der Zeile: Eintrag „Endgültig löschen“.
- **M3** Auswahlleiste: „Endgültig löschen“ für mehrere Mails im Papierkorb.
- **M4** Kacheln: „Endgültig löschen“.
- **M5** Übersicht: „Endgültig löschen“.
- **M6** Einstellungen › Ordner: Projektordner dort wählen (heute nur Wert; gewählt wird in der Karte des Dateidienstes).
- **M7** Text nach „Als Spam melden“: heute „Verschoben“ mit Rückgängig; der Master hat keinen eigenen Text.
- **M8** `views.json` beschreibt „Mehr laden“ mit 120 Mails; entschieden sind 500 (29.10.).
- **M9** Zeilenmenü: macOS Mail hat dort zusätzlich Allen antworten, Spam, Markierung, Kopieren in, Umleiten, Als Anhang weiterleiten. Ob Standard, ist nicht gegen Outlook, Thunderbird und Gmail abgeglichen; Bogen nur, wenn gewollt.
