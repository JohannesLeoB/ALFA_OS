# cabinetclaude · Karte

Merkwort für das Küchen-Korpus-System von Draws. Weg zur Küchenfabrik: Lastenhefte nach Thema, Daten statt Code.
Maße kommen vom Schreiner; Spezifikation ist allgemein (keine Marken, Serien, Artikelnummern, Preise).

## Dateien
```
specs/cabinetclaude/
  README.md              Karte
  system.md              Koordinaten, Höhenlagen, Raster, Zeilen, Fugen
  korpus.md              Standardschränke (Tabelle)
  fronten.md             Frontarten, Teilung, Griffvarianten
  bauteile.md            Sockel, Platte, Blenden, Leisten, Böden
  ausstattung.md         Innenleben, Sichtbarkeit, Modellform
  geraete.md             Geräte, Nischen, Einbauregeln
  lastenheft-generator.md  G-01…  Generator (Stufe 1)
  lastenheft-katalog.md    K-01…  Küchenfabrik (Stufe 2)
Packs/presets/carcass.json         Daten (Pack)
Packs/skills/alfanomy/carcass.md   Raster-Skill für Claude
Sources/DrawingKit/KitchenSpec.swift, Cabinets.swift   Generator
```

## Datenfluss
KitchenSpec (Doc.kitchen) -> Kitchen.generate(spec, pack) -> Parts + Units (stabile Ids) -> Ansichten, Render, SVG.
Pack liefert Standards; Eingabe überschreibt; Raster füllt nur Auslassungen.

## Status
| Wert | Bedeutung |
|---|---|
| gebaut | Code vorhanden, Beleg Datei:Zeile |
| Daten | im Pack/Skill als Wert, ohne Logik |
| offen | nur als Anforderung |
