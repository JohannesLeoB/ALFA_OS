# Lastenheft Bemaßung und Plansatz

Status: gebaut (Datei:Zeile in Draws) / teilweise / offen. Stand 23.10. Quelle: Beobachtung echter Entwurfsmappen (Konventionen, keine Kundendaten). Entwurfsstand: einige mm egal, Wände schief. Skill für Claude: `Packs/skills/alfanomy/plans.md`.

## Blatt und Satz
| Nr | Anforderung | Status |
|---|---|---|
| Z-01 | A3 quer, Rahmen, ein Maßstab je Blatt | gebaut template.json:6, 8 |
| Z-02 | Rechte Spalte: Legende (Geräte, Zubehör, Materialien), Schriftfeld unten | gebaut template.json:82, Studio.swift:57 |
| Z-03 | Leere Legendenzeilen bleiben stehen (= offen) | teilweise Column.swift:98 |
| Z-04 | Pflichtsatz: Maße am Bau prüfen | gebaut template.json:150 |
| Z-05 | Hinweisblock: Unstimmigkeiten melden, Höhen auf OKFF | teilweise template.json:185, Spaltenvorlage nutzt ihn nicht |
| Z-06 | Stempel VORABZUG, rot, schräg | gebaut Column.swift:162, template.json:210 |
| Z-07 | Stempel VORPLANUNG als zweiter Stand | offen template.json:211 (nur vorabzug, Text fest) |
| Z-08 | Seitenfolge Deckblatt, Perspektiven, Plan, Ansichten A/B/C, Details, Innenansichten | teilweise Sheet.swift:113 (Zellen, Cover), keine Reihenfolge |
| Z-09 | Perspektiven ohne Maße | gebaut Sheet.swift:90, Board.swift:37 |

## Ansichten
| Nr | Anforderung | Status |
|---|---|---|
| Z-10 | Maßstab 1:20, 1:25 (Küche), 1:10 (Möbel) wählbar | gebaut template.json:31, Board.swift:71 |
| Z-11 | Ansichtstitel mit Maßstab | gebaut Engine.swift:229 |
| Z-12 | Ansichtstitel nach Objekt oder Buchstabe A/B/C | teilweise template.json:39 (nur Ansicht, Grundriss, Seiten) |
| Z-13 | Blickpfeile mit Buchstaben im Grundriss, außerhalb des Körpers | offen |
| Z-14 | Innenansicht: Fronten durch Innenleben ersetzt | offen |

## Bemaßung
| Nr | Anforderung | Status |
|---|---|---|
| Z-20 | Ganze mm ohne Einheit, Text mono, Vertikale gedreht | teilweise Dimensioner.swift:63 (Zehntel möglich), Engine.swift:385 |
| Z-21 | Ticks 45 Grad, keine Pfeilspitzen, kurzer Überstand | gebaut Engine.swift:377 |
| Z-22 | Kette: Einzelmaße plus Gesamt, höchstens 3 Ebenen (Module, Block, Wand) | teilweise Dimensioner.swift:47 (2 Ebenen) |
| Z-23 | Ketten außerhalb des Körpers: Breiten unter der Ansicht, Höhen seitlich | gebaut Engine.swift:240, 247 |
| Z-24 | Höhenkette ab OKFF auf einer Seite | gebaut Engine.swift:235 (Datum 0, links) |
| Z-25 | Marke APL OK an der Plattenoberkante | offen |
| Z-26 | Kleinmaße Blende, Fuge, Füller bleiben stehen (19, 30, 70) | offen Dimensioner.swift:39 (kurze Maße fallen weg) |
| Z-27 | Randmodule mit krummem Maß nehmen die Wandabweichung auf | teilweise KitchenSpec.swift:37 (freie Breite), kein Wand-Ist |
| Z-28 | Aufmaßwerte hellgrau, Planwerte kräftig | offen Packs.swift:161 (eine Maßfarbe) |
| Z-29 | Maßfarbe getrennt von der Geometrie | gebaut Engine.swift:372, Packs.swift:161 |
| Z-30 | Offene Punkte als tbd | offen |
| Z-31 | Magenta-Wolke mit Kurztext an offenen Stellen | offen |
| Z-32 | Nicht bemaßen: Griffe, Steckdosen, Sanitär, Schubladenhöhen, außer auf Wunsch | teilweise Engine.swift:231 (Maße aus allen Teilen, G-27 Griffe offen) |
| Z-33 | Teilkette je Objekt (Zeile, Insel, Hochschrank) statt eine Kette über alles | offen Engine.swift:233 (eine Kette je Ansicht) |

## Beschriftung der Ansicht
| Nr | Anforderung | Status |
|---|---|---|
| Z-40 | Funktionstext je Spalte unter der Breitenkette | teilweise Presentation.swift:37 (Rollenbeschriftung neben der Ansicht) |
| Z-41 | Gerätekürzel im Umriss: KS, GS, BO, KF, TK, KGK, DA | offen KitchenSpec.swift:17 (fünf Geräte, keine Kürzel) |
| Z-42 | Öffnungszeichen: X für Tür und Klappe, V für Schublade, Spitze zu Band oder Griff | offen, Daten Cabinets.swift:298 (Hinge, Slide) |
| Z-43 | PTO an der Front | offen |

## Linienbild
| Nr | Anforderung | Status |
|---|---|---|
| Z-50 | Geschnittene Wand, Decke, Boden: Grauflächen oder 45-Grad-Schraffur | offen |
| Z-51 | Verdecktes gestrichelt (Decke, Unterzug, Sockelrücksprung) | offen |
| Z-52 | Drei Strichstärken: Kontur, Kante, Aufmaß | teilweise Engine.swift:221 (lineEdge), keine Aufmaßstufe |
| Z-53 | Rot nur Stempel und Maße, Magenta nur Wolken | teilweise Column.swift:166 (signal), Engine.swift:372 |

## Stufen
| Nr | Anforderung | Status |
|---|---|---|
| Z-60 | Früh: Perspektiven, grober Plan, wenige Gesamtmaße | teilweise Sheet.swift:161 (Maße an oder aus) |
| Z-61 | Danach: volle Ketten, Funktionstexte, Öffnungszeichen, Varianten | offen |
| Z-62 | Skill plans lädt bei Maßen, Plan oder Schritten | gebaut DrawsModel.swift:831, manifest.json:10 |
