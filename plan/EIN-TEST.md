# Ein Test

Ziel: genau ein XCTest für die ganze App. Alle anderen Tests entfallen. Stand 2026-10-16.

## Setup (Johannes, vor dem Start)
1. Neue Claude-Code-Sitzung in `~/Developer/ALFA_OS`, Zweig `main`, kein Worktree. Name: `ALFA · <Nr> · MAX · Chef · 2026-10-16`.
2. Sandbox ohne `dangerouslyDisableSandbox`. Schreibrecht nur auf das Repo, `$TMPDIR` und diese zwei Ordner, sonst scheitert `swift test` an `output-file-map.json`: `/private/var/folders/7s/09zwpv5n33j2b9f8hgnw34xh0000gp/T` und `…/C`.
3. Den Hook, der Schreiben auf einen nicht vorhandenen Worktree `pensive-brahmagupta-b5087a` verlangt, vorher entfernen.
4. Auto-Push-Hook (`SubagentStop` in `.claude/settings.local.json`): entscheiden, ob er bleibt.
5. Stärkstes Modell, keine Worker außer dem Prüf-Worker unten.

## Prompt (einfügen)
Du bist die Sitzung „Ein Test“ für ALFA_OS. Lies `AGENTS.md`, `plan/EIN-TEST.md` und `gestaltung/nomenclature.json`. Ersetze alle 169 Tests durch genau einen: `func testTheWholeApp` in `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift`. Er startet die App-Zusammenstellung ohne Fenster, mit In-Memory-Datenbank und den vorhandenen Attrappen, und spielt ein festes Skript über die öffentliche Schnittstelle: Hülle (Bahnen falten, ziehen, maximieren, zurücksetzen), Tokenstempel und Generatoren, Einstellungsbereiche, Mail (Konto, Ordner, Liste, Lesen, Archivieren, Papierkorb, Verschieben, Entwurf speichern, senden, löschen, Postausgang), Gmail- und IMAP-Draht über die Stream-Attrappen. Das Ergebnis wird als Protokoll mit einer festen Datei `golden.txt` verglichen; jede Abweichung macht den Test rot. Keine Kommentare, englische Namen, keine neue Doku.

Reihenfolge: (1) Plane und baue `scripts/mutate.py` (Mutationen in `ShellCore`, `Hub`, `Mail`, `MykilosServices/Mail`; Übersetzungsfehler zählen nie als erkannt) und führe sie gegen die 169 alten Tests aus, um die Ausgangslage zu messen. (2) Baue den einen Test, bis jeder erkennbare Mutant ihn rot macht. Überlebende Mutanten werden durch bessere Szenen im Skript oder durch Entfernen toten Quellcodes erledigt, nie durch einen zweiten Test. (3) Lösche erst dann die alten Tests. (4) Hook `.githooks/pre-commit`: bricht ab, wenn die Zahl der `func test` in allen Testordnern ungleich 1 ist, wenn eine Testdatei dazukommt oder die Zeilen der Tests steigen. Zähle aus den git-Objekten, nicht aus einer editierbaren Datei.

Abnahme (alles mit Befehlsausgabe belegen): genau 1 Testfunktion; Laufzeit unter 60 Sekunden; mindestens 200 Mutanten, alle erkannt oder einzeln als gleichwertig begründet; Hook verweigert einen zweiten Test. Berichte kurz, Zahlen statt Text. Nichts pushen ohne Johannes.

## Warum ein Test
Viele kleine Tests bestätigen sich selbst. Ein Szenario über die ganze App kann nur grün sein, wenn die Teile zusammen stimmen, und ein Mutant fällt dort sofort auf.
