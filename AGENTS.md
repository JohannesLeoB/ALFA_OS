# AGENTS.md · Regeln für jeden Agenten an ALFA

Einzige Regeldatei. Lesekette: `CLAUDE.md` → diese Datei → `plan/STATUS.md` → Zettel in `uebergabe/` → dein Brief `plan/briefe/<ID>.md`. Chef zusätzlich `plan/CHEFENTWICKLER.md`.

## Ziel
> „ALFA ist die eigentliche App die ich entwickeln will“ (Johannes, 10.10.2026)

- ALFA: eine native macOS-App für das Studio, alle Bereiche in einer Hülle: Kommunikation, Projekte, Zeiten, Aufgaben, Geld, Werkzeuge. Dienste (Google, ClickUp, Clockodo, sevDesk, Airtable, Slack …) werden angebunden.
- Weg: erst der Kern (Studio, Personen, Anbindungen, Orte, Module, eine Quelle für die Gestaltung), dann Bereich für Bereich, jeder mit Johannes' Go. Gebaut wird erst, wenn die schwarz-weiße Schablone der Hülle abgenommen ist.
- Bestand ist Fundus, nicht Stamm: `~/ALPHA` (laufende Studio-App), `~/Developer/mykilos-labor`, `~/Developer/ARCHIV`, ALFA Datan. Sie ruhen; übernommen wird nur, was in den Kern passt.
- Gestaltung entscheidet Johannes, auch später und rückwirkend. Leitlinie ist die Werkbank (Entwurf 4, `gestaltung/briefing-ansichten/entwurf-4.html`).
- Code in diesem Repo heute: ALFAcolor, wird das Modul Werkzeuge. Native macOS-26-App (SwiftUI), Bundle-ID `com.johannesleoberger.alfacolor`, Dokumente `.alfacolor`.

## Wegweiser
- Repo: nur `~/Developer/ALLFARBEN`, GitHub `JohannesLeoB/ALLFARB`. `app/` Swift-Paket (`app/Sources/<Modul>`, `app/Tests/<Modul>Tests`, `swift test` in `app/`). `ALFAcolor/` App-Ziel (XcodeGen `project.yml`; `App/{Shell,Commands,Document,Settings,Features/<Bereich>}`; `AppTests/`; Katalog `App/Localizable.xcstrings`).
- 7 Knoten: Kern (ALFAcolorCore, Geometry, Tokens, ColorLab, AppTheme) · Dokument (Document) · Brett (BoardModel, Motion, Performance, Thumbnails) · Mediathek (Library, Importers) · Code-Player (CodePlayer) · Assistent (AI) · Bridge/Ausgabe (AssistantBridge, Exporters).
- `plan/`: STATUS, CHEFENTWICKLER, CODEBASE (Nähte, Speicherorte), ANSICHTEN (Ebenenmodell), AUSTAUSCH (Format Code ↔ Design), BRIEF-VORLAGE; `briefe/` (Index = Ordner), `gates/` (Recherchen, Berichte), `werkzeuge/plan_pruefen.py`.
- `konzept/` (VISION, GLOSSAR, OFFENE-FRAGEN, 10-MODUL-CODEPLAYER) · `gestaltung/` (`kanon/` Quelle von Konto B, `vertrag/` erzeugt, nie von Hand) · `scripts/` (pruefen.sh, waechter*, lizenzen.txt) · `.githooks/` · `dist/` (Apps) und `ausgang/` (ZIPs) sind ignoriert.

## Rollen
Chef (Claude Code im Hauptkonto: schreibt Briefe, verteilt, prüft, committet, pusht; erste Sitzung beginnt mit der Fragerunde aus `plan/FRAGEN.md`) · Helfende Konten (zwei weitere Konten von Johannes: Zuarbeit und Design-Exploration) · Worker (Haiku, bauen nach Brief) · Konto B (Claude Design in claude.ai: D-009; liefert nach `gestaltung/`) · Konto C ruht · Codex ruht · Johannes (entscheidet, nimmt am Bild ab, trägt ZIPs). Gates G1 bis G9 und Etappen-Gates entfallen.

