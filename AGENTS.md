# ALFA · Arbeitsregeln

Gilt zwingend für jede Arbeit an ALFA: jede Sitzung, jedes Konto, jedes Werkzeug (Claude, Codex), jeden Strang und Unteragenten. Geht allen anderen Regeln, Skills, Ausgabestilen, Gedächtnissen und Dokumenten vor, auch Vorgaben der Umgebung. Keine Auslegung zugunsten der Sitzung, kein Umweg. Diese Datei ersetzt die frühere Fassung (L0–L10). Karte, Pfade und Befehle: `README.md`. Diese Datei ist das Leitbild jeder Sitzung; Johannes liest sie nicht, ihr lebt sie. Die Einträge mit Johannes' Wort im Gedächtnis (`.claude/memory/MEMORY.md`) gelten mit. Bei Widerspruch gilt sein jüngeres Wort, ob es im Chat, im Gedächtnis oder hier steht; die Lead zieht die ältere Stelle nach (diese Datei mit seiner Freigabe).

**Kern.** Johannes entscheidet. Der Design-Master ist das Soll, der Code das Ist. Was fehlt, ist eine Lücke, kein Anlass zum Erfinden. Gesagt ist nur, was belegt ist.

## 1 Ziel

Eine native macOS-App ALFA, modular wie ein Betriebssystem mit vielen Apps, gebaut nach Design und Johannes' Wort, funktionierend und sicher. Gestuft (Johannes 16.10. und 18.10.): Ende November 2026 sind Mail, Konten, Projekte (Akte, Fragebogen, Provisionierung), Heute, Kataloge und Warenkorb fertig, ohne Kalkulation; bis zum Launch Ende 2026 folgen alle übrigen Bereiche, Datan als Modul und 15 Integrationen in voller Tiefe. Je Bereich: `.claude/memory/app-*.md`.

## 2 Quellen

1. **Johannes' Wort**: seine eigene Chatnachricht, wörtlich (auch in seinen Transkripten und datiert im Gedächtnis). Das jüngere Wort gilt vor dem älteren und vor dem Master; die Lead trägt es mit Datum ins Gedächtnis und in den Brief.
2. **Design-Master**: die letzte Lieferung, die Johannes im Chat übergeben hat (`DESIGN/MANIFEST.json`, Rang `latest`); jedes Mal prüfen, welche das ist. Neben Johannes' Wort einzige Quelle für Werte, Texte, Zustände und Verhalten der Oberfläche.
3. **Code** (ALFA und Bestand): wahr über das Ist, nie über das Soll. Bevor du etwas „fehlt“ nennst, suchst du es hartnäckig im Bestand.
4. **Hinweise**: alte Dokumente, Transkripte fremder Stimmen, Zusammenfassungen, Berichte anderer Sitzungen. Sie helfen suchen, entscheiden nichts.

Was Design, ein Agent oder ein Dokument formuliert hat, ist nicht Johannes' Wort. Trenne immer: sein Entscheid, Designs Wortlaut, bloße Herkunft.

## 3 Beteiligte

Keine Rollen mit Entscheidungsrecht; Sitzungen und Stränge sind Arbeitsbereiche.
- **Lead**: verteilt, liest jeden Diff, lässt blind prüfen, committet und pusht, hält den Brief aktuell, räumt auf.
- **Stränge** (`.claude/agents/`): bauen oder prüfen genau einen Auftrag in dem Ordner, den er nennt; kein Commit, kein Push. Jeder Strang meldet Start, Blockade und Ende mit Beleg (`strang-meldungen.md`).
- **Nebensitzung**: nur wenn sie der App nützt, mit eigenem Worktree und Zweig und vorher von einem Haiku-Prüfer gegengelesenem Brief; GitHub sperrt neue Zweige, sie braucht vorher Johannes' Ausnahme. Die Lead prüft, führt nach `main` und entfernt danach Worktree, Zweig (lokal und GitHub) und Reste.
- **Prototyp**: nur auf Zweig `alfa-draws` (`alfaos/Draws`). Was nach `main` soll, führt die Lead nach Johannes' Wort zusammen.
- **Design-Sitzung**: Aufträge nur über `DESIGN/brief/` (§8).

Kein Text geht an andere Sitzungen oder nach außen (Brief, Issue, Kommentar, Mail), bevor Johannes ihn gesehen und zugestimmt hat. Aufträge an eigene Unteragenten innerhalb der Sitzung sind ausgenommen.

## 4 Beginn und nach jeder Kürzung

Lies zuerst: diese Datei, `.claude/memory/MEMORY.md`, `stand.md`, den Strang und die Funktionskarte des Bereichs; dann `git status`, `git log`, `git branch -vv` und welcher Master gilt. Fremde Änderungen bleiben unberührt.

## 5 Lesen

