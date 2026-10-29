# Verflechtung im Code (graphify)

Stand 29.10.2026, **ungeprüft**. Gebaut mit graphify 8, nur aus dem Code, ohne Sprachmodell. Grundlage: `ALFA_OS` `main` @ f22d7bcc (669 Swift-Dateien) und aus Etappe I `alfa-shell.js` und `alfa-bausteine.js`.

## Dateien
- `graph.html`: im Browser öffnen, braucht Internet für die Zeichenbibliothek. Ein Punkt ist ein Typ mit echtem Namen (z. B. `InboxState`, `SettingsContext`, `MailSearchPort`) und Datei:Zeile; die Farbe ist der Bereich.
- `graph.json`: derselbe Graph als Daten. `bereichsmatrix.json`: Zählung Bereich × Bereich je Kantenart.
- `bereiche.py`: bildet graphify-Knoten auf Bereiche ab (Regel nach Pfad; Assistent = `Sources/Assistant` und `App/Shell/Assistant*`).

## Zahlen
- 1099 Typen, 3288 Verbindungen zwischen Typen; davon **802 über Bereichsgrenzen**.
- Typen je Bereich: Mail 206, Dienste 176, Assistent 171, Hub 119, Grundlage 112, Kalkulation 98, Hülle 95, Einstellungen 51; Design-Laufzeit 71 Funktionen.

## Wer nutzt wen (Typ-Paare, Zeile nutzt Spalte)

| nutzt → | Grundlage | Hülle | Mail | Einstellungen | Hub | Assistent | Kalkulation | Dienste |
|---|---|---|---|---|---|---|---|---|
| **Grundlage** | · | 22 | 2 | 2 | 2 | 1 | · | · |
| **Hülle** | 19 | · | 13 | 3 | 27 | 54 | 10 | 15 |
| **Mail** | 138 | 40 | · | 2 | 69 | 3 | · | 3 |
| **Einstellungen** | 56 | 17 | 4 | · | 52 | 6 | · | · |
| **Hub** | 15 | 2 | 7 | · | · | 2 | · | 13 |
| **Assistent** | 18 | 4 | · | · | 11 | · | 5 | 10 |
| **Kalkulation** | 5 | · | · | · | · | 2 | · | 3 |
| **Dienste** | 11 | 1 | 22 | · | 59 | 47 | 5 | · |

## Stärkste Querverbindungen
- Mail → Grundlage: 138 (calls 174, references 62)
- Mail → Hub: 69 (references 192, calls 42, implements 4)
- Dienste → Hub: 59 (references 52, implements 18, calls 14)
- Einstellungen → Grundlage: 56 (calls 51, references 12)
- Hülle → Assistent: 54 (calls 44, references 20, implements 2)
- Einstellungen → Hub: 52 (references 70, calls 36)
- Dienste → Assistent: 47 (references 56, calls 10, implements 9)
- Mail → Hülle: 40 (references 49, calls 22, implements 1)

## Grenzen
- Bögen (`*.dc.html`) und Brief erkennt graphify nicht ohne Sprachmodell; sie fehlen im Graphen.
- Zwischen Swift und JavaScript gibt es keine Kanten; die Design-Laufzeit steht als eigene Insel.
- 10 % der Kanten im Rohgraphen sind von graphify erschlossen (INFERRED), nicht direkt gelesen; in `graph.json` je Kante markiert.
- `Sources/Hub/Port/SyncPort.swift` lieferte keine Symbole (Meldung von graphify).
