# Schaltschrank ALFA · Werkzeug

Baut die Seite https://claude.ai/artifact/Ns8gc5BrjcepgMMXSBigyG aus dem echten Code.

- `aktualisieren.sh <Arbeitsordner> [--force]`: holt den aktuellen `main` von GitHub, misst mit graphify (aus `~/Developer/SKILLS/TECH/graphify-8.zip`, ohne Sprachmodell), ordnet die Typen Bereichen zu (`bereiche.py`), zählt die Paare (`paare.py`) und baut `alfa-maschine.html` (`build.mjs` mit `live.js` und `page.css`, Zeichen-Kit aus `~/.claude/skills/anatomy`).
- Ohne `--force` bricht es ab, wenn `main` seit dem letzten Lauf im selben Ordner gleich ist.
- Veröffentlicht wird von einer Claude-Sitzung mit dem Artifact-Werkzeug unter derselben Adresse; das Skript selbst veröffentlicht nichts.
