# Status

| Etappe | Stand | Freigabe (Johannes, Datum, Wortlaut) | Gate |
|---|---|---|---|
| E0 Fundament | erledigt | 2026-10-08 „DAHIN“ | G0 erfüllt: 12 Tests grün |
| E1 Gerüst | läuft: B-101, B-103, B-104, B-105 erledigt; B-102, B-106 offen | 2026-10-08 „Go. Einmal vorher rundumcheck, dann mit haikus oder sonnet Auftrag bauen lassen.“ | G1 offen |
| E2 bis E9 | geplant | | |

## Chef-Aufgaben vor E2 (aus den Übergaben von E1)

1. `Setzkasten/project.yml`: UTType `com.johannesleoberger.setzkasten` exportieren (erbt von `com.apple.package`) und als Dokumenttyp eintragen; danach `UTType.setzkasten.conforms(to: .package)` prüfen (Vorschlag in `plan/briefe/B-104.md`).
2. `project.yml`: `gestaltung/vertrag/tokens.json` und `tokens.dunkel.json` als Ressourcen ins App-Paket (aus B-103), sobald B-102 läuft.
3. Kern vor E2: `ItemID` mit eigenem `Codable` als einfache Zeichenkette statt `{"raw": …}`; `Board` um `documentID` und `createdAt` ergänzen (OFFENE-FRAGEN 26, 27). Danach B-104-Tests und Beispielpaket neu erzeugen.
4. Zwei DTCG-Leser zusammenlegen (Tokens.DTCGImport und Document/TokenFile), spätestens in B-506.
5. Große Bilder: Assets beim Öffnen nur bei Bedarf laden und beim Sichern nur Geänderte schreiben, bevor B-201 Autosave baut.

Vor E1 offen: konzept/OFFENE-FRAGEN.md Nr. 1, 4 und 5 (Name, Vertrieb, Takt; Nr. 2 und 3 sind entschieden bzw. per Vorschlag gesetzt).

## Briefe (56)

