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
| `ausgang/` | Forensik; nicht in Git | bis Forensik fertig |
| Wurzel | `AGENTS.md` (Regeln), `CLAUDE.md` (verweist auf AGENTS.md), `README.md` (Karte), `.gitignore`, `.swiftlint.yml` | dauerhaft |

## Einstieg für Agenten

1. `AGENTS.md` (Regeln), dann `.claude/memory/MEMORY.md` (Stand, Johannes' Wort).
2. Der Strang zur Aufgabe in `.claude/agents/`.
3. Werte nur aus dem Master: `DESIGN/MANIFEST.json`, Rang `latest`; `scripts/design_generate.py` erzeugt daraus `alfaos/Kit/Sources/ShellCore/DesignTokens.swift`.

## Ablage

- Neue Ordner oder Dateien außerhalb dieser Karte nur auf Johannes' Wort; die Karte im selben Commit nachziehen.
- Entpackter Master nur in `dist/master-latest/`.
- Build-Zwischenstände: ein gemeinsamer Pfad je Art; eigene Pfade nur bei Parallelarbeit, die Sitzung löscht sie am Ende.
