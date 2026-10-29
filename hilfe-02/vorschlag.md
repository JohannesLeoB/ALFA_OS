# HILFE-02 · Vorschlag Design-Arbeitsmappen

Stand 29.10.2026. Nur Vorschlag, nichts umgebaut. Ergebnis **ungeprüft**. Grundlage: `bestand.json`, `zuordnung.json`, `code-schnitt.md`.

## 0 · Befund in drei Sätzen

1. **Bestand:** 5593 Dateien mit 2786 verschiedenen Inhalten. 951 Inhalte kommen mehrfach vor (zusammen 3758 Dateien). 2485 Inhalte sind Altmaterial (uploads, ARCHIV, Sicherungen). Es bleiben 301 Arbeitsdateien, davon 50 Bögen.
   - Die ZIP „Interface CHEF 2810“ ist Datei für Datei gleich E1 (1095 von 1095).
   - Die ZIP „Editoren Sketches 1610-3“ ist gleich E2 (693 von 693; ein Dateiname nur anders kodiert).
2. **Die Hülle gibt es heute dreimal, in drei verschiedenen Fassungen.** `ALFA Shell.dc.html`, `alfa-shell.js`, `alfa-theme.css`, `alfa-bausteine.js`, `ALFA Bestaetigen.dc.html` und `TOKENBOGEN.json` haben in E1, E2 und E3 je eine andere Prüfsumme (`bestand.json`).
   - Die Editoren-Bögen laden die Hülle ihres eigenen Ordners: `<dc-import name="ALFA Shell" …>` (`ALFA Atelier.dc.html:15`) und `s.src = "alfa-shell.js"` (`ALFA Atelier.dc.html:224`). Gleich in Aufmass, Konfigurator, Moodboard, Planvergleich und Draws.
   - Die Editoren-Hülle trägt „Export 18.10.2026“, das Theme „Export 19.10.2026“ (`alfa-shell.js:1`, `alfa-theme.css:1` in E2). In E1 steht beim Theme „Export 21.10.2026“ (`alfa-theme.css:1`).
   - Die Regel „Hülle nur einmal“ (`CLAUDE.md:2–4` in E1) gilt heute also nur innerhalb von E1.
3. **Alles erwartet einen flachen Projektstamm.** „Projektstamm = Entwurfsordner. Die Werkzeuge … lesen die Bögen am Stamm; deshalb liegen sie dort.“ (`ETAPPE-2910.md:50`). Ordner je Modul innerhalb eines Design-Projekts brechen die Pfade (Abschnitt 2).

## 1 · Vorschlag: Mappen als Zweige, Stamm bleibt flach

**Begründung aus dem Code-Schnitt:**
- Der Code teilt in Gemeinsames (Design, Texte, `App/Components`, `App/Shell`) und Bereiche (`App/Mail`, `App/Settings`); siehe `code-schnitt.md`.
- Die Design-Werkzeuge lassen keine Unterordner je Bereich zu (Abschnitt 2).
- Deshalb: die Teilung über Git-Zweige im Repo `alfa-design-`, nicht über Ordner. In jedem Zweig liegen die Dateien weiter flach am Stamm.

| Zweig (Vorschlag) | Was hinein gehört (aus `zuordnung.json`) | Braucht von `design/main` | Code-Ziel |
|---|---|---|---|
| `design/main` | Hülle: `ALFA Shell`, `ALFA Bestaetigen`, `alfa-shell.js` · Tokens: `TOKENBOGEN.json`, `alfa-theme.css`, `ALFA Tokenbogen`, `ALFA Designsystem` · Bauteile: `alfa-bausteine.js` · `support.js`, `lieferung-an-code/fonts/` · Vertrag `contract/`, Werkzeuge `contract-build/`, `DESIGN/brief/`, `lieferung-an-code/pruefung.js` · Führung: `CLAUDE.md`, `entscheidungen.md`, `ETAPPE-*.md` | – | `Resources/tokens.json`, `Resources/*.localizable.json`, `App/Components`, `App/Shell`, `Sources/Shell` |
| `design/mail` | `ALFA Mail.dc.html`, `material/icons/mailkonten.svg` | alles aus main | `App/Mail`, `Sources/Mail` |
| `design/settings` | `ALFA Einstellungen.dc.html`; `ALFA Dienste` ist `unklar` (Frage 6) | alles aus main | `App/Settings`, `Sources/Hub` |
| `design/projects` | heute kein Bogen; Brief `01-projekte.md` | alles aus main | Project (reserviert, `ARCHITECTURE.md:54`) |
| `design/workshop` | `ALFA Aufmass`, `Atelier`, `Konfigurator`, `Moodboard`, `Planvergleich`, `Draws`, `alfa-draws.css`, `image-slot.js`, `uebergabe-draws-IN-PROGRESS/`, Briefe `02`–`07` | alles aus main; die eigene E2-Hülle entfällt | ein Modul laut `CLAUDE.md:24`, Name offen (Frage 4) |
| `design/archiv` | Altmaterial (2485 Inhalte), E3 `project/`, E4, v1/v2-Bögen, Entwurf A–D | – | keins |

