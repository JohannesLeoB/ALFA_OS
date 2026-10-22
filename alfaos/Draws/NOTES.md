# Draws · Stand 22.10.2026

Prototyp auf `alfa-draws` (Clone `~/Developer/ALFA_DRAWS`, Konto bergerjohannesleo-dot). Status Orange: kein Design-Master für Draws, keine Abnahme. Gelesen und gebaut nur in `alfaos/Draws`. Lead-Wort 21.10.: Draws schreibt nicht in ALFA-Gedächtnis, AGENTS.md, CLAUDE.md, README, Stränge, `main`.

## Johannes' Wort (wörtlich, Auszug)
- 21.10.: ergänzen statt ersetzen, „VOR der eigentlichen richtigen Zeichenarbeit als Pitch oder Entwurfspräsentation“; „millimetermaße macht dann eh später der Tischler“.
- 21.10.: Maßstufen 1 ohne Maße, 2 nur gegebene, 3 („ca.“) „eher später“.
- 21.10.: „erzeugte blätter bekommen die upload schriften aus den Einstellungen, Fallback ist die ALFA_OS Standardschrift.“
- 21.10.: Claude-Modell aus dem gespeicherten Zugang, kein fest eingetragenes Modell.
- 21.10.: „es ist kein MASTER DRAWS … Orange … was in DRAWS neu und einzigartig ist als PROTOTYP temporär und NICHTS im MAIN CODE“.
- 22.10.: Eingang mit Rollen (Moodboard, Vorlage/Unterlage, Skizze, Linedrawing), Prompts, Presets, Skills → „Entwurfs-Werkstück, das das DRAWING auf dem Canvas wird“.
- 22.10.: „DRAWS hat den SKILL LIVE, es wird IN der APP live gebaut“; Skillset „alfanomy“ aus Anatomy, „motion addon skill“; „teilmechanisch und claude flexibel, mit skillset und nach user Style master gewichtet … Claude in der ALFA_OS als Creative Assistant“.
- 22.10.: Claude-API und Daten „zentral als Integration aus dem Alfa OS Hub/Einstellungen gezapft“, nicht Draws-eigen.
- 22.10.: „DRAWS ist in ALFA_OS, als eine der Funktionsengines der creative cloud, also den Editoren“ (neben Skizze/Atelier, Moodboard, Aufmaß).
- 22.10. zu D2: „NEIN. DRAWS hat eigentlich "kaum was selber an Bord" Weil DRWAS nur ein In App Modul der ALFA_OS wird und sich voll in dessen Infrasturuktur integriert udn die dort über den Hub/Einstellungen gegebenen Integrations, API, Anbindungen, Datenquellen udn Speicher etc versorgt.“ Folge: Pages, Intake, Templates, Assist und die Dock-Ports sind Vorarbeit für die ALFA-Infrastruktur, nicht Draws-eigen; Draws behält Zeichenkern, Werkzeuge für Claude, Skills und Oberfläche.
- 22.10. zur Bedienung: „Ich werde sicherlich keine Json sachen da reinfüttern oder hunderte parameter "coden" - es ist nur eine "visualisiere mir das hier in cool und konsistent" app“; Claude als „creative assistant“ rendert „meine skizzen, irgendwelche Pläne und perspektiv entwürfe, oder eine "claymodell screenshot" raumsituation … mit einem material bündel an texturen oder auch beispielbildern“. „Es geht nicht um Maschinen und fronten offnen“. Ausgabe „eher an PDF udn sekundär erst auch an Kunden, Partner“. „WICHTIG- auch frei und ohne "einladen oder freigeben" muss das Ausgabeformat, wenn es animationen und effekte, viewoptions etc trägt systemunabhängig als Mailanhang zum öffnen mit standard on board Software funktionieren“.

## Module (Commit 53e793c)
| Ziel | Art | Inhalt |
|---|---|---|
| Pages | neutral | Dokument → PDF/SVG/PNG, Musterseiten mit Zonen |
| Intake | neutral | PDF+OCR, Bild, CSV, xlsx, IDML, DXF; DWG nur erkannt |
| Templates | neutral | Mustache mit Meldung unbekannter Variablen, Canvas aus JSON/IDML |
| Assist | neutral | Claude-Werkzeug-Schleife, Skillset, Style Master; Zugang vom Gastmodul |
| DrawingKit | Draws | Modell, Projektion, Ordnung, Maße, Packs, Board, Studio-Blätter, Einheiten/Posen |
| DrawsAI | Draws | Einmal-Entwurf, Live-Werkzeuge (12), Vorbereitung über Intake |
| DrawsDock | Draws | 7 Ports mit lokalen Adaptern, Exportname nach Altcode |
| DrawingDudeApp | Draws | Oberfläche nach Sketch 1610 auf Master-Tokens, Werte sonst in Proto.swift |

Packs: `ci/studio`, `template/studio-a3-plan`, `template/studio-a4-deck` (gemessen), `skills/alfanomy`, `style/studio.json`, `presets/default.json`.

## Specs
- `specs/family.md`: ALFA Creative Family (Editoren, Rückgrat, verbindende Typen, Editor-Vertrag, Reihenfolge, offene Fragen).
- `specs/aufmass.md`: Aufmaß aus Johannes' Bildern und der Altcode-Inventur.
- `specs/hub-needs.md`: was Draws vom Hub braucht (Eingang/Ausgang, FilesPort, Ports, Ereignisse).
- 22.10.: „wir bleiben aber baulich erstmal bei draws“.

## Offen
- Fragen an die Lead (22.10.): Claude-Schlüssel über Hub, Assist als Assistent aller Bereiche, Packs als Bundle oder Einstellungen „Vorlagen“, Ort des Tests, ungenutzte Fähigkeiten behalten, ZIPFoundation in Kit.
- Aufräumen in Draws: Farb-Helfer vereinen, toten Code löschen, Test in Abschnitte je Modul.
- Nie in der echten App oder gegen die echte API geprüft.
- Altcode-Inventur der Editoren läuft; gemeinsamer Editor-Kern noch nicht geschnitten.