| Brief | Etappe | Titel | Hängt ab von | Status |
|---|---|---|---|---|
| [B-101](briefe/B-101.md) | E1 | Xcode-Projekt mit XcodeGen | — | erledigt, geprüft 2026-10-08 (Chef: BUILD SUCCEEDED nachgebaut, Team 28Z2KHMANG, Hardened Runtime) |
| [B-102](briefe/B-102.md) | E1 | Fensterschale mit allen Bereichen | B-101 | vergeben an Sonnet-Agent (Arbeitsklon), 2026-10-08 |
| [B-103](briefe/B-103.md) | E1 | AppTheme und Vertragsleser | — | erledigt, geprüft 2026-10-08 (Chef: 55 Tests grün, Pfade und Importe sauber) |
| [B-104](briefe/B-104.md) | E1 | Dokumentpaket .setzkasten | — | erledigt, geprüft 2026-10-08 (Chef: 119 Tests grün, Gesamtprüfung 0 Fehler) |
| [B-105](briefe/B-105.md) | E1 | Prüfskript und Nahtregeln | — | erledigt, geprüft 2026-10-08 (Chef: Lauf grün, Gegentest rot) |
| [B-106](briefe/B-106.md) | E1 | Menüleiste und Tastenkarte | B-102 | offen |
| [B-201](briefe/B-201.md) | E2 | BoardModel: Zustand, Befehle, Rückgängig | B-104 | offen |
| [B-202](briefe/B-202.md) | E2 | Einrast-Engine | B-201 | offen |
| [B-203](briefe/B-203.md) | E2 | Leinwand-View: Zoom, Verschieben, Sichtbarkeit | B-201 | offen |
| [B-204](briefe/B-204.md) | E2 | Auswahl, Lasso, Griffe, Tastatur | B-202, B-203 | offen |
| [B-205](briefe/B-205.md) | E2 | Stückarten zeichnen | B-203 | offen |
| [B-206](briefe/B-206.md) | E2 | Räume als Reiter und Ebenen | B-201, B-102 | offen |
| [B-207](briefe/B-207.md) | E2 | Einfügen und Hineinziehen | B-201, B-104 | offen |
| [B-208](briefe/B-208.md) | E2 | Kontextleiste und Inspektor-Grundgerüst | B-204 | offen |
| [B-209](briefe/B-209.md) | E2 | Leistungsprobe Leinwand | B-203 | offen |
| [B-301](briefe/B-301.md) | E3 | Rahmen und Geräte | B-205, B-208 | offen |
| [B-302](briefe/B-302.md) | E3 | Spaltenraster und Grundlinien | B-301 | offen |
| [B-303](briefe/B-303.md) | E3 | Lineale und Hilfslinien | B-203 | offen |
| [B-304](briefe/B-304.md) | E3 | Abstände zeigen und Messen | B-202, B-303 | offen |
| [B-305](briefe/B-305.md) | E3 | Werkzeugpalette und Werkzeugoptionen | B-204 | offen |
| [B-401](briefe/B-401.md) | E4 | Renderer-Protokoll und Web-Renderer | B-205 | offen |
| [B-402](briefe/B-402.md) | E4 | Player-Verwaltung und Vorschaubilder | B-401 | offen |
| [B-403](briefe/B-403.md) | E4 | Code-Karte und Quelltextansicht | B-401 | offen |
| [B-404](briefe/B-404.md) | E4 | Labor | B-403 | offen |
| [B-405](briefe/B-405.md) | E4 | Hinweise im Labor | B-404 | offen |
| [B-501](briefe/B-501.md) | E5 | Farbfelder und Pipette | B-208 | offen |
| [B-502](briefe/B-502.md) | E5 | Farben aus Bild | B-501 | offen |
| [B-503](briefe/B-503.md) | E5 | Kontrastmatrix | B-501 | offen |
| [B-504](briefe/B-504.md) | E5 | Textstile und Schriftreihe | B-208 | offen |
| [B-505](briefe/B-505.md) | E5 | Bausteine mit Varianten | B-205, B-507 | offen |
| [B-506](briefe/B-506.md) | E5 | Token-Werkstatt und Ausgabe | B-502, B-504 | offen |
| [B-507](briefe/B-507.md) | E5 | Token-Bindung | B-201 | offen |
| [B-601](briefe/B-601.md) | E6 | Bibliothek, Ordner, Suche | B-201 | offen |
| [B-602](briefe/B-602.md) | E6 | Herkunft und Lizenz | B-601 | offen |
| [B-603](briefe/B-603.md) | E6 | Screenshot-Sortierer | B-601 | offen |
| [B-604](briefe/B-604.md) | E6 | Lesezeichen, Gists, Link-Vorschau | B-207 | offen |
| [B-605](briefe/B-605.md) | E6 | Teilen-Erweiterung | B-603 | offen |
| [B-701](briefe/B-701.md) | E7 | Verbindungen und Vorspielen | B-301 | offen |
| [B-702](briefe/B-702.md) | E7 | Vergleich nebeneinander | B-203 | offen |
| [B-703](briefe/B-703.md) | E7 | Versionen von Karten | B-404 | offen |
| [B-704](briefe/B-704.md) | E7 | Mockup-Paket ausgeben | B-602 | offen |
| [B-705](briefe/B-705.md) | E7 | Vertrag-ZIP und Mockup-Paket einlesen | B-103, B-704 | offen |
| [B-706](briefe/B-706.md) | E7 | PDF-Bogen | B-704 | offen |
| [B-801](briefe/B-801.md) | E8 | Claude-Anbindung | B-404 | offen |
| [B-802](briefe/B-802.md) | E8 | iCloud Drive für Dokumente | B-104 | offen |
| [B-803](briefe/B-803.md) | E8 | Ordner-Spiegel | B-603 | offen |
| [B-804](briefe/B-804.md) | E8 | Swift-Vorschau, Versuch mit Messung | B-401 | offen |
| [B-901](briefe/B-901.md) | E9 | Einstellungen und Setups | B-106 | offen |
| [B-902](briefe/B-902.md) | E9 | Erster Start und leere Zustände | B-901 | offen |
| [B-903](briefe/B-903.md) | E9 | Barrierefreiheit | B-902 | offen |
| [B-904](briefe/B-904.md) | E9 | Leistung und Speicher | B-209 | offen |
| [B-905](briefe/B-905.md) | E9 | Auslieferung | B-901 | offen |
| [D-001](briefe/D-001.md) | E1 | Gegenlieferung lesen und Ansichten zeichnen (Claude Design) | — | vergeben an Konto B (Claude Design), 2026-10-08 |
| [D-002](briefe/D-002.md) | E2 | Gestaltungsvertrag der App (Claude Design) | D-001 | offen |
| [D-003](briefe/D-003.md) | E5 | Startbausteine und Musterbogen (Claude Design) | D-002 | offen |
| [P-001](briefe/P-001.md) | alle | Prüfplan je Gate (Konto C) | — | offen |
