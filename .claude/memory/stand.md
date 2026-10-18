---
name: stand
description: Laufender Stand ALFA_OS am 18.10. 19:05 UTC
metadata:
  type: project
---

- Repo `main` = GitHub; letzter Commit vor diesem Eintrag `541a57a`. LAWS AND ORDERS in `AGENTS.md` (ZIEL gestuft und L1 mit Funktionskarte seit `3df8ccc`, Gedächtnis im Repo seit `f5109e1`).
- Gedächtnis liegt in `.claude/memory/`, der Claude-Ordner des Projekts zeigt per Link dorthin; jede Änderung wird committet und gepusht (L4).
- 12 Strang-Definitionen in `.claude/agents/`: bau-heute, bau-kataloge, bau-mail, bau-projekte, design-bruecke, leser, produkt, pruefer-freund, pruefer-petzer, pruefer-spuerhund, pruefer-waterboarder, sammler.
- Design-Master `ALFA OS Interface CHEF 1610.zip` ist noch nicht nach L7 verarbeitet; `DESIGN/` gibt es noch nicht.
- Arbeitsbaum = GitHub: die 19 App-Dateien vom 17.10. (Nachbau Kartenstapel und Bahnen mit Abkürzungen) sind auf sein Wort vom 18.10. verworfen; nachlesbar nur im Transkript c2a04c8a.
- Bestand gesichert: 27 Zweige `sicherung/*` im Repo `mykilos-Alphabet`; Ruleset „Sichi“ aktiv (gh api, 18.10.).
- Die Zweige des zweiten Entwicklers sind gelöscht, lokal und auf GitHub (18.10.).

Aufträge an die Lead
- Test nach L5 (aus `plan/EIN-TEST.md`, 16.10.): genau eine Testfunktion `testTheWholeApp` in `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift`. Sie startet die App-Zusammenstellung ohne Fenster, mit In-Memory-Datenbank und Attrappen, und spielt ein festes Skript über Hülle, Generatoren, Einstellungen und Mail; das Protokoll wird mit `golden.txt` verglichen. Erst `scripts/mutate.py` gegen die alten Tests, dann der eine Test, bis jeder erkennbare Mutant ihn rot macht; erst danach die alten Tests löschen. Abnahme: 1 Testfunktion, unter 60 s, mindestens 200 Mutanten erkannt oder einzeln begründet.
- Wächter (Johannes 18.10.): GitHub Actions melden, sperren nicht (Build in `dist/`); Codex prüft unangekündigt. Die Lead entwirft beides, Text vorher an Johannes.
- xcodegen erzeugt das Projekt künftig in `dist/`; danach entfällt die Zeile `alfaos/*.xcodeproj/` in `.gitignore`.
- `ausgang/pruefung-48h/` bleibt, bis die Forensik-Sitzung fertig ist; dann entfallen `ausgang/` und die Zeile in `.gitignore`.

Offene Punkte aus dem alten Plan
- C2: Proben für Airtable, ClickUp, Clockodo, sevDesk, Claude, DHL fehlen; `alfaos/Kit/Sources/Hub/Providers/` hat nur Google und IMAP.
- D1: `scripts/lizenzen.txt` ohne GRDB-Zeile.
- N1: Nomenklatur `gestaltung/nomenclature.json` steht auf `proposed`.

Behalten bis zum Abgleich mit CHEF 1610: `AN-DESIGN.md`, `nomenclature.json`, `quarantine.json`, `bundle.*`, `entwurf-4.html`, `schablone.html`, die 2 PNG, `scripts/vertrag_aus_entwurf.py`.

Nächster Schritt: neue Lead-Sitzung; Gespräch über die App im Strang `produkt`.
