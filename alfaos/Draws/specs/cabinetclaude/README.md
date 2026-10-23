# cabinetclaude · Karte

Merkwort für das Küchen-Korpus-System von Draws. Weg zur Küchenfabrik: Lastenhefte nach Thema, Daten statt Code.
Maße kommen vom Schreiner; Spezifikation ist allgemein (keine Marken, Serien, Artikelnummern, Preise).

## Dateien
```
specs/cabinetclaude/
  README.md              Karte
  system.md              Koordinaten, Höhenlagen, Startwerte, Zeilen, Fugen
  korpus.md              Typen mit Startwerten (Tabelle)
  fronten.md             Frontarten, Teilung, Griffvarianten
  bauteile.md            Sockel, Platte, Blenden, Leisten, Böden
  ausstattung.md         Innenleben, Sichtbarkeit, Modellform
  geraete.md             Geräte, Nischen, Einbauregeln
  lastenheft-generator.md  G-01…  Generator (Stufe 1)
  lastenheft-katalog.md    K-01…  Küchenfabrik (Stufe 2)
  lastenheft-konfigurator.md  KF-01…  Konfigurator im Canvas
Packs/presets/carcass.json         Daten (Pack)
Packs/skills/cabinetclaude/        Skill für Claude (core, types, splits, appliances, variants); eine Quelle der Maße im Prompt
Sources/DrawingKit/KitchenSpec.swift, Cabinets.swift   Generator
```

## Datenfluss
KitchenSpec (Doc.kitchen) -> Kitchen.generate(spec, pack) -> Parts + Units (stabile Ids) -> Ansichten, Render, SVG.
Pack liefert Startwerte; Eingabe überschreibt; Startwerte füllen nur Auslassungen.

## Status
| Wert | Bedeutung |
|---|---|
| gebaut | Code vorhanden, Beleg Datei:Zeile |
| Daten | im Pack/Skill als Wert, ohne Logik |
| offen | nur als Anforderung |

## Zu bestätigen
Werte, die Claude gewählt hat; Status je Zeile: Claude-Wahl, offen.
- Sockelrücksprung 50 → Generator, Pack `presets/carcass.json`, Skill core → Claude-Wahl, offen
- Rückwand 8, Seite 19, Fachbodenraster 300 → Generator, Pack carcass, Skill splits → Claude-Wahl, offen
- Schubladenteilung 20/30/50 % → Generator, Skill splits → Claude-Wahl, offen
- Einlagen Kochfeld 560 × 490 bei 60, Spüle 500 × 400 bei 80 → Generator, Skill appliances → Claude-Wahl, offen
- Gerätetöne → Pack carcass, Render → Claude-Wahl, offen
- Studio-Werte 100/810/20 und Studio-Plan, -Deck, CI → Skill core/types/plans, `Packs/template/studio-*` → Claude-Wahl, offen
- Lichtpresets Studio, Weich, Warm, Hart → Foto-Render (DrawsRender) → Claude-Wahl, offen
- A4-Deck-Vorlage → `Packs/template/studio-a4-deck` → Claude-Wahl, offen
- ExportName-Muster → DrawsDock → Claude-Wahl, offen
- Intake xlsx und CSV → Intake → Claude-Wahl, offen
