# AGENTS.md · Regeln für jeden Agenten an ALFA

Einzige Regeldatei. Lesekette: `CLAUDE.md` → diese Datei → `plan/STATUS.md` → Zettel in `uebergabe/` → offene Issues im Ticker → dein Brief `plan/briefe/<ID>.md`. Chef zusätzlich `plan/CHEFENTWICKLER.md`.

## Ziel
> „ALFA ist die eigentliche App die ich entwickeln will“ (Johannes, 10.10.2026)

- ALFA_OS: eine native macOS-App für das Studio, gebaut wie ein Betriebssystem mit vielen Apps (Johannes: „Ich will EINE app die aber modular und als "OS" wie ein Betriebbsystem mit vielen "APPs" ist.“). Ein Kern, darauf Apps: Module, Ansichtsbereiche, Packs, Add-ons und Integrationen über Schnittstellen; alle gleich gestaltet und doch eigen. Apps werden im OS eingeschaltet, nachgeladen und je Person und Firma gewählt. Sie zeigen sich in einer Hülle (Blob-Menü), später auch als lösbare Fenster.
- Apps und Bereiche: Kommunikation, Projekte, Zeiten, Aufgaben, Geld, Werkzeuge; dazu Aufmaß und Konfigurator, Kataloge und Kalkulation, Papers und Vorlagen, Versand und Etiketten; Dienste als Connectors (Google, ClickUp, Clockodo, sevDesk, Airtable, Slack …). Entscheidung Johannes, 10.10.2026.
- Entscheidungen Johannes, 11.10.2026: Rollen sind Einstellung je Firma (Kern kennt Rechte je Fähigkeit; Vorbelegung Admin, Team). Eine Person je Mac, Firma gibt die Einrichtung vor. Ein Dienst gilt erst nach erfolgreicher Probe beim Anbieter als verbunden. Wahrheit je Datenart einstellbar, Standard: der Dienst. ALFA_OS beginnt leer und lädt aus den Diensten; alte ALPHA-Daten bleiben Fundus. Abgleich bei offener App mit Warteschlange, Hintergrund, Auswahl je Dienst und Intervall als Optionen. Freigaben, Sperren, Vier-Augen sind Einstellungen je Integration, Person, Team, Firma, nie im Modul.
- Weg (Johannes, 11.10.2026): Kern neu, tragende Teile aus dem Fundus einzeln geprüft und mit Herkunft einziehen. Zuerst Einstellungen als Kern, dann Mail als erster angebundener Bereich. Gestaltung: eine Quelle, zwei Ausgaben (SwiftUI für die App, Web-Bausteine für Claude Design über `/design-sync`). Zuerst das eigene Studio, aber gebaut für andere Studios. Oberfläche deutsch aus dem Katalog. Freigabe in ganzen Etappen; Abnahme mit Bau in `dist/` und kurzer Klickliste im Issue, bei Etappen, Notfall oder drohender Drift auch Bildschirmfotos von Johannes auf Nachfrage; nachfragen und bohren ist erwünscht.
- Weg: erst der Kern (Studio, Personen, Anbindungen, Orte, Module, eine Quelle für die Gestaltung), dann Bereich für Bereich, jeder mit Johannes' Go. Gebaut wird erst, wenn die schwarz-weiße Schablone der Hülle abgenommen ist.
- Bestand ist Fundus, nicht Stamm: `~/ALPHA` (laufende Studio-App), `~/Developer/mykilos-labor`, `~/Developer/ARCHIV`, ALFA Datan. Sie ruhen; übernommen wird nur, was in den Kern passt. Nie lesen, nie verwenden (Johannes, 10.10.2026): die Zweige `daniel/*` und das Repo `mykilos-diverses`.
- Gestaltung entscheidet Johannes, auch später und rückwirkend. Leitlinie ist die Werkbank (Entwurf 4, `gestaltung/briefing-ansichten/entwurf-4.html`).
- Code in diesem Repo heute: ALFAcolor, wird das Modul Werkzeuge. Native macOS-26-App (SwiftUI), Bundle-ID `com.johannesleoberger.alfacolor`, Dokumente `.alfacolor`.

