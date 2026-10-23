# Bauteile

Rolle = Pack roles (KORPUS, FRONT, PLATTE, SOCKEL, EINBAU). Ids: `r<Zeile>c<n>…`, Zeilenteile `r<Zeile>w<n>` (Platte), `p<n>` (Sockel).

| Teil | Zweck | Typische Maße (mm) | Modell im Generator | Status |
|---|---|---|---|---|
| Sockel / Blende | Fuß verdecken, Reinigung | Höhe 80, 50 zurück | 1 Quader je Zeile und Tiefengruppe | gebaut (:284) |
| Beine | Höhe einstellen, tragen | 80-150 | nur Metadatum, Sockel deckt | offen |
| Arbeitsplatte | Arbeitsfläche | Dicke 40 (20-60), vorn 20 über | 1 Quader je Gruppe, Enden 20 | gebaut (:275) |
| Platten-Kante | Kantenbild | 2-3 mm | Metadatum | offen |
| Nischenrückwand | Wandschutz | Höhe Platte bis Wand (600), Dicke 4-19 | Quader an Wand | offen |
| Wange / Seitenblende | Zeilenende sichtbar | 19 oder 38, Tiefe wie Korpus | Quader am Zeilenende | offen |
| Passleiste / Passstück | Raumtoleranz zur Wand | 20-100 breit | Quader, Breite = Rest | offen |
| Attika / Blende | Wand bis Decke füllen | Höhe Rest | Quader über Wandzeile | offen |
| Kranzleiste | Oberkante Oberschränke | 40-80 | Quader über Zeile | offen |
| Lichtleiste | Unterkante Oberschränke, Licht | 40-60 | Quader unter Wandzeile | offen |
| Abdeckboden | Oberseite Hoch/Wand | 19 | Quader über Korpus | offen |
| Regalboden | Einlegeboden | 19, Tiefe minus Rückwand | Quader, alle 300 bei Regal | gebaut (:245) |
| Rückwand | Korpus hinten | 8 | Quader, Wandseite | gebaut (:243) |

Regeln
- Jedes Teil ein Part mit Rolle, Gruppe, deutschem Namen; Wortliste aus Pack words.
- Teile in der Zeilengruppe (zeile_unten, zeile_oben) für Ein-/Ausblenden.
- Normaler Schrank ist heute ein Quader (Korpus); Einzelplatten nur bei Offen (gebaut, :234).