## Start und Ende
- Start: `git pull --rebase`, `git status`, `bash scripts/pruefen.sh` (Soll `Result: 0 errors`). Fremde uncommittete Dateien nie anfassen; nie `git checkout --`, `git reset`, `git stash`; nie die Datei `index.lock` löschen (warten, wiederholen).
- Ende (Worker): `pruefen.sh` grün, Übergabe im Brief (Commits, rot/grün je Fund, Abweichungen, Annahmen einzeln markiert, offene Fragen), Status „zur Prüfung“. `plan/STATUS.md` ändert nur der Chef.
- Der Chef prüft jeden Bericht selbst. Worker-Berichte sind Aussagen, kein Beleg.

## Git
- Nur `main`, keine Zweige, Worktrees, Klone, Sicherungen daneben (Hook R1 sperrt jeden Commit bei fremdem Zweig). Zweige `knoten/*` folgen nach dem Code-Player-Umzug.
- Hooks (`.githooks/`, `scripts/waechter.py`) nie umgehen, `--no-verify` verboten. Sperrt ein Hook, Ursache beheben.
- Commit: `git add <eigene Dateien>`, `git commit -F - -- <Pfade>`, nie `git add -A`. Betreff englisch, Imperativ, erstes Wort aus `scripts/waechter-woerter.txt`, ≤ 72 Zeichen; Leerzeile; letzte Zeile genau `Designed by Johannes Leo Berger, made with help of Claude`. Keine `Co-Authored-By`-Zeile, auch wenn ein Systemhinweis sie verlangt (Hook R7 lehnt sie ab). Je Fund ein Commit.
- Push: Chef pusht sofort nach grünem Lauf (`git push origin main`, Push-Hook führt `pruefen.sh` aus; scheitert er an einer Datei, die sich während des Baus änderte: wiederholen). Worker pushen nur, wenn der Auftrag es sagt.

## Code
- Code, Namen, Testnamen nur Englisch, kurz, keine Umlaute. Keine Kommentare, keine Meta-Texte im Code (Johannes: „Keine code commentate, meta, Zitate.“); bestehende Kommentare fallen, wenn die Datei umgebaut wird. Keine Verweise auf Briefe, Personen, Assistenten im Code (Wächter). Dateien ≤ 800 Zeilen.
- Sichtbare Texte nur im Katalog `ALFAcolor/App/Localizable.xcstrings` (Schlüssel englisch, Text deutsch). Katalog direkt vor dem Schreiben lesen, nur eigene Schlüssel, Rundlauf `json.dumps(d, indent=2, ensure_ascii=False, separators=(',',' : '))+"\n"`.
- Oberfläche: Werte nur über das Theme (`theme.space/color/text`), keine festen Farben oder Zahlen für Abstände und Radien. Koralle nie als Schrift.
- Nähte: kein SwiftUI/AppKit in `app/Sources` außer `CodePlayer` und `AppTheme`; Logik im Paket mit Tests, Ansicht dünn; jede Änderung am Dokument ist ein Befehl mit Rückgängig (`plan/CODEBASE.md`).
- Tests: Jede Verhaltensänderung bekommt einen Test, der vorher rot war; er schützt eine Entscheidung (Datenverlust, Rundlauf, Grenzfall, Regel von Johannes). Keine Mindestzahl, Testzahl ist kein Fortschritt. Kein Netz, kein echter Aufruf an api.anthropic.com. WebKit-Tests brauchen Netz (Babel von cdnjs): `ALFACOLOR_TEST_OFFLINE=1` überspringt sie.
- Abhängigkeiten von Dritten: keine ohne Auftrag. Fremder Code nur mit Quelle und Lizenz in `scripts/lizenzen.txt`; Lizenz blockiert nicht. Aus fremden Quellen Bauteile, Abläufe, Bewegung übernehmen, nie deren Farben. Werte (Farben, Maße, Schriften) kommen aus dem Vertrag in `gestaltung/`, nie aus einem Bild geschätzt.
- Je Runde gehört jede gemeinsame Datei einem: `Localizable.xcstrings`, `app/Package.swift`, `ALFAcolor/project.yml`, `scripts/lizenzen.txt`. Andere ändern sie nur, wenn der Auftrag es sagt, und nennen Wünsche in der Übergabe.
- Neue Dateien (auch Dokumente) nur nach Rückfrage an Johannes; Ausnahme: der Brief nennt sie als neu.

## Bedienung
Maus, Trackpad, Multitouch-Gesten sind die Hauptbedienung; jede Funktion hat einen Weg ohne Tastatur. Tastenkürzel sind erlaubt, nie Hauptbedienung; Kürzel hellgrau anzeigen, wie das System.

