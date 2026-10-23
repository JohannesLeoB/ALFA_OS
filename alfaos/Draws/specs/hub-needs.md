# Spec · Was Draws vom Hub braucht

Stand 22.10.2026 · Vorschlag der Draws-Sitzung auf das Hub-Briefing der Lead. Keine Änderung am Hub. Draws importiert den Hub nicht; die App bildet die Draws-Protokolle (DrawsDock) auf die Hub-Ports ab. `FileFolder` und `FileEntry` in DrawsDock/Ports.swift sind feldgleich mit Hub/Files.swift (id, name / id, name, mimeType, isFolder).

## a · Eingang und Ausgang je Modul
| Modul | Eingang | Ausgang | Format | Größe üblich / größte | Häufigkeit |
|---|---|---|---|---|---|
| Intake | Dateien aus Projektordner oder Vorlagen | `Ingested` (in der App) | PDF, Bild, IDML, xlsx, CSV, DXF; DWG nur erkannt | 1–8 MB / 17 MB (Plansatz Bad, 24 S.); CAD-Exporte bis 130 MB | bei Bedarf |
| Templates | Vorlagen (Musterseiten, Mustache, IDML) aus „Vorlagen“ | gefülltes Dokument | JSON, HTML/Mustache, IDML | KB / 3 MB | beim Öffnen, selten neu |
| Packs (CI, Vorlage, Material) | Einstellungen „Vorlagen“, Firmendaten | Blattwerte | JSON + Schriften (otf/ttf) + Logo (svg/png) | KB / 2 MB | beim Start, bei Änderung |
| Pages | Blatt aus Draws | PDF, SVG, PNG, HTML (interaktiv) | – | 0,1–2 MB / 20 MB (Satz mit Bildern) | bei Export |
| Assist | Claude-Zugang (Schlüssel, Modell), HTTP | Ereignisse, Werkzeug-Aufrufe | JSON, Bilder ≤ 30 MB je Lauf | – | bei Bedarf, laufend während eines Laufs |
| DrawsDock Projekt | Projektfelder (Nachname, Projekt, Straße, PLZ/Ort, Kundennr., Datum, Status), Projektnummer | – | Felder | – | beim Öffnen, bei Änderung |
| DrawsDock Ablage | Ordner: Arbeitsstand, Präsentation, Anfragen Gewerke | Dateien dort ablegen | – | – | bei Sichern/Export |
| DrawsDock Katalog | Materialien (Code, Name, Ton, Textur) | – | Datensätze + Bilder | 100 Einträge / 10 000 | beim Öffnen |

## b · Fehlende Methoden am FilesPort
```swift
func folders(in folderID: String) async throws -> [FileFolder]
func makeFolder(name: String, in folderID: String) async throws -> FileFolder
func info(_ fileID: String) async throws -> FileInfo      // size, modified, mimeType, parent
func download(_ fileID: String, to url: URL) async throws  // große Dateien ohne alles im Speicher
func upload(_ url: URL, name: String, mimeType: String, into folderID: String) async throws -> FileEntry
func find(_ query: String, in folderID: String?) async throws -> [FileEntry]
```
`FileInfo { id, name, mimeType, size: Int64, modified: Date, parent: String }`. Löschen und Verschieben braucht Draws nicht; Altcode legte in einen Papierkorb statt zu löschen.

## c · Weitere Ports
- **Assistant:** `credentials() -> (key, model)` und `http`; Draws baut darauf `Assist.Session` (HUB-F27).
- **Documents:** Vorlagen und CI aus den Einstellungen: `templates() -> [TemplateRef]`, `read(template) -> Data`, `fonts() -> [URL]`, `logo() -> Data?`, `company() -> [String: String]` (Firmendaten für den Fuß des Schriftfelds).
- **Projects** (heute DataKind ohne Port): `current() -> ProjectRef?` mit den Feldern oben und dem Projektordner.
- **Contacts:** nur über Projects (Kunde, Anschrift); kein eigener Port für Draws.
- **Mail:** Entwurf mit Anhang (`EmailDraft` + `DraftAttachment`) für „als Mail senden“.

## d · Ereignisse
Nur holen auf Anforderung. Ausnahmen, die helfen würden: `newItems(.files)` für den Vorlagen-Ordner (neue Vorlagen erscheinen ohne Neustart) und `inletChanged` für den Claude-Zugang (Live-Panel zeigt verbunden oder nicht).

## e · Material- und Medienkatalog
Quelle: Medienbibliothek der Firma (tabellenbasiert) und Medienkatalog im Cloud-Laufwerk (ca. 23 000 Bilder); beide im Hub verbunden. Draws liest nur.
- Port `Materials`: `list(group: front|carcass|worktop?, tags: [String], query: String?, page: Int, size: Int) -> Page<MaterialRef>`; Seitenweise ist Pflicht (ca. 23 000 Bilder).
- `MaterialRef { code, name, group, swatch: ImageRef, tile: (mm, mm), roughness }`.
- Suche und Filter nach Gruppe und Tags.
- `image(_ ref, size) -> Data`: Bild oder Textur erst auf Anforderung holen, mit Cache (Größe begrenzt, Neuladen bei Änderung).
- Bedarf aus lastenheft-konfigurator.md (KF-21).

