# Spec · ALFA Creative Family

Stand 22.10.2026 · Entwurf, nicht beschlossen.

## Umfang
- Draws ist ein Editor der ALFA Creative Cloud. Weitere Editoren: Skizze (Linien, Pinsel, Füllungen, Farbbibliotheken auf Foto oder Papier, Annotationen auf PDF), Moodboard, Aufmaß (Foto, Punkt-zu-Punkt-Linien, Maß von Hand oder Laser).
- Gemeinsam: eigene und verbindende Dateitypen, Ein- und Ausgang in ähnlicher Form.
- Claude, Dateien, Vorlagen, Materialtexturen und Medien kommen über Hub und Einstellungen.
- Gebaut wird vorerst nur Draws.

## Familie
| Editor | eigene Engine | Werk |
|---|---|---|
| Draws | Teile, Einheiten, Projektion → Blätter | Entwurf |
| Skizze | Pinsel, Marker, Füllung auf Foto/Papier | Skizze |
| Aufmaß | Kalibrieren, Entzerren, Messen, Laser | Aufmaß (spec `aufmass.md`) |
| Moodboard | Seiten-Layout, Bildzonen, Beschriftung | Board |
| Planvergleich | zwei PDF-Sätze abgleichen | Vergleich |
| Konfigurator | Regeln → Teile | geht als Regel-Generator in Draws auf |
| Ablage | Werke je Projekt, Stände, Verknüpfungen | – |

## Rückgrat (neutral, typisiert, je Bauteil eine Prüfung, die rot werden kann)
| Bauteil | Schnittstelle | Stand |
|---|---|---|
| Werk | `Work<Content>`: id, Art, Projekt, Stände, Assets per id (nie absoluter Pfad), Verknüpfungen | fehlt |
| Raum | Ansicht (Zoom, Verschieben, Einpassen), Einheiten, Kalibrierung (gleichmäßig, Entzerrung über 4 Punkte) | fehlt |
| Szene | Ebenen (sichtbar, Sperre, Deckkraft, Rolle), Elemente (Vektor, Strich, Bild, Beschriftung, Maß), Auswahl, Verlauf | fehlt |
| Werkzeug | `down/move/up(pos, mods, druck)`, Einrast-Kette (Winkel, Raster, Kante, Endpunkt, Flucht), Treffertest | fehlt |
| Bibliothek | Farben, Materialien, Symbole, Stile (Style Master), aus dem Hub | Style Master als Datei in Draws |
| Eingang | `Intake`: Datei → `Ingested` → Eingabe mit Rolle | gebaut |
| Ausgang | `Pages`: Dokument → PDF, SVG, PNG, Druck | gebaut |
| Vorlagen | `Templates`: Musterseiten mit Zonen, Mustache | gebaut |
| Assistent | `Assist`: Claude mit Werkzeugkasten je Editor + Skills | gebaut |
| Dock → Hub | Ports Projekt, Ablage, Dateien, Vorlagen, Claude, Ausgabe | gebaut, lokal |

## Verbindende Typen
| Typ | Inhalt | Fluss |
|---|---|---|
| Maß | Wert, Einheit, Herkunft (Hand, Laser, Kalibrierung, Claude), Fundstelle | Aufmaß → Draws, Konfigurator |
| Material | Code, Name, Ton, Textur-Asset | Bibliothek, Moodboard → Draws, Skizze |
| Unterlage | Bild oder PDF-Seite + Kalibrierung | Aufmaß, Skizze, Draws, Planvergleich |
| Modell | Teile, Einheiten, Bewegung | Konfigurator, Claude → Draws |
| Blatt | `Document` mit Status (Vorplanung, Vorabzug, Final) | alle → Ablage, Mail, Drive, Planvergleich |
| Ebenenpaket | Ebenen mit Elementen | Skizze ↔ Draws, Aufmaß → Skizze |

## Editor-Vertrag
```swift
protocol Editor {
    static var kind: WorkKind { get }
    static var accepts: [InputKind] { get }
    static var produces: [OutputKind] { get }
    func open(_ work: Work) throws -> Session
    func take(_ input: Input, as role: Role) async throws -> Change
    func give(_ kind: OutputKind) async throws -> Output
}
```
Ablage und Assistent arbeiten nur gegen diesen Vertrag; Editoren kennen einander nicht.

## Reihenfolge (Vorschlag, nicht beschlossen)
1. Rückgrat minimal (Werk, Raum, Szene + Verlauf, Werkzeug + Einrasten, Bibliothek)
2. Aufmaß als erster Editor
3. Draws auf das Rückgrat (Doppelungen fallen weg)
4. Skizze, 5. Moodboard, 6. Planvergleich (Altcode-Engine fast 1:1), 7. Konfigurator in Draws

## Altcode-Befund (labor/ansicht, Inventur 22.10.)
- Atelier ist kein Pinsel-Skizzenbuch: Foto + Polylinie/Rechteck/Freihand + 6 feste Füllfarben + Render-Übergabe (KI-Render von Hand). Platzierte Bilder gehen beim Sichern verloren.
- Jeder Editor baut neu: Ansicht/Zoom 6×, Rückgängig 5×, Ebenen-Typ 3×, Treffertest 5×, Punkt-Typ 5×, Export 5 Wege, Plankopf-HTML 3×, Kalibrierung/Einheiten 4×.
- Moodboard speichert Bilder mit absoluten lokalen Pfaden (bricht im geteilten Drive).
- Planvergleich (FFT, log-polar, Funde, 6 Ansichten) ist solide und in sich geschlossen.
- Werkstatt-Ablage `<Kunde>/<Projekt>/<Editor>/<Werk>/<yy-MM-dd_KÜRZEL>/` mit Papierkorb statt Löschen: Funktion übernehmen.

## Offen
1. Werk-Format: Paket (Ordner mit Manifest + Assets) im Projekt-Drive oder Datenbank + Dateien?
2. Wahrheit: Werke im Drive oder in der ALFA-Datenbank mit Drive als Ablage?
3. Ablage/Bridge: eigener Bereich oder Teil von Projekte/Akte?
4. Bibliothek: eine je Firma im Hub?
5. Zeitplan: Editoren nach Ende November; Rückgrat jetzt auf alfa-draws vorbauen?