- **Feature-Zweige** zweigen je Arbeit vom Modulzweig ab, zum Beispiel `design/workshop-aufmass-ebenen`, und gehen in den Modulzweig zurück.
- Änderungen an Hülle, Tokens, Bauteilen und Vertrag gehen nur über `design/main`. Modulzweige holen `main` hinein, ändern sie aber nicht.

**Hülle nur einmal sichern:** In jedem Modulzweig müssen die Dateien aus `main` (Hülle, Tokens, Bauteile, Laufzeit) dieselbe Git-Prüfsumme haben wie in `design/main`.
- Das lässt sich mit `git diff --quiet design/main -- <Datei>` je Datei messen.
- Dafür ist kein neues Werkzeug im Vertrag nötig.

**Lieferung an Code:**
- Heute ist die Lieferung eine Gesamtlieferung mit den Bereichen shell, mail und settings. Sie stehen fest in `contract-build/lauf.js:19` und `contract-build/apply.js:38`.
- Vorschlag: Die Gesamtlieferung kommt weiter aus `design/main` nach dem Zusammenführen der Modulzweige.
- Eine Lieferung je Modul geht erst, wenn `lauf.js` die Bereiche als Parameter nimmt (Frage 10).

## 2 · Folgen und Risiken beim Teilen

| Was bricht bei Unterordnern | Stelle |
|---|---|
| `lauf.js` findet Bögen nur am Stamm: `ls("")`, Filter auf `.dc.html` | `contract-build/lauf.js:17` |
| `lauf.js` liest feste Namen am Stamm: `ALFA Mail`, `Einstellungen`, `Shell`, `Bestaetigen` | `contract-build/lauf.js:18` |
| `lauf.js` liest feste Pfade: `contract/`, `contract-build/previous/2026-10-23T-vor-uebergabe/`, `DESIGN/brief/`, `lieferung-an-code/pruefung.js` | `contract-build/lauf.js:8`, `:16`, `:25`, `:26` |
| `lauf.js` schreibt den Lieferschein über **alle** Bögen am Stamm. Neue Werkstatt-Bögen am Stamm kämen ungefragt in `LIEFERUNG.json` | `contract-build/lauf.js:22` |
| `check-delivery.js` meldet jeden Bogen, der nicht im Lieferschein steht | `contract-build/check-delivery.js:17` |
| `apply.js` liest `TOKENBOGEN.json` und `alfa-theme.css` am Stamm, Bögen mit festen Namen (auch das gelöschte „ALFA PDF“) | `contract-build/apply.js:11`, `:20`, `:37`, `:45` |
| Die Bereiche `shell`, `mail` und `settings` sind fest verdrahtet | `contract-build/lauf.js:19`, `contract-build/apply.js:38` |
| `pruefung.js` erwartet feste Dateilisten am Stamm (APP, BOGEN, DOKU) und `entscheidungen.md` | `lieferung-an-code/pruefung.js:6–8`, `:39` |
| `pruefung.js` verlangt einen Exportvermerk mit Datum vom 18.–31.10.2026; danach wird jeder Lauf rot | `lieferung-an-code/pruefung.js:77–78` |
| Bögen laden die Hülle relativ: `src="alfa-shell.js"`, `load("alfa-bausteine.js")` | `ALFA Mail.dc.html:355–356`, `ALFA Einstellungen.dc.html:208–209`, `ALFA Shell.dc.html:139` (E1) |
| Bögen laden Theme und Schrift relativ: `href="alfa-theme.css"`, `href="lieferung-an-code/fonts/geist.css"`, `src="./support.js"` | z. B. `ALFA Shell.dc.html:7`, `:12`, `:17` (E1) |
| Bögen laden Material relativ: `material/icons/…` | `ALFA Dienste.dc.html:48`, `:56`, `:60`; `ALFA Icon.dc.html:123`; `ALFA Widgets.dc.html:32` |
| Bögen lesen `TOKENBOGEN.json` per `fetch` am Stamm | `ALFA Designsystem.dc.html:89`, `ALFA Tokenbogen.dc.html:30` |
| `<dc-import name="ALFA Shell">`, `name="ALFA Bestaetigen"`, `name="ALFA Mail"` lösen nach Namen auf. Ob Claude Design einen Namen über Ordner oder Projekte hinweg findet, ist **nicht belegt** | `ALFA Mail.dc.html:13`, `:116`; `ALFA Designsystem.dc.html:29` |

