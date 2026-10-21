# ALFA_OS

Native macOS-App ALFA (Swift, SwiftUI). Regeln: `AGENTS.md`; sie gehen allem vor. Hier steht Nachschlagwissen, auf das `AGENTS.md` verweist. Diese Datei ist die Karte: jeder Ordner im Repo steht hier mit Zweck und Lebensdauer.

## Karte

| Pfad | Inhalt | Lebensdauer |
|---|---|---|
| `alfaos/App/` | Ansichten (SwiftUI), `Localizable.xcstrings`, Resources | dauerhaft |
| `alfaos/App/Resources/Assets.xcassets` | App-Icon aus dem Master (erzeugt von `scripts/icon_generate.py`) | dauerhaft |
| `alfaos/Kit/` | Logik (Swift-Paket: ShellCore, Mail, Hub), Tests | dauerhaft |
| `alfaos/project.yml` | Xcode-Projekt-Vorlage (xcodegen) | dauerhaft |
| `alfaos/Config/` | Entitlements, Info.plist, Export-Optionen, Beispielwerte ohne Firmendaten | dauerhaft |
| `alfaos/Tests/` | App-Test `HullProbeTests.swift`; geht in den einen Test über (`AGENTS.md` §10) | bis überführt |
| `fundus/alpha/` | Bestandscode, eingebunden als `AlfaKit`, `AlfaServices`, `AlfaCalculation` | bis abgelöst |
| `DESIGN/` | letzter und vorletzter Design-Master (ZIP), `MANIFEST.json` | nach `AGENTS.md` §8 |
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
- `AGENTS.md`: ALFA · Arbeitsregeln. Lies sie vor jeder Arbeit.

Gedächtnis (Inhaltsarchiv)
- `.claude/memory/MEMORY.md`: Index. Lies ihn zu Beginn jeder Sitzung.
- `.claude/memory/stand.md`: aktueller Stand (Gebautes, Ungeprüftes, Lücken an Design, Offenes, bekannte Fehler). Lies ihn, bevor du etwas für offen oder erledigt erklärst.
- `.claude/memory/spec-*.md`: Spec je Bereich (Ziel, Funktionen mit Ist-Beleg und Status, Regeln, Lücken); `spec-format.md` sagt, wie sie gepflegt werden; `spec-arbeit.md` ergänzt AGENTS.md um die Arbeitsweise; `spec-architektur.md` ist das Bild der App. `artefakte.md` ist nur Hinweis (AGENTS.md §2.4), keine Quelle.
- Johannes' Wort im Original: Transkripte unter `~/.claude/projects/-Users-johannesleoberger-Developer-ALFA-OS*/`; Nutzernachrichten und eingereihte Nachrichten (`queue-operation`, `queued_command`) durchsuchen.

Stränge
- `.claude/agents/*.md`: Wissen über Bestand und Code je Arbeitsbereich (bau-mail, bau-heute, bau-projekte, bau-kataloge, design-bruecke, figma-spiegel, produkt, leser, sammler, vier Prüfer).

Design (einzige Wertquelle)
- `DESIGN/MANIFEST.json`: welcher Master gilt (Rang `latest`), Prüfsummen.
- `DESIGN/*.zip`: letzter und vorletzter Master im Original.
- `DESIGN/brief/BRIEF.txt`: aktueller Brief an Design, mit Schemas und Prüfskripten (`validate.py`, `check_contract.py`, `diff_contract.py`, `check_delivery.py`).
- `dist/master-latest/`: entpackter Master zum Lesen; fehlt er, neu entpacken: `unzip -q "DESIGN/ALFA OS Interface CHEF 1610-handoff 1810.zip" -d dist/master-latest` (Name der ZIP nach `DESIGN/MANIFEST.json`, Rang latest) (lange Zeilen mit `python3` lesen).

