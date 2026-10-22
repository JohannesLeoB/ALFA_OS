# Draws · Stand 22.10.2026

Prototyp auf `alfa-draws` (Clone `~/Developer/ALFA_DRAWS`). Status Orange: kein Design-Master für Draws, keine Abnahme. Nichts davon in `main` ohne Johannes.

## Was Draws ist
- Editor der ALFA Creative Cloud (neben Skizze, Moodboard, Aufmaß). Pitch und Entwurfspräsentation vor der Werkplanung, keine Fertigungsmaße.
- Nutzer zieht Material rein und schreibt einen Satz; keine Parameter, kein JSON.
- Eingang mit Rollen: Skizze, Plan/Unterlage, Perspektiv-Entwurf, Clay-Screenshot, Materialbündel (Texturen), Beispielbilder.
- Claude baut die Szene live im Canvas über Draws-Werkzeuge, Skillset `alfanomy`, gewichtet nach Style-Master; Korrektur per Satz.
- Maße: Stufe 1 keine, Stufe 2 nur gegebene, Stufe 3 („ca.“) später.
- Kein Schwerpunkt auf Mechanik (Fronten, Schubladen öffnen).

## Ausgabe
- Hauptformat PDF nach Vorlage (A3-Plan, A4-Deck); Schriften aus den Einstellungen, Fallback ALFA-Schrift.
- Mit Bewegung oder Ansichtswahl: muss als Mailanhang ohne Einladung und Freigabe mit Bordmitteln aufgehen (HTML-Einzeldatei offline, MP4).

## Abgrenzung zu ALFA
- Draws hat kaum eigene Infrastruktur. Claude-Zugang, Dateien, Vorlagen, Projektdaten, Speicher und Versand kommen über Hub und Einstellungen.
- Pages, Intake, Templates, Assist und die Dock-Ports sind Vorarbeit für Kit/Hub; was übernommen wird, entscheidet Johannes.
- Draws-eigen bleiben: Zeichenkern, Claude-Werkzeuge und Skills, Oberfläche.
- Claude-Modell aus dem gespeicherten Zugang, Schlüssel nur im Hub.

## Module
| Ziel | Art | Inhalt |
|---|---|---|
| Pages | neutral | Dokument → PDF/SVG/PNG/Druck, Musterseiten mit Zonen, interaktives HTML |
| Intake | neutral | PDF+OCR, Bild, CSV, xlsx, IDML, DXF; DWG nur erkannt; zip über `/usr/bin/unzip` |
| Templates | neutral | Mustache mit Meldung unbekannter Variablen, Canvas aus JSON/IDML |
| Assist | neutral | Claude-Werkzeug-Schleife, Skillset, Style Master; Zugang vom Gastmodul |
| DrawingKit | Draws | Modell (Quader, Keil, konisches Bein), Projektion, Ordnung, Maße, Packs, Board, Studio-Blätter, Einheiten/Posen |
| DrawsAI | Draws | Einmal-Entwurf, Live-Werkzeuge (12), Vorbereitung über Intake, Rollen |
| DrawsDock | Draws | 7 Ports mit lokalen Adaptern, Typen feldgleich mit Hub |
| DrawingDudeApp | Draws | Oberfläche nach Sketch 1610 auf Master-Tokens, Werte sonst in Proto.swift |

Packs: `ci/studio`, `template/studio-a3-plan`, `template/studio-a4-deck`, `skills/alfanomy`, `style/studio.json`, `presets/default.json`.

Specs: `specs/family.md` (Creative Family), `specs/aufmass.md` (Aufmaß), `specs/hub-needs.md` (Bedarf am Hub).

## Offen
- Darstellung: gezeichnet aus dem Modell, oder zusätzlich Fotorealismus über einen Bildgenerator (Entscheid Johannes).
- Texturen aus dem Materialbündel auf Flächen.
- Ablauf „reinziehen, ein Satz“ in der Oberfläche.
- MP4-Ausgabe.
- Keil und konisches Bein in den Claude-Werkzeugen.
- Hub-Ports: wer baut, Reihenfolge (offen bei Johannes und Lead).
- Nie gegen die echte Claude-API und nie in der echten App geprüft.
