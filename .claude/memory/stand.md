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
- Figma-Spiegel (L1-Ausnahme seit 0ad6013, Johannes 18.10.: „probe auf starter, wenn wir an limits stoßen, sag bescheid. In L1 freigeben“): Team ALFA (team::1690866401587157051, Starter, View-Platz). Probedatei „ALFA Verlauf · Mail“ (fileKey qIrCnMnRZZl5Fazm4Q7CbT), Seite „Verlauf“, Zeile „Mail · 18.10.2026“ mit Bild aus Master handoff 1810 (kopfloser Chrome, Profil dist/chrome-profile, 1512 × 982, hell, Ausgangszustand). Aufrufe bisher: whoami 1, create_new_file 1, use_figma 2, upload_assets 1; kein Limit getroffen. Strang und Automatik noch nicht freigegeben.
- Johannes 18.10.: DTCG nutzen; Master zieht mit Datum immer mit; Code baut, meldet Funktionslücken, Bedarfe, Fehler; Design liefert nach; dann weitere Bereiche nach Schema. Unter der UI alles englisch, ASD-STE100; UI-Texte zentral als Sprachsystem DE/EN umschaltbar.
- Strang figma-spiegel eingetragen (14821b7), Wortlaut wie freigegeben; die Zeile tools nennt Figma-Werkzeuge nicht mit ihren echten Namen (mcp__…), ob der Strang sie bekommt, ist ungeprüft.
- Schemas (19.10., nur dist/schemas/, nicht im Repo): alfa.tokens.schema.json (DTCG 2025.10, ALFA-Profil: $type je Token, $extensions.alfa mit status oder source, srgb, px, ms), alfa.resolver.schema.json (Set base, Modifier theme light/dark), components.schema.json, views.schema.json, texts.schema.json, validate.py (ohne Fremdpaket). Beispiele gültig, 11 Mutationen werden erkannt. TOKENBOGEN.json aus Master 1810 gegen Schema: nach Johannes' Regel „kein mykilos“ (19.10.) Namensraum alfa: 297 Fehler, davon rund 100 deutsche Statuswerte und 189 Tokens ohne status oder source; sonst component ohne $value (12), surface (5), stack (2), Metafelder export/paket, mood-Farben, confirm.tooltip.
- Entscheidungen Johannes 19.10. (Fragerunde): Kachelhöhe Integrationen „112“. Mehrere Mail-Konten: „Design muss liefern, bitte "temporärbauteil" vorsehen udn Design um Nachlieferung erreichen. Tendenziell "wähler" aber checke auch ncohmal die designs!“ (Befund: Master 1810 zeigt in Mail nur ein Postfach im Kopf, ALFA Mail.dc.html:818; Konten-Liste nur in Einstellungen, :737, :1045; kein Wähler). Brief an Design „Mit T8 als v7“. Regel kein myk in AGENTS.md L8 und den vier Bau-Strängen (15f5f58).
- Entscheidungen Johannes 19.10. (zweite Fragerunde): Fokusring-Abstand „Design entscheidet“; Kartei „Beide als Einstellung“ (8a gestaffelt und 8b Turm, Vorgabe 8a); Firmendaten und Impressum „Nutzer trägt ein“; mit Design geklärte Lücken: „Nein, alle offen“. Brief v7 in dist/bruecke/prompt-an-design-v7.txt (T1 bis T8, Änderungskanal changes.json mit diff_contract.py).
- Bauaufträge 19.10. verteilt (Johannes: „Verteile das bitte in sub sessions mit klarem start-stop task und ziel check“): a myk aus dem Code (Sitzung alfa-a-myk), c Generatoren lesen DESIGN/ (alfa-c-generatoren); b Hülle-Mängel nach c, d ein Test (L5) nach a, b, c. Grenze je Sitzung 400.000 Token.
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