Code
- `alfaos/App/`: Ansichten. `alfaos/App/Localizable.xcstrings`: alle sichtbaren Texte.
- `alfaos/Kit/Sources/`: Logik (ShellCore, Hub, Mail). `ShellCore/DesignTokens.swift` ist erzeugt; `ShellCore/SheetValues.swift` hält Werte ohne Token.
- `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift`: der eine Test (`testTheWholeApp`), dazu `golden.txt` und `MailWire.txt`.
- `fundus/alpha/`: Bestand (IMAP, Gmail, DHL u. a.); deutsche Namen und `myk`-Reste werden abgelöst.
- `scripts/design_generate.py --check`, `scripts/receive_master.py --check`: Master, Manifest und Stempel gegen den Code prüfen.
- `scripts/icon_generate.py --check`: App-Icon (`Assets.xcassets`) gegen den Master prüfen.

Außerhalb des Repos
- Von Johannes in Sitzungen als Leseort angegeben, nicht dauerhaft freigegeben (`AGENTS.md` §5; je Sitzung neu klären):
  - `~/Developer/STAMMTISCH/ALFA Stammtisch.rtf`: Beratung zwischen Lead, Archivar und Produkt.
  - `~/Developer/SKILLS/alfa-bibliothekar/books/`: Bücher je Bereich (Stand nicht garantiert; an der Quelle prüfen).
- Dauerhaft nur lesend, laut `AGENTS.md` §5: `~/Developer/ARCHIV/mykilos-Alphabet` (Branch `labor/ansicht`, gesichert als `sicherung/labor-*` auf GitHub), `~/Developer/mykilos-labor`, `~/ALPHA`.

## Bauen und prüfen

Jede Sitzung arbeitet in genau **einem** Ordner `dist/<sitzung>/` (die Lead den Ordner, den ihr Startprompt nennt; ein Bau-Strang den Ordner, den sein Auftrag nennt) und löscht ihn am Ende selbst (Johannes 21.10., `.claude/memory/spec-arbeit.md`). Pfade immer vollständig angeben, nie unter `alfaos/`.

- Kit-Test: `cd alfaos/Kit && swift test --scratch-path "$PWD/../../dist/<sitzung>/kit"`
- App: `cd alfaos && xcodegen && xcodebuild -project ALFA_OS.xcodeproj -scheme ALFA_OS -derivedDataPath "$PWD/../dist/<sitzung>/app" build -quiet`
- Fundus: `cd fundus/alpha && swift build --scratch-path "$PWD/../../dist/<sitzung>/fundus"`
- Fertige App: `scripts/build_app.sh --keep-running` (nummeriert `dist/ALFA OS <Nr>.app`, nur die zwei neuesten; ohne das Flag beendet das Skript die laufende App, die App startet nur Johannes)

## Commit

- Betreff höchstens 72 Zeichen, Leerzeile, dann höchstens drei Zeilen Text; die letzte ist genau `Designed by Johannes Leo Berger, made with help of Claude`; kein `Co-Authored-By`.
- Der Hook prüft swiftlint (Regeln in `.swiftlint.yml`, z. B. keine Umlaute in Code), Generatoren (`--check`) und Grenzen. Kommentare nach `AGENTS.md` §6.
- Nach jedem Commit pushen; lokal und GitHub gleich (`AGENTS.md` §11).

## Zweige und GitHub-Regeln

- `main`: Arbeitszweig. Regel `main-protect`: kein Force-Push, kein Löschen, lineare Historie.
- `alfa-draws`: Zweig der Prototyp-Sitzung (`alfaos/Draws`). Regel `only-main` sperrt alle anderen Zweige; eine Nebensitzung mit eigenem Zweig braucht vorher Johannes' Ausnahme.

## Ablage

- Neue Ordner oder Dateien außerhalb dieser Karte nur auf Johannes' Wort; die Karte im selben Commit nachziehen.
- Entpackter Master nur in `dist/master-latest/`.
- `dist/` zeigt sichtbar nur: fertige Apps, `master-latest/`, den Zwischenordner `build/` von `build_app.sh` und je laufender Sitzung einen Ordner. Worktrees von Nebensitzungen liegen als eigener Ordner in `dist/` und werden mit ihrem Zweig entfernt. Nichts versteckt, keine Berichte; Berichte gehen an Johannes und werden danach gelöscht.