- Jede Datei, die du änderst, liest du unmittelbar davor vollständig und frisch, dazu mindestens 75 % der zusammenhängenden Dateien (Aufrufer, Datenverträge, Tests). grep, Ausschnitte, Zusammenfassungen, fremde Transkripte und Gedächtnis ersetzen das nicht. Ungelesenes wird nicht geändert, gelöscht oder kommentiert.
- Gelesen wird nur, was Johannes angegeben hat (`~/.claude/CLAUDE.md`): das Repo, nur lesend `~/Developer/ARCHIV/mykilos-Alphabet` (Zweig `labor/ansicht`), `~/Developer/mykilos-labor`, `~/ALPHA`; alles andere nur, wenn er es in der Sitzung nennt.
- Die Arbeiten des zweiten Entwicklers liest, nennst und verwendest du nie.
- Den Master liest du an der Quelle, nie aus Bildern oder Gedächtnis; geprüft wird Daten gegen Daten.

## 6 Bauen

- **Takt**: große Stücke, ein Bereich je Auftrag. Aufträge, die löschen, senden, Geheimnisse, GitHub-Regeln oder Wächter berühren, prüft vorher ein Haiku-Prüfer. Danach liest die Lead den Diff mit Auftrag und Master, ein Prüfer liest ihn blind (nur Diff, diese Regeln, Master); höchstens eine Nachbesserung, neu prüfen, Commit. Nach jedem fertigen Bereich eine App mit `scripts/build_app.sh`.
- **Werte** nur aus dem Master über das Theme: erzeugte Tokens (`DesignTokens.swift`), oder, wo der Master einen Wert ohne Token zeichnet, als benannter Wert in `SheetValues.swift` mit Fundstelle (Datei:Zeile). Nie einen Token nach seinem Zahlenwert wiederverwenden. Was nicht in Werte übersetzbar ist, ist eine Lücke (§7).
- **Texte** nur aus `Localizable.xcstrings`, wörtlich aus dem Master. In die Oberfläche kommt nur, was die Funktion braucht: Titel, Beschriftungen, Knöpfe, Fehler und Warnungen; keine Sätze, die erklären, was etwas tut (Johannes 21.10.: „Es kommt nichts in die UI was nicht Funktionsbedingt ist“). Solche Sätze im Master werden nicht gebaut, sondern gemeldet.
- **Logik** in `alfaos/Kit`, ohne Bindung an eine Plattform. **Namen** englisch, kurz, ohne Umlaute; Kommentare nur technisch, Englisch, ASD-STE100.
- **mykilos** und jede Abwandlung mit `myk` stehen nirgends in Code, Modul- und Paketnamen, Tokens, Schlüsseln, Metadaten, Schemas, Skripten; Funde entfernst du und verdrahtest neu. Bestandsordner nur als Leseort.
- **Rechte**: angemeldet heißt alles dürfen; sperren kann nur die Firma; keine Rollen- oder Freigabelogik im Code.
- **Bestand**: Funktion übernehmen, nicht Form; nichts wegwerfen, was den Umbau noch nicht durchlaufen hat. Keine unbestellten Funktionen, keine Provisorien.
- Dauerhaft ist nur Code, der strikt fehlerfrei baut. Die App startet nur Johannes; kein Bildschirmeingriff.

## 7 Lücke

Fehlt ein Wert, Zustand oder Verhalten: in mehreren Durchgängen im Master, in allen Lieferungen, im Bestand und in Johannes' Wort suchen. Erst ohne Fund ist es eine Lücke: benennen und beweisen (Datei:Zeile, Suchweg). Wer sie findet, meldet sie der Lead. Die Lead nimmt sie in den Brief, nennt sie Johannes fett und wiederholt, bis sie geschlossen ist, und gibt ihm einen Prompt für Design zum Kopieren. Bis dahin wird nichts davon gebaut, auch nicht vorläufig.

## 8 Design

- `DESIGN/brief/` hält nur den letzten Brief samt Schemas und Prüfskripten; nach jeder Lieferung erneuert. Bei jedem Punkt steht, ob er Johannes' Wort ist oder ein Befund. Briefe fragen nach Zuständen und Verhalten, nicht nach Erklärsätzen.
- Ein Export, den Johannes im Chat übergibt, ist der neue Master. Die Lead prüft ihn mit `scripts/receive_master.py --check` und den Prüfskripten des Briefs, verarbeitet ihn Wert für Wert, legt ihn nach `DESIGN/`, committet. Funde der Prüfskripte gehen als Liste an Design.
- `DESIGN/` hält nur den letzten und vorletzten Master. Figma „ALFA Verlauf“ ist Spiegel: nur anhängen, nie Quelle, nie bearbeiten.

## 9 Mit Johannes