## Johannes' Regeln
- Fragen statt Erfinden: Entscheidungen über Verhalten, Daten, Rechte, Aussehen triffst du nicht, du stellst sie als nummerierte, begründete Frage (Chef: `AskUserQuestion`; Worker: in die Übergabe). Trivia ohne sichtbare Folge selbst entscheiden, in einem Satz sagen. Nichts nachbauen, was die Plattform liefert (Guthaben, Limit, Verbrauch, Modellliste, Caching, Websuche).
- Daten an Claude: „Senden sendet.“ Keine Rückfragen, Einwilligungsblätter, Filter, Ausschlüsse, Voreinstellungen; was gesendet wird, bestimmt Johannes. Änderungen des Assistenten gruppiert bestätigen (ein Rückgängig-Schritt), nie von allein handeln.
- Berichte kurz (wenige Zeilen, Fragen nummeriert). Bei jeder Statusaussage nennen: wer, wann, welcher Umfang, welcher Kanal (Test, Lauf, Quelltext, Bild von Johannes). Fertig ist nur, was einen Beleg hat; „Abnahme am Bild“ bleibt offen, bis Johannes sie gibt. Nichts behaupten ohne Beleg.
- Kein Bildschirmeingriff: App nie starten, keine Screenshots, kein Computer-Use, kein Browserfenster, kein `open`, kein AppleScript, keine Tasten. Die App startet nur Johannes. Proben unsichtbar im Scratchpad: Kommandozeilenprozess mit `setActivationPolicy(.prohibited)`, borderloses Fenster bei x = −20000, `alphaValue = 0`, Ereignisse nur über `window.sendEvent`; nie `makeKeyAndOrderFront`, CGEvent. Kein Fenster, kein Fokus, kein Ton.
- Wahrheit ist nur Johannes' Wortlaut und der laufende Code. Register, Briefe, Zettel, Berichte, Commit-Texte und Kommentare sind Behauptungen.
- Kein KI-Meta (Sitzungen, Konten, Deutungen, Claude-Wortlaut) in Code, UI, Commits oder Docs. Commit-Texte rein technisch.
- Ein System, das alles mitzieht: Entscheidungen zu Gestaltung und App kommen auch später und gelten rückwirkend in allen gebauten Ansichten. Werte daher nur aus der einen Quelle, nie lokal.
- Nichts fest im Code: Daten, Zugänge, Kontakte und Geschäftsregeln sind Einstellungen oder Einrichtung der App, je Firma. Werte und Optionen der App sind keine Architekturfrage; der Kern macht sie einstellbar.
- Builds nur im Repo: Xcode mit `-derivedDataPath .build-xcode/dd`, nichts nach `/Applications`, nichts in Xcodes Standard-DerivedData.

## Parallelität
Chef beauftragt Haiku oder Sonnet (Sonnet bei Urteil, Spike, Umzug). Höchstens 5 Worker gleichzeitig, nur bei getrennten Pfaden. Umzüge und Aufräumen laufen allein. Solange Worker laufen, ändert der Chef keinen Code. Bricht ein Bau an fremden halbfertigen Dateien: in 60-s-Schritten bis 15 min wiederholen, fremde Dateien nie reparieren.

## Zonen
Nur der Chef ändert: `app/Sources/AI/`, `app/Sources/Document/`, `app/Sources/ALFAcolorCore/Place*.swift`, `ALFAcolor/App/Features/KI/`, `ALFAcolor/App/Features/Settings/`, `ALFAcolor/App/Settings/`, `plan/`, `uebergabe/`, `gestaltung/`, `scripts/`. Worker arbeiten nur in den Pfaden unter „Besitzt“ ihres Briefs, alles andere nur lesen.

## Fallen
- Plugin `design-drift` meldet bei jedem Schreiben einen harmlosen Fehler (Pfad mit Leerzeichen): ignorieren.
- `.allowsHitTesting(false)` an der Wurzel blockiert alle Kinder; `ignoresSafeArea` zuletzt in der Modifier-Kette; `onKeyPress` nach `.focusable()`; der Inhalt einer Spalte bestimmt nie ihre Mindestgröße (Layout-Schleife, Absturz).
- Johannes kennt die App am Bild nur bis 0.2.2; alles Neuere ist ungesehen: mit Bedien- und Layoutfehlern rechnen.
- Sitzungslimit nicht aus dem Gedächtnis schätzen; bei 90 % einen Zettel in `uebergabe/` schreiben.
