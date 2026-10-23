# Lastenheft Generator (Stufe 1)

Status: gebaut (Datei:Zeile) / Daten / offen. Stand 23.10.

## Eingabe und Standards
| Nr | Anforderung | Status |
|---|---|---|
| G-01 | Eingabe KitchenSpec: runs[], island, worktop, plinth, wall, prefix | gebaut KitchenSpec.swift:71 |
| G-02 | Schrank: kind, width, height, depth, fronts, material, frontMaterial | gebaut KitchenSpec.swift:35 |
| G-03 | Standards aus Pack presets/carcass.json, nie im Code | gebaut Cabinets.swift:112, Daten |
| G-04 | Freie Maße: jede positive endliche Größe gilt; Raster füllt nur Auslassungen | gebaut Cabinets.swift:106 |
| G-05 | Zeilen: origin + turn; ohne origin setzt die Zeile am Eckschrank an | gebaut Cabinets.swift:77 |
| G-06 | Insel als eigene Zeile | gebaut Cabinets.swift:69 |
| G-07 | Aufsatzschrank sitzt auf tragendem Vorgänger | gebaut Cabinets.swift:119 |

## Prüfung (nur physikalische Fehler)
| Nr | Anforderung | Status |
|---|---|---|
| G-10 | Fehler: leer, Drehung, Anschluss, Größe, Wirt, unbekannt, Teilung, Passung, Überlappung | gebaut KitchenSpec.swift:114 |
| G-11 | Kein Fehler für Norm-Abweichung (Breite, Platte, Abstand) | gebaut |
| G-12 | Wandabstand unter 560 als Hinweis, nicht Fehler | offen |
| G-13 | Meldungen deutsch, mit Id des Schranks | Daten (DraftEdit englisch), offen |

## Ausgabe
| Nr | Anforderung | Status |
|---|---|---|
| G-20 | Parts mit Id, deutschem Namen, Rolle, Gruppe, Material | gebaut Cabinets.swift:212 |
| G-21 | Stabile Ids: `r<Zeile>c<n>` Korpus, `f<n>` Front, `u<n>` Unit, `w`/`p` Platte/Sockel, `i<n>` Einlass | gebaut Cabinets.swift:15 |
| G-22 | Units je Front: Tür Hinge, Klappe Hinge, Schublade Slide | gebaut Cabinets.swift:298 |
| G-23 | Neuaufbau ersetzt alle Parts/Units mit gleichem prefix | gebaut DraftEdit.swift:112 |
| G-24 | Gruppen zeile_unten, zeile_oben (+Zeilennummer) | gebaut Cabinets.swift:209 |
| G-25 | Materialliste der Küche zurück | gebaut Cabinets.swift:101 |
| G-26 | Unter-Korpus als ein Quader; Einzelplatten nur bei Offen | gebaut Cabinets.swift:234 |
| G-27 | Griffe, Blenden, Leisten, Wangen, Nischenrückwand | offen (bauteile.md) |

## Bearbeiten
| Nr | Anforderung | Status |
|---|---|---|
| G-30 | Doppelklick im Canvas auf Schrank öffnet Maß- und Fronteingabe | gebaut Editing.swift:29 |
| G-31 | Änderung baut nur diesen Schrank neu; Nachbarn rücken (Cursor addiert Breiten) | gebaut Editing.swift:58 |
| G-32 | Teile mit Handänderung (given) bleiben unberührt | offen |
| G-33 | Rückgängig je Eingabe | offen |

## Datei und Werkzeug
| Nr | Anforderung | Status |
|---|---|---|
| G-40 | Spec im SVG-Arbeitsfile als Doc.kitchen | gebaut Doc.swift:155 |
| G-41 | Claude-Werkzeug add_kitchen mit Schema und Rückgabe (Zahlen, Zeilenlängen, Materialien) | gebaut DrawsTools.swift:65 |
| G-42 | Skill cabinetclaude als Raster für Claude | Daten Packs/skills/cabinetclaude/ |
| G-43 | Werkzeug edit_kitchen (einen Schrank ändern) | offen |
| G-44 | Test je Anforderung mit Mutant | offen |
