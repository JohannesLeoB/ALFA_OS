# Spec · ALFA Creative Family

Stand 22.10.2026 · Entwurf der Draws-Sitzung, keine Entscheidung. Gebaut wird vorerst nur Draws (Johannes 22.10.: „wir bleiben aber baulich erstmal bei draws“).

## Johannes' Wort
- 22.10.: „DRAWS ist in ALFA_OS, als eine der Funktionsengines der creative cloud, also den Editoren“ – Skizze/Atelier (Linien, Pinsel, Marker, Tusche, Füllungen, Farbwähler, Farbbibliotheken auf Foto oder Papiervorlage), Entwurfsskizzen mit Annotationen auf PDFs, Moodboard (wie InDesign, Canva, Figma, Notion, Keynote), Aufmaß (Foto, Laser per Bluetooth, Punkt-zu-Punkt-Linien, Maße von Hand oder vom Laser), Materialtexturen und Medien aus Hub und Integrationen.
- 22.10.: die Editoren wie Adobe-Produkte gedacht (Photoshop, Illustrator, InDesign, Bridge), „eine family mit eigenen und verbindenden File- und Funktionstypen und immer auch einem rein und raus in sehr ähnlicher Form“.
- 22.10.: Claude, Dateien, Vorlagen kommen zentral über Hub und Einstellungen.

## Familie
| Editor | Sinnbild | eigene Engine | Werk |
|---|---|---|---|
| Draws | Illustrator + Dimension | Teile, Einheiten, Projektion → Blätter | Entwurf |
| Skizze | Photoshop / Fresco | Pinsel, Marker, Füllung auf Foto/Papier | Skizze |
| Aufmaß | Messwerkzeug | Kalibrieren, Entzerren, Messen, Laser | Aufmaß (spec `aufmass.md`) |
| Moodboard | InDesign / Canva | Seiten-Layout, Bildzonen, Beschriftung | Board |
| Planvergleich | Acrobat Vergleichen | zwei PDF-Sätze abgleichen | Vergleich |
| Konfigurator | Konfigurator | Regeln → Teile | geht als Regel-Generator in Draws auf |
| Ablage | Bridge | Werke je Projekt, Stände, Verknüpfungen | – |

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
- Atelier ist kein Pinsel-Skizzenbuch: Foto + Polylinie/Rechteck/Freihand + 6 feste Füllfarben + Render-Übergabe (Firefly von Hand). Platzierte Bilder gehen beim Sichern verloren.
- Jeder Editor baut neu: Ansicht/Zoom 6×, Rückgängig 5×, Ebenen-Typ 3×, Treffertest 5×, Punkt-Typ 5×, Export 5 Wege, Plankopf-HTML 3×, Kalibrierung/Einheiten 4×.
- Moodboard speichert Bilder mit absoluten lokalen Pfaden (bricht im geteilten Drive).
- Planvergleich (FFT, log-polar, Funde, 6 Ansichten) ist solide und in sich geschlossen.
- Werkstatt-Ablage `<Kunde>/<Projekt>/<Editor>/<Werk>/<yy-MM-dd_KÜRZEL>/` mit Papierkorb statt Löschen: Funktion übernehmen.

## Offen für Johannes und die Lead
1. Werk-Format: Paket (Ordner mit Manifest + Assets) im Projekt-Drive oder Datenbank + Dateien?
2. Wahrheit: Werke im Drive oder in der ALFA-Datenbank mit Drive als Ablage?
3. Ablage/Bridge: eigener Bereich oder Teil von Projekte/Akte?
4. Bibliothek: eine je Firma im Hub?
5. Zeitplan: Editoren nach Ende November; Rückgrat jetzt auf alfa-draws vorbauen?
