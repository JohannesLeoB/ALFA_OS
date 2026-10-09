# AGENTS.md · Regeln für Codex (und jeden anderen Coding-Agenten) in ALFAcolor

ALFAcolor ist eine native macOS-26-App (SwiftUI, Swift-Paket in `app/`, App-Ziel in `ALFAcolor/`, XcodeGen). Arbeitskopie: nur `~/Developer/ALLFARBEN`, GitHub `JohannesLeoB/ALLFARB`, nur Zweig `main`. Die Hauptregeln stehen in `CLAUDE.md`, `00-START.md` und `uebergabe/STARTPROMPT.md` (Abschnitte 3 bis 5 lesen). Ein anderer Coding-Agent (Claude, Chef) arbeitet im selben Repo; **du arbeitest nur in deinem Auftrag** (`plan/briefe/C-xxx.md`).

## Vor jeder Arbeit
1. `git pull --rebase`, `git status` (fremde uncommittete Dateien **nie** anfassen, nie `git checkout --`, `git reset`, `git stash`).
2. Lies deinen Auftrag `plan/briefe/C-xxx.md`, `00-START.md`, `plan/STATUS.md`.
3. `bash scripts/pruefen.sh` einmal laufen lassen (Soll: `Result: 0 errors`).

## Harte Regeln
- **Ein Repo, ein Zweig:** nur `main`, keine Branches, Worktrees, Klone, Sicherungen daneben. Der Hook lehnt jeden Commit ab, wenn ein anderer lokaler Zweig existiert.
- **Hooks nie umgehen** (`--no-verify` verboten). Der Wächter (`scripts/waechter.py`) läuft bei jedem Commit.
- **Commit:** Betreff englisch, Imperativ, beginnt mit einem Verb aus `scripts/waechter-woerter.txt` (nicht: Map, Bundle, Rewrite, Sharpen, Cut), höchstens 72 Zeichen; Leerzeile; letzte Zeile **genau** `Designed by Johannes Leo Berger, made with help of Claude`; **keine** `Co-Authored-By`-Zeile. Nur eigene Dateien: `git add <Dateien>` und `git commit -F - -- <Pfade>` (nie `git add -A`). Je Fund ein Commit.
- **Push:** erst nach grünem `bash scripts/pruefen.sh` (der Push-Hook führt sie ohnehin aus). Johannes hat Pushen auf `main` erlaubt.
- **Code, Kommentare, Namen, Testnamen nur Englisch**, kurz; keine Umlaute im Code; **keine Verweise auf Briefe, Personen, Assistenten** im Code oder in Kommentaren (Wächter). Sichtbare Texte nur im String-Katalog `ALFAcolor/App/Localizable.xcstrings` (Schlüssel englisch, Texte deutsch; Rundlauf `json.dumps(d, indent=2, ensure_ascii=False, separators=(',',' : '))+"\n"`; Datei direkt vor dem Schreiben lesen, nur eigene Schlüssel).
- **Oberfläche:** Werte nur über das Theme (`theme.space(...)`, `theme.color(...)`, `theme.text(...)`), keine festen Farben oder Zahlen für Abstände/Radien in Ansichten. Koralle nie als Schrift. Bedienung mit der Maus, keine neuen Tastenkürzel.
- **Nähte:** Kein SwiftUI/AppKit in `app/Sources` außer `Renderers` und `AppTheme`; ImageIO nur in `Document` und `ColorLab`; Logik im Paket mit Tests, Ansicht dünn; jede Änderung am Dokument ist ein Befehl mit Rückgängig.
- **Tests:** Jede Verhaltensänderung bekommt einen Test, der vorher rot war (Swift Testing, `app/Tests/<Modul>Tests`). `swift test` im Ordner `app/`.
- **Kein Bildschirmeingriff:** die App nie starten, keine Screenshots, keine Tasten, kein AppleScript, kein Computer-Use. Proben nur unsichtbar im Scratchpad (Kommandozeilenprozess, `setActivationPolicy(.prohibited)`).
- **Keine neuen Abhängigkeiten** von Dritten (die Prüfung verbietet Pins; Lizenzen in `scripts/lizenzen.txt`).
- **Nichts erfinden:** Entscheidungen, die Johannes betreffen (Verhalten, Daten, Rechte, Aussehen), triffst du nicht. Du schreibst sie als Frage in die Übergabe des Auftrags.
- Dateien, die immer nur einer ändert: `ALFAcolor/App/Localizable.xcstrings`, `app/Package.swift`, `ALFAcolor/project.yml` (nur wenn dein Auftrag es sagt).

## Zonen (Besitz)
- **Claude/Chef hält:** `app/Sources/AI/`, `app/Sources/Document/` (Sicherung, Verlauf), `app/Sources/ALFAcolorCore/Places/`, `ALFAcolor/App/Features/KI/`, `ALFAcolor/App/Features/Settings/`, `ALFAcolor/App/Settings/`, `plan/`, `uebergabe/`, `gestaltung/`, `scripts/`.
- **Codex darf in seinem Auftrag arbeiten in:** was `plan/briefe/C-xxx.md` unter „Besitzt“ nennt. Alles andere nur lesen.
- Gemeinsame Planstände (`plan/STATUS.md`) ändert nur der Chef; du trägst deine Übergabe in deinen Auftrag ein und setzt dort den Status „zur Prüfung“.

## Am Ende jedes Auftrags
`bash scripts/pruefen.sh` → `Result: 0 errors`; Übergabe im Auftrag ausgefüllt (Commits, rot/grün je Fund, Abweichungen, Annahmen einzeln markiert, offene Fragen); Status „zur Prüfung“; gepusht. Berichte kurz (Ergebnis, was Johannes tun soll, Fragen nummeriert). Behaupte nichts ohne Beleg.