**Risiken auch bei Zweigen:**
- **Zusammenführen der Hüllen.** Die Editoren-Bögen sind gegen die E2-Hülle gebaut (242 Zeilen gegenüber 305 in E1; verschiedene Prüfsummen). Mit der E1-Hülle kann sich ihr Aussehen ändern. Das ist nicht geprüft.
- **Schreibweg.** Die Design-Sitzung kann GitHub nur lesen (KALTSTART §0). Wer die Zweige schreibt, ist offen (Frage 1).

## 3 · Schritte eines Umzugs (klein, umkehrbar, nichts davon ausgeführt)

1. Johannes beantwortet die Fragen in Abschnitt 4.
2. Leg `design/main` in `alfa-design-` an, aus E1 ohne `uploads/` und `ARCHIV/`.
   - Prüfung: Die Prüfsummen stimmen mit E1 überein (`bestand.json`).
   - Umkehr: den Zweig löschen.
3. Leg `design/archiv` an: E1 `uploads/` und `ARCHIV/`, E2 `uploads/`, `archiv-1810/` und `export-entwurf-c-2310/`, E3 `project/`, E4.
   - Nur kopieren, nichts löschen; die Quellen bleiben, wie sie sind.
4. Leg `design/mail` und `design/settings` von `design/main` an. Sie bleiben zunächst gleich `main`, weil Mail und Einstellungen schon flach in E1 liegen.
   - Die Teilung ist dort erst eine Namensabsprache: Welche Bögen ändert welcher Zweig?
5. Leg `design/workshop` von `design/main` an und lege die Editoren-Bögen aus E2 dazu. Die E2-Hülle wird nicht übernommen.
   - Dann jeden Bogen einzeln in Claude Design öffnen und gegen das E2-Bild vergleichen; Abweichungen kommen in eine Liste.
   - Umkehr: den Zweig löschen, E2 bleibt unverändert.
6. Führ die Prüfsummen-Regel „Dateien aus main gleich“ (Abschnitt 1) als Teil jeder Lieferung ein.
7. Erst danach und nur auf Johannes' Wort: `lauf.js`, `apply.js` und `pruefung.js` auf Bereiche als Parameter umstellen (über `contract-build/`, nicht von Hand am Vertrag).

## 4 · Fragen an Johannes (vor dem Umzug)

1. Wo lebt das Design künftig: `alfa-design-` oder ein Zweig in `ALFA_OS` (heute `DESIGNCHANNEL`)? Und wer schreibt dorthin, da die Design-Sitzung GitHub nur liest?
2. Mappen als Git-Zweige (Vorschlag), als Unterordner (bricht die Pfade aus Abschnitt 2) oder als eigene Claude-Design-Projekte (das ist der heutige Zustand mit drei Hüllen)?
3. Welche Hülle gilt als die eine: E1 (Etappe I, 29.10.)? Sollen die Editoren-Bögen auf die E1-Hülle umgestellt werden?
4. Wie heißen die Mappen: wie die Code-Module (`mail`, `settings`, `project`, `survey` …) oder deutsch? Wie heißt die Werkstatt, die laut `CLAUDE.md:24` ein Modul ist?
5. Werkstatt als eine Mappe mit allen Editoren (wie `CLAUDE.md:24`) oder eine Mappe je Editor?
6. Wohin gehören `ALFA Dienste`, `ALFA Widgets`, `ALFA Icon`, `ALFA Bausteinbibliothek`, `ALFA Entwurf A–D` und die v1/v2-Bögen: Modul, `main` oder Archiv?
7. Bleibt `uploads/` (E1 516, E2 620, E3 1552 Dateien) im Archiv-Zweig oder außerhalb von Git?
8. Gilt E3 (`alfa-design-` `main`, `project/`) noch, oder ist es ganz Archiv?
9. Ist E4 (Zweig `alfa-draws`) nur Archiv?
10. Lieferung an Code: weiter gesamt aus `main` oder je Modul (braucht eine Änderung an `lauf.js`)?
11. Gibt es weitere Design-Exporte (E5) außer den drei in dieser Sitzung genannten ZIPs? Wenn ja, wo liegen sie?
12. Der Exportvermerk in `pruefung.js` läuft am 31.10.2026 ab (`pruefung.js:78`). Wer stellt ihn um und wann?