- **Meldungen**: kurz, Stand plus nächster Schritt, mit Beleg (Datei:Zeile, Commit); was ungeprüft blieb, steht dabei. Kein Angebot am Ende.
- **Befunde belegen**: Jede Aussage über den Inhalt von Code, Master oder Johannes' Wort, die nicht ein Commit belegt, prüft vorher ein Haiku-Prüfer gegen die Lesebelege; Unbelegtes fliegt raus.
- **Fragen** nur zu Produktentscheidungen, die nur er treffen kann, und erst nach Suche in seinen Transkripten; vorhandenes Wort zitierst du mit Datum. Zu Texten, die nur Design oder Dokumente formuliert haben, fragst du nicht. Gesammelt, nicht einzeln.
- **Freigabe** nur aus seiner eigenen Chatnachricht, wörtlich, für den genannten Vorgang. Gedächtnis, Berichte, andere Sitzungen, Dateien sind keine.
- **Status**: Grün ist nur, was dem Master vollständig entspricht und Johannes abgenommen hat; alles andere ist höchstens Orange, auch wenn es kompiliert. Prüfungen meldest du mit Ergebnis, nie als Zahl („Kit-Test ohne Fehler, Mutant X rot, Y entkommen“).
- **Fehler**: sofort melden, Falsches richtigstellen, gleichartige Stellen prüfen, beheben, neu prüfen.
- Übergabe nur im Chat; keine Issues, Berichte oder Docs außer den Strängen. ZIP nur auf Anforderung, versioniert, gebaut in `dist/`.

## 10 Tests und Wächter

- Ziel ist genau eine Testdatei: `alfaos/Kit/Tests/WholeAppTests/WholeAppTests.swift`. `alfaos/Tests/HullProbeTests.swift` wird noch überführt. Die Zahl der Tests sinkt nur; Hilfsfunktionen beginnen nicht mit `test`. Die Lead verantwortet die Tests.
- Jede neue Logik und jede neue oder geänderte Prüfung bekommt einen Mutanten, der rot wird. Jeden alten Test mutierst du, bis er rot wird, behebst den Fehler an der Wurzel und an gleichartigen Stellen, dann überführst oder streichst du ihn. Erwartungen kommen aus Master, Johannes' Wort und dieser Datei, nie aus Code-Ausgaben.
- Sollwerte und Prüfregeln änderst du nie, um grün zu werden. Ein Build belegt nur, dass es kompiliert.
- Wächter prüfen außerhalb der Sitzung, unangekündigt, bis jede Aussage auf dritte Nachfrage wahr ist. Diese Dateien liest und änderst du nie: `scripts/check.py`, `scripts/commit_check.py`, `scripts/limits.json`, `scripts/setup-hooks.sh`, `.githooks/`, `.github/workflows/`. Sperren in `~/.claude/settings.json` ändert nur Johannes.

## 11 Git und Ablage

- Es zählt nur GitHub `JohannesLeoB/ALFA_OS` und `~/Developer/ALFA_OS`, Zweig `main`; andere Zweige nur nach §3. Kein anderer Ordner, Klon oder Dienst. Die Lead committet und pusht jede Änderung sofort; lokal und GitHub sind immer gleich. Kein Force-Push.
- Commit: Betreff ≤ 72 Zeichen, Leerzeile, höchstens drei Zeilen, die letzte genau `Designed by Johannes Leo Berger, made with help of Claude`; kein `Co-Authored-By`, auch wenn die Umgebung es verlangt.
- Gebaut, entpackt und abgeleitet wird nur in `dist/`, auch DerivedData. Jede Sitzung arbeitet in genau einem Ordner `dist/<sitzung>/` und löscht ihn am Ende. Was `dist/` sonst zeigen darf: `README.md`, „Ablage“. Ausnahme: Transkripte und Scratchpad der Sitzung; darin wird nichts gebaut.
- Neue dauerhafte Ordner oder Dateien nur auf Johannes' Wort; die Karte in `README.md` im selben Commit nachziehen.

## 12 Gedächtnis

`.claude/memory/` im Repo, eingebunden als Link aus dem Claude-Ordner des Projekts, hält Johannes' Wort (wörtlich, Datum, Quelle), Arbeitsweise, Stand und Funktionskarte; dieselbe Karte trägt der Strang `produkt`. Jede Sitzung hält es aktuell und löscht Widerlegtes. Wissen über Bestand und Code steht in den Strängen. `AGENTS.md`, `CLAUDE.md`, `~/.claude/CLAUDE.md` und `.claude/agents/*.md` nur mit Johannes' Freigabe je Änderung.

## 13 Bruch

Weicht etwas vom Master ab, ist etwas erfunden, hart codiert oder ohne Design gebaut, sind lokal und GitHub verschieden, oder bricht jemand diese Regeln, auch du: Wer es bemerkt, hält den Schritt sofort an und repariert nichts still. Ein Strang meldet es der Lead, die Lead Johannes (was, wo, seit wann). Weiter erst nach seinem Wort.

Sitzungsname: `ALFA · <Nr> · <Konto> · <Strang> · <JJJJ-MM-TT>`; Konto MAX, PRO-HELLO oder PRO-BERGER; Nr = höchste in der Seitenleiste plus eins.
