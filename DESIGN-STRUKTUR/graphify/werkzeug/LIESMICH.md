# Werkbank ALFA · Werkzeug

Baut die Seite https://claude.ai/artifact/Ns8gc5BrjcepgMMXSBigyG aus dem echten Code und dem Design-Vertrag.

- `aktualisieren.sh <Arbeitsordner> [--force]`: holt den aktuellen `main` und `DESIGNCHANNEL` von GitHub, misst den Swift-Code mit graphify (aus `~/Developer/SKILLS/TECH/graphify-8.zip`, ohne Sprachmodell) und baut `alfa-maschine.html`.
- `model.py`: Module aus `Package.swift` (Ziele) und `App/<Ordner>` (gleichnamig = Teil des Moduls, sonst eigenes Ansichts-Modul), Tiefe aus den Abhängigkeiten, Typ-Paare über Modulgrenzen. Design: Bögen aus Etappe I und II, Vertrag aus `contract/` (Texte per Schlüssel oder deutschem Wortlaut im Code-Katalog und wörtlich im Swift-Code; Bauteile per gleichnamigem Swift-Typ; Tokens per Namen in `Tokens.…`, `Colors.…` usw.).
- `build.mjs` mit `live.js` und `page.css`: Zeichnung mit dem Kit aus `~/.claude/skills/anatomy`. Gezeichnet werden Code-Leitungen ab 8 und Design-Leitungen ab 5 Einträgen; alle stehen in der Detailansicht.
- Ein neues Modul im Code erscheint ohne Änderung am Werkzeug.
