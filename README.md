# ALFA_OS

Native macOS-App ALFA (Swift, SwiftUI). Regeln: `AGENTS.md`; sie gehen allem vor. Diese Datei ist die Karte: jeder Ordner im Repo steht hier mit Zweck und Lebensdauer.

## Karte

| Pfad | Inhalt | Lebensdauer |
|---|---|---|
| `alfaos/App/` | Ansichten (SwiftUI), `Localizable.xcstrings`, Resources | dauerhaft |
| `alfaos/Kit/` | Logik (Swift-Paket: ShellCore, Mail, Hub), Tests | dauerhaft |
| `alfaos/project.yml` | Xcode-Projekt-Vorlage (xcodegen) | dauerhaft |
| `alfaos/Config/` | Entitlements, Info.plist, Export-Optionen, Beispielwerte ohne Firmendaten | dauerhaft |
| `alfaos/Tests/` | App-Test `HullProbeTests.swift`; geht in den einen Test über (L5) | bis überführt |
| `fundus/alpha/` | Bestandscode, eingebunden als `AlfaKit`, `AlfaServices`, `AlfaCalculation` | bis abgelöst |
| `DESIGN/` | letzter und vorletzter Design-Master (ZIP), `MANIFEST.json` | nach L7 |
| `DESIGN/brief/` | aktueller Brief an Design mit Schemas, Prüfskripten, Beispielen | nur der letzte |
| `gestaltung/alfa-interface/` | `tokens.json`, `tokens.css` (altes Theme), `quarantine.json` (Alt-Tokens ohne Rolle), `design.stamp.json` (Stempel des Masters) | bis abgelöst |
| `scripts/` | Generatoren mit `--check`, `mutate.py`, `lizenzen.txt`; Prüf- und Hook-Dateien (Wächter) | dauerhaft |
| `.githooks/`, `.github/workflows/` | Commit-Hook, GitHub-Prüflauf (Wächter) | dauerhaft |
| `.claude/agents/` | Stränge (Arbeitsbereiche der Sitzungen) | dauerhaft |
| `.claude/memory/` | Gedächtnis | dauerhaft |
| `dist/` | Gebautes und Abgeleitetes; nicht in Git; jederzeit löschbar | flüchtig |
| Wurzel | `AGENTS.md` (Regeln), `CLAUDE.md` (verweist auf AGENTS.md), `README.md` (Karte), `.gitignore`, `.swiftlint.yml` | dauerhaft |

## Einstieg für Agenten

1. `AGENTS.md` (Regeln), dann `.claude/memory/MEMORY.md` (Stand, Johannes' Wort).
2. Der Strang zur Aufgabe in `.claude/agents/`.
3. Werte nur aus dem Master: `DESIGN/MANIFEST.json`, Rang `latest`; `scripts/design_generate.py` erzeugt daraus `alfaos/Kit/Sources/ShellCore/DesignTokens.swift`.

## Wegweiser: welche Datei wofür

Regeln
- `~/.claude/CLAUDE.md`: globale Regeln (nur Angegebenes lesen; ALFA folgt `AGENTS.md`).
- `AGENTS.md`: LAWS AND ORDERS. Lies sie vor jeder Arbeit.

Gedächtnis (Inhaltsarchiv)
- `.claude/memory/MEMORY.md`: Index. Lies ihn zu Beginn jeder Sitzung.
- `.claude/memory/stand.md`: laufender Stand, offene Punkte, Aufträge. Lies ihn, bevor du etwas für offen oder erledigt erklärst.
- `.claude/memory/app-*.md`: Funktionskarte je Bereich (Ist, Soll, Offen) mit Johannes' Wort. Lies die Karte des Bereichs, an dem du arbeitest.
- `.claude/memory/arbeitsweise.md`, `test-verstaendnis.md`, `strang-meldungen.md`, `nebensitzungen.md`, `design-brief-aktuell.md`: wie gearbeitet, geprüft, gemeldet wird.
- Johannes' Wort im Original: Transkripte unter `~/.claude/projects/-Users-johannesleoberger-Developer-ALFA-OS*/`; Nutzernachrichten und eingereihte Nachrichten (`queue-operation`, `queued_command`) durchsuchen.

Stränge
- `.claude/agents/*.md`: Wissen über Bestand und Code je Arbeitsbereich (bau-mail, bau-heute, bau-projekte, bau-kataloge, design-bruecke, figma-spiegel, produkt, leser, sammler, vier Prüfer).

Design (einzige Wertquelle)
- `DESIGN/MANIFEST.json`: welcher Master gilt (Rang `latest`), Prüfsummen.
- `DESIGN/*.zip`: letzter und vorletzter Master im Original.
- `DESIGN/brief/BRIEF.txt`: aktueller Brief an Design, mit Schemas und Prüfskripten (`validate.py`, `check_contract.py`, `diff_contract.py`).
- `dist/master-latest/`: entpackter Master zum Lesen (lange Zeilen mit `python3` lesen).

Code
- `alfaos/App/`: Ansichten. `alfaos/App/Localizable.xcstrings`: alle sichtbaren Texte.
- `alfaos/Kit/Sources/`: Logik (ShellCore, Hub, Mail). `ShellCore/DesignTokens.swift` ist erzeugt; `ShellCore/SheetValues.swift` hält Werte ohne Token.
- `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift`: der eine Test (`testTheWholeApp`), dazu `golden.txt` und `MailWire.txt`.
- `fundus/alpha/`: Bestand (IMAP, Gmail, DHL u. a.); deutsche Namen und `myk`-Reste werden abgelöst.
- `scripts/design_generate.py --check`, `scripts/receive_master.py --check`: Master, Manifest und Stempel gegen den Code prüfen.

Außerhalb des Repos
- `~/Developer/STAMMTISCH/ALFA Stammtisch.rtf`: Beratung zwischen Lead, Archivar und Produkt.
- `~/Developer/SKILLS/alfa-bibliothekar/books/`: Bücher je Bereich (Stand nicht garantiert; an der Quelle prüfen).
- Nur lesend, laut `AGENTS.md` L6: `~/Developer/ARCHIV/mykilos-Alphabet` (Branch `labor/ansicht`), `~/Developer/mykilos-labor`, `~/ALPHA`.

## Bauen und prüfen

- Kit-Test: `cd alfaos/Kit && swift test --scratch-path ../../dist/kit-test`
- App: `cd alfaos && xcodegen && xcodebuild -project ALFA_OS.xcodeproj -scheme ALFA_OS -derivedDataPath ../dist/dd-app build -quiet`
- Fundus: `cd fundus/alpha && swift build --scratch-path ../../dist/fundus-test`
- Scratch-Ordner in `dist/` nach dem Lauf löschen.

## Commit

- Betreff höchstens 72 Zeichen; letzte Zeile genau `Designed by Johannes Leo Berger, made with help of Claude`; kein `Co-Authored-By`.
- Der Hook prüft swiftlint (keine Kommentare, keine Umlaute in Code), Generatoren (`--check`) und Grenzen.
- Nach jedem Commit pushen; lokal und GitHub gleich (`AGENTS.md` L4).

## Ablage

- Neue Ordner oder Dateien außerhalb dieser Karte nur auf Johannes' Wort; die Karte im selben Commit nachziehen.
- Entpackter Master nur in `dist/master-latest/`.
- Build-Zwischenstände: ein gemeinsamer Pfad je Art; eigene Pfade nur bei Parallelarbeit, die Sitzung löscht sie am Ende.
