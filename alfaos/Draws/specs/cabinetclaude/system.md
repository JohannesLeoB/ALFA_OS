# System

## Koordinaten
| Achse | Richtung | Ist |
|---|---|---|
| x | entlang der Front | gebaut (Frame, Cabinets.swift:42) |
| y | in die Tiefe (Wand = größtes y) | gebaut |
| z | nach oben, Ursprung = Fertigfußboden | gebaut |
Einheit mm. Zeilen drehen um z in 0/90/180/270 (turn).

## Höhenlagen (z, mm, Standard)
| Lage | von | bis | Quelle |
|---|---|---|---|
| Sockel | 0 | 80 | Daten plinth |
| Korpus | 80 | 880 | Daten carcass 800 |
| Arbeitsplatte | 880 | 920 | Daten worktop 40 |
| Nische | 920 | 1520 | wallGap 600 (min. 560) |
| Wand | 1520 | 1520+h | gebaut (Cabinets.swift:129) |
| Attika | Oberkante Wand | Decke | offen |
| Decke | Raumhöhe | | offen |
Lage-Namen sind Merkwörter, kein Datenfeld; Sockel-/Plattenhöhe je Küche änderbar: offen (nur Pack).

## Raster
| Raster | Wert | Status |
|---|---|---|
| Lochreihe | 32 mm | offen (Ausstattung) |
| Breitenstufen | 200 300 400 600 800 (Eck 675 880 1280) | Daten |
| Höhenraster | Parameter (Unter 800; Wand 400-1000; Hoch 1400-2200) | Daten |
Maße frei: jede positive Größe gilt; Raster füllt nur Fehlendes (gebaut, Cabinets.swift:106).

## Zeilen
| Form | Regel | Status |
|---|---|---|
| Zeile | Schränke links nach rechts, Cursor addiert Breiten | gebaut (:112) |
| L, U | Folgezeile ohne origin setzt an Eckschrank an, turn = Vorgänger + 270 | gebaut (:77) |
| Insel | KitchenSpec.island, eigene origin | gebaut |
| Halbinsel | wie Insel, an Zeile gestoßen | offen |
Abstand Insel zu Zeile ca. 1200: nur Skill-Text, ungeprüft.
Eckregel: Eckschrank schließt Platte ohne Überstand; Folgezeile setzt um Wandlinie versetzt an.
Überlappung zweier Zeilen = Fehler (gebaut, :140).

## Fugen, Versatz
| Maß | Wert | Status |
|---|---|---|
| Frontdicke | 18 | Daten |
| Fuge | 2 | Daten |
| Sockel zurück | 50 | Daten plinthSetback |
| Plattenüberstand vorn/Ende | 20 | Daten overhang |
| Korpusplatte / Rückwand | 19 / 8 | Daten |
Fuge halb je Seite der Front (gebaut, :322).
