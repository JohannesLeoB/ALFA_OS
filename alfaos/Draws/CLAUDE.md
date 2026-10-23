# Draws · Register

Gilt für jede Sitzung in `alfaos/Draws` auf Zweig `alfa-draws`, zusätzlich zu `AGENTS.md`.

Merkwort cabinetclaude = Küchen-Korpus-System von Draws (Typen mit Startwerten, freie Maße, Konfigurator im Canvas): specs/cabinetclaude/, Generator, Werkzeug add_kitchen, Pack presets/carcass.json, Skill Packs/skills/cabinetclaude/.

## Pflege
- Jedes Dokument in `alfaos/Draws` steht in dieser Tabelle. Ein Dokument ohne Zeile wird eingetragen oder gelöscht.
- Bei jeder Arbeit: betroffene Dokumente nachziehen, Veraltetes löschen, kürzen statt anhängen.
- Inhalt sind technische Anforderungen und Karten, keine Zitatsammlung, keine Zuschreibung an Johannes ohne seinen Wortlaut.

## Dokumente
| Datei | Inhalt | Stand |
|---|---|---|
| `NOTES.md` | Was Draws ist, Ausgabe, Grenze zu ALFA, Module, Offenes | 23.10. |
| `specs/hub-needs.md` | Bedarf am Hub: Ein- und Ausgänge, FilesPort-Methoden, Ports, Ereignisse, Materialkatalog | 23.10. |
| `specs/family.md` | Creative Family: Editoren, Rückgrat, Editor-Vertrag, Reihenfolge | 23.10. |
| `specs/design-needs.md` | Draws gegen ALFA-Tokens, -Komponenten, -Namen: Umverdrahten, Design-Bedarf, Risiko Masterwechsel | 23.10. |
| `specs/aufmass.md` | Aufmaß: Ablauf, Funktionen mit Altcode-Beleg, Laser, Blatt-Anforderungen, Prüfung | 23.10. |
| `specs/cabinetclaude/README.md` | Karte, Datenfluss, Status, Zu bestätigen (Claude-Wahl) | 23.10. |
| `specs/cabinetclaude/system.md` | Koordinaten, Höhenlagen, Startwerte, Zeilen, Fugen | 23.10. |
| `specs/cabinetclaude/korpus.md` | Typen mit Startwerten als Tabelle | 23.10. |
| `specs/cabinetclaude/fronten.md` | Frontarten, Teilung, Griffe | 23.10. |
| `specs/cabinetclaude/bauteile.md` | Sockel, Platte, Blenden, Leisten, Böden | 23.10. |
| `specs/cabinetclaude/ausstattung.md` | Innenleben: sichtbar, Part/Unit/Metadatum | 23.10. |
| `specs/cabinetclaude/geraete.md` | Geräte, Nischen, Einbauregeln | 23.10. |
| `specs/cabinetclaude/lastenheft-generator.md` | G-01…: Generator, Stufe 1, mit Status | 23.10. |
| `specs/cabinetclaude/lastenheft-katalog.md` | K-01…: Küchenfabrik, Stufe 2, offen | 23.10. |
| `specs/cabinetclaude/lastenheft-konfigurator.md` | KF-01…: Konfigurator im Canvas (Auswahl, Menü, Tastatur, gemeinsamer Satz), mit Status | 23.10. |
| `specs/cabinetclaude/bemassung.md` | Z-01…: Bemaßung, Plansatz, Ansichtsbeschriftung, mit Status | 23.10. |

## Laufzeit-Texte (von Claude in der App gelesen, keine Doku)
| Datei | Inhalt |
|---|---|
| `Sources/DrawsAI/Resources/designer.md` | Auftrag an Claude für den Einmal-Entwurf |
| `Packs/skills/alfanomy/*.md` | Skillset `alfanomy`: core, dims, materials, motion, steps, plans (Plansatz, Bemaßung); Liste in `manifest.json` |
| `Packs/skills/cabinetclaude/*.md` | Skillset `cabinetclaude`, mit alfanomy zusammengeführt: core, types (Typen, Startwerte), splits, appliances, variants; alle Addons immer geladen |