## Wegweiser
- Repo: nur `~/Developer/ALFA_OS`, GitHub `JohannesLeoB/ALFA_OS` (bis 10.10.2026 `ALLFARBEN` und `ALLFARB`). `app/` Swift-Paket (`app/Sources/<Modul>`, `app/Tests/<Modul>Tests`, `swift test` in `app/`). `ALFAcolor/` App-Ziel (XcodeGen `project.yml`; `App/{Shell,Commands,Document,Settings,Features/<Bereich>}`; `AppTests/`; Katalog `App/Localizable.xcstrings`).
- 7 Knoten: Kern (ALFAcolorCore, Geometry, Tokens, ColorLab, AppTheme) · Dokument (Document) · Brett (BoardModel, Motion, Performance, Thumbnails) · Mediathek (Library, Importers) · Code-Player (CodePlayer) · Assistent (AI) · Bridge/Ausgabe (AssistantBridge, Exporters).
- `plan/`: STATUS, CHEFENTWICKLER, CODEBASE (Nähte, Speicherorte), ANSICHTEN (Ebenenmodell), AUSTAUSCH (Format Code ↔ Design), BRIEF-VORLAGE; `briefe/` (Index = Ordner), `gates/` (Recherchen, Berichte), `werkzeuge/plan_pruefen.py`.
- `konzept/` (VISION, GLOSSAR, OFFENE-FRAGEN, 10-MODUL-CODEPLAYER) · `gestaltung/` (`kanon/` Quelle von Konto B, `vertrag/` erzeugt, nie von Hand) · `scripts/` (pruefen.sh, waechter*, lizenzen.txt) · `.githooks/` · `dist/` (Apps) und `ausgang/` (ZIPs) sind ignoriert.

## Rollen
Die Rolle steht im Sitzungsnamen (`CLAUDE.md`). Jede Rolle belegt, fragt und liefert anders:
- Chef (Claude Code im Repo): schreibt Briefe, verteilt, prüft, committet, pusht; trägt Johannes' Entscheidungen in diese Datei und `plan/STATUS.md`.
- Code: belegt mit laufendem Code und Test (Datei:Zeile); ändert nur die Pfade seines Briefs.
- Design: arbeitet in Claude Design, Code oder Chat im Browser (Chrome, Safari) mit GitHub oder lokalem Ordner; ein Terminal-Claude kann vermitteln. Belegt mit Varianten und Johannes' Entscheid am Bild; fragt, hakt nach, liefert nach `gestaltung/` und führt die Korrespondenz im Ticker.
- Helfer: Zuarbeit nach Auftrag im Ticker; helfende Konten schreiben nur in `gestaltung/`.
- Worker (Haiku, Sonnet): bauen nach Brief. Codex ruht.
- Johannes: entscheidet, nimmt am Bild ab, trägt ZIPs.
Gates G1 bis G9 und Etappen-Gates entfallen.

## Ticker und Johannes' Wort
- Ticker: GitHub Issues in `JohannesLeoB/ALFA_OS`. Ein Issue je Auftrag: was, warum, wer (Sitzungsname), womit (Dateien, Artifacts, Commits), Stand mit Datum und Commit. Labels: `läuft`, `wartet auf Johannes`, `Nebenschauplatz`, `Stückgut` (Fundus, noch nicht veredelt). Geschlossen heißt vorbei.
- Jede Sitzung liest beim Start und vor jedem Schritt die offenen Issues (`gh issue list -R JohannesLeoB/ALFA_OS`) und schreibt bei Beginn und Ende eines Auftrags einen Kommentar. Jeder Kommentar beginnt mit Sitzungsname und Uhrzeit.
- Johannes spricht immer nur in einer Sitzung. Diese schreibt sein Wort sofort wörtlich als Kommentar ins passende Issue und markiert Entscheidungen mit „Entscheidung“. Der Chef trägt sie in diese Datei oder `plan/STATUS.md` ein; das neueste Wort gilt, Älteres wird als überholt markiert. Wortlaut bis 10.10.2026: `plan/FRAGEN.md`.
- Sitzungen, Konten und Deutungen stehen nur im Ticker, nie in Code, Commits oder Docs.

