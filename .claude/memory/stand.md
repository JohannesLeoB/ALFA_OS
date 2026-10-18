---
name: stand
description: Laufender Stand ALFA_OS am 18.10. 20:00 UTC
metadata:
  type: project
---

- Repo `main` = GitHub; letzter Commit vor diesem Eintrag `541a57a`. LAWS AND ORDERS in `AGENTS.md` (ZIEL gestuft und L1 mit Funktionskarte seit `3df8ccc`, Gedächtnis im Repo seit `f5109e1`).
- Gedächtnis liegt in `.claude/memory/`, der Claude-Ordner des Projekts zeigt per Link dorthin; jede Änderung wird committet und gepusht (L4).
- 12 Strang-Definitionen in `.claude/agents/`: bau-heute, bau-kataloge, bau-mail, bau-projekte, design-bruecke, leser, produkt, pruefer-freund, pruefer-petzer, pruefer-spuerhund, pruefer-waterboarder, sammler.
- `DESIGN/` (Commit a59341a, 18.10.): Original-ZIPs plus `MANIFEST.json` (Prüfsummen, Dateiliste je ZIP); entpackt wird nur in `dist/`. Letzter Master: `ALFA OS Interface CHEF 1610-handoff 1810.zip` (109 Dateien, 341 Tokens, noch nicht final poliert, ABNAHME.md 12 Kriterien offen). Vorletzter: `ALFA OS Interface CHEF 1610.zip` (245 Tokens). Johannes 18.10.: „Ja. Lege beide Master als Original-ZIP mit MANIFEST.json in DESIGN/ ab, entpackt wird nur in dist/.“
- Im letzten Master gezeichnet: nur Mail und Einstellungen. Projekte, Heute, Kataloge, Warenkorb: kein Bogen (nur Textlisten in INHALT.json). Es fehlen `bauteile.json` und `mechanik.json` (von Design angekündigt). Widersprüche im Export: RUECKGABE-AN-CODE.md:14 (329/67 Tokens) gegen akte.json (341/78); Byte-Angaben in akte.json falsch.
- Design-Projekt (Johannes' Link, 18.10. ca. 22:40 MESZ, nur gelesen, Anmeldung durch Johannes im App-Browser): läuft weiter und ist dem Export 1810 (21:37) voraus: 352 Tokens statt 341 (neu u. a. scale.pressTile 0,98, size.scrollEdgeHeight 16); nach dem Export u. a. Kacheln ohne Kante, Menübreiten im 56er-Raster, Doppelklick auf gefaltete Bahn = Ruhebreite, Scroll-Kante statt Haarlinie, Toast 8 über Kartenfuß, Assistent im Blob-Kopf (Orb Vorgabe), Johannes „600 übrnehmen.“ (Schnitt semibold). Dateien im Projekt: kein bauteile.json, mechanik.json, texte.json, ansichten/, AUDIT-BERICHT.md. Offene Fragen von Design an Johannes: Kachelhöhe 112 oder 96; Fokusring-Abstand 2 oder 1. Design-Sitzung läuft mit Sonnet 5.5 High. Gilt als Master nur ein neuer Export im Chat (L7).
- Brücke Lauf 1 (dist/bruecke/, 18.10.): Lückenliste hat falsche Belege (Haiku-Prüfung); Berichtigung vor jedem Prompt an Design nötig; Johannes 18.10.: „Der neueste Design export ist immer der geltende. er muss nur vollständig sein.“ und was im Design fehlt, formuliert der Code als Funktions-Spec und Baubedarf.
- Commit-Regeln des Repos: Betreff höchstens 72 Zeichen, letzte Zeile „Designed by Johannes Leo Berger, made with help of Claude“, kein Co-Authored-By.
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

Behalten bis zum Abgleich mit dem letzten Master: `AN-DESIGN.md`, `nomenclature.json`, `quarantine.json`, `bundle.*`, `entwurf-4.html`, `schablone.html`, die 2 PNG, `scripts/vertrag_aus_entwurf.py`.

Offen, wartet auf Johannes' Wort: Wortlaut für `design-bruecke.md` (Datenformat, Generatoren mit --check, Abdeckungsliste, Vergleich zum Vorletzten, Lückenliste mit Rückschein und festen Nummern); Reife, ab der gebaut wird (freigegeben/freigabe-orange oder auch von-design-gesetzt); ob audit_swift aus dem Skill design-zu-swift auf Design.* angepasst nach scripts/ kommt. Gebaut wird nichts.
Danach: Aufträge unten (Test, Wächter, xcodegen, ausgang).
