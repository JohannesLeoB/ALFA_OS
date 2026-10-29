# Memo · Farbleiter (Exploration)

Stand 21.10.2026. Für jede spätere Design-Sitzung.

## Status
**Exploration. Ruht. Export gesperrt bis auf Widerruf. Nicht baurelevant.**
Nichts davon steht in `TOKENBOGEN.json`, `alfa-theme.css`, den Bögen oder `lieferung-an-code/`. Code übernimmt nichts daraus (Johannes 21.10.: „ist erstmal bis auf Widerruf export gesperrt und auch nicht baurelevant z.Z.“).
Aufheben darf nur Johannes, ausdrücklich.

## Wo
- `ALFA Farbleiter.dc.html` (Entwurf, mit Hinweisleiste oben)
- Einträge in `lieferung-an-code/decisions.json`: `kontrastAufloesen`, `farbpaletteVorgabe`, `farbpaletteFavorit`, `farbpaletteOhneBlau`, `glasNeutralKeineVollfarbButtons`, `farbprobeEtablierteWerte`, `farbleiterExplorationRuht`
- Zeilen in `entscheidungen.md`, 20. und 21.10.2026
- Quellmaterial von Johannes in `uploads/`: `ALFA FARBENum 17.19.39.png` (Muster UB), `1.jpg`, `2.jpg`, `6.jpg`, `7.jpg`; Figma „macOS 27 (Community).fig“ (nur gelesen, nichts übernommen)

## Auftrag von Johannes (Wortlaut, 20./21.10.)
- Der harte Schwarz-Weiß-Kontrast ist „augenfeindlich“. Der schwarze Token (`inverse`, auf der Marke „Mail“) und alle ähnlich harten Töne sollen weg.
- Tokenfarben auf eine Leiter von Weiß über Grau bis Schwarz bringen.
- Höchstens 4 bis 6 Boldfarben, matt, kräftig, in sich komplementär und signalisierend. Sonst die Leiter, abgestuft nach macOS-26-Richtlinien oder Best of Industry.
- Initial ohne Blau.
- An Schrift, Inhalte, Überlagerungen und Liquid Glass denken.
- Liquid Glass ist nicht selbst farbig.
- Keine vollfarbigen Knöpfe auf neutralen Flächen.
- Etablierte Werte beachten: Radien, Platzierung, Maße.

## Stand der Entwürfe
- **Runde 1 (verworfen, enthält Blau):** 1a Barragán warm, 1b Dämmerung kühl. 1b nannte Johannes „schön“, dann kam „ohne Blau“.
- **Runde 2 (ohne Blau, offen, keine Wahl):**
  - 2a Erde · Oxblut: #420f0e, #7e2b33, #9c3e17, #c58a00, #bc927a
  - 2b Zypresse · Terrakotta: #263e16, #71382d, #955341, #b36924, #ccae72
  - 2c Mauve · Kakao: #76453c, #7e2b33, #9c3e17, #b36924, #a08e9c
- **Neutrale Leiter** (im Entwurf, Stufen 0 bis 1000): #ffffff, #f2f2f7, #e5e5ea, #d1d1d6, #c7c7cc, #aeaeb2, #8e8e93, #636366, #48484a, #3a3a3c, #2c2c2e, #1c1c1e, #000000. Das sind Werte nach meiner Kenntnis der Apple-Systemgrautöne, nicht aus dem Figma gelesen.
- Die Hex der Farben sind aus den Bildern gemessen (Mittelwert 6 × 6 px).
- Glasprobe: `surface.glass` aus `TOKENBOGEN.json`, Radius 20, Bahn 280, Rand 16, Kopf 44, Zeile 88, Marke 28, Knöpfe 28. Fülltöne geschätzt: hell rgba(255,255,255,.75) (`--c-glaze`), dunkel rgba(20,20,20,.62) (nicht belegt).

## Offen
- Wahl 2a, 2b oder 2c, oder eine neue Runde.
- Rolle des fünften Tons (Haut, Sand, Mauve) ist offen.
- Dunkler Modus nicht entworfen.
- Rolle der Farben ist nur Vorschlag: tiefe Blockfarbe, Auswahl und Fokus, Fehler, Warnung, Akzent.
- Ob die Leiter Linien und Hover einschließt, hat Johannes nicht gesagt.
- Ocker (#c58a00) liegt bei Ringen auf Weiß knapp unter 3:1.
- Kontrastuntergrenze: Text 4,5:1, laut `KONTRAST-PROTOKOLL.md`.
- Lavendel/Mauve/Haut/Sand haben keine Aufgabe in der Oberfläche.

## Wiederaufnahme (nur nach Widerruf)
1. Johannes fragen: Freigabe aufgehoben? Welche Palette?
2. Erst dann: `TOKENBOGEN.json` (`color.*`), `alfa-theme.css`, `ALFA Tokenbogen.dc.html`, alle Bögen.
3. Danach `contract/` neu erzeugen und die Übergabe-Dateien aktualisieren.
4. Alle neuen Werte gegen `KONTRAST-PROTOKOLL.md` prüfen.
5. Jede Entscheidung von Johannes zugleich in `decisions.json` und `entscheidungen.md` eintragen.