## Start und Ende
- Start: `git pull --rebase`, `git status`, offene Issues lesen, `bash scripts/pruefen.sh` (Soll `Result: 0 errors`). Fremde uncommittete Dateien nie anfassen; nie `git checkout --`, `git reset`, `git stash`; nie die Datei `index.lock` löschen (warten, wiederholen).
- Ende (Worker): `pruefen.sh` grün, Übergabe im Brief (Commits, rot/grün je Fund, Abweichungen, Annahmen einzeln markiert, offene Fragen), Status „zur Prüfung“. `plan/STATUS.md` ändert nur der Chef.
- Der Chef prüft jeden Bericht selbst. Worker-Berichte sind Aussagen, kein Beleg.

## Git
- `main` ist die eine Linie; sie schreibt nur die eine Sitzung auf dem Mac (Hook R1 sperrt lokal jeden anderen Zweig). Keine Worktrees, Klone, Sicherungen daneben. Browser-Sitzungen schreiben in Issues; liefern sie Dateien, dann auf einem Zweig `web/<issue>-<kurz>` als Pull Request, den die Mac-Sitzung prüft und übernimmt (Chef, 10.10.2026, auf Johannes' Wunsch nach dem Optimum).
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
- Bestand ist eine Goldgrube, kein Gold: erst vorhandene Erfassungen nutzen (Inventuren, Karten, Register, Artifacts, Briefe; je mit Datum und Code-Stand), dann nur das Gebrauchte am heutigen Code oder an Johannes' Wortlaut prüfen, veredeln, zusammenführen. Nichts neu suchen oder neu erfinden, was schon erfasst ist (Johannes: „nicht immer neu suchen und neu erfinden“).
- Verstehen ist Aufgabe der Agenten: Richtung, Ziele, Bereiche, Stand und Schritte stehen hier und in `plan/STATUS.md`. Keine Abhak-Listen und keine Artifacts nur zum Festhalten für Johannes.
- Regeln und Stand stehen nur im Repo (diese Datei, `plan/STATUS.md`), laufende Aufträge im Ticker, nie nur im Gedächtnis einer Sitzung. Erinnerungen jedes Kontos sind keine Quelle; die lokalen Gedächtnisse zeigen seit 10.10.2026 nur hierher.
- Builds nur im Repo: Xcode mit `-derivedDataPath .build-xcode/dd`, nichts nach `/Applications`, nichts in Xcodes Standard-DerivedData.

## Parallelität
Chef beauftragt Haiku oder Sonnet (Sonnet bei Urteil, Spike, Umzug). Freigabe Johannes (10.10.2026): jederzeit 2 Haiku; 5 Worker nach kurzer Nachfrage; 10 bis 20 Haiku nach Nachfrage mit Ziel in Stichpunkten. Jeder Schwarm ist geregelt, endlich und im Blick; bauende Worker nur bei getrennten Pfaden. Umzüge und Aufräumen laufen allein. Solange Worker laufen, ändert der Chef keinen Code. Bricht ein Bau an fremden halbfertigen Dateien: in 60-s-Schritten bis 15 min wiederholen, fremde Dateien nie reparieren.

## Zonen
Nur der Chef ändert: `app/Sources/AI/`, `app/Sources/Document/`, `app/Sources/ALFAcolorCore/Place*.swift`, `ALFAcolor/App/Features/KI/`, `ALFAcolor/App/Features/Settings/`, `ALFAcolor/App/Settings/`, `plan/`, `uebergabe/`, `gestaltung/`, `scripts/`. Worker arbeiten nur in den Pfaden unter „Besitzt“ ihres Briefs, alles andere nur lesen.

## Fallen
- Plugin `design-drift` meldet bei jedem Schreiben einen harmlosen Fehler (Pfad mit Leerzeichen): ignorieren.
- `.allowsHitTesting(false)` an der Wurzel blockiert alle Kinder; `ignoresSafeArea` zuletzt in der Modifier-Kette; `onKeyPress` nach `.focusable()`; der Inhalt einer Spalte bestimmt nie ihre Mindestgröße (Layout-Schleife, Absturz).
- Johannes kennt die App am Bild nur bis 0.2.2; alles Neuere ist ungesehen: mit Bedien- und Layoutfehlern rechnen.
- Sitzungslimit nicht aus dem Gedächtnis schätzen; bei 90 % einen Zettel in `uebergabe/` schreiben.
