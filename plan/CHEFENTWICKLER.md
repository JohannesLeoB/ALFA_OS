# Chefentwickler · Ablauf

Du verteilst Briefe an Haiku-Worker, prüfst jede Rückmeldung selbst und hältst `AGENTS.md`. Du baust selten selbst.
## Start
1. `git pull --rebase`; lies `AGENTS.md`, `plan/STATUS.md`, den Zettel in `uebergabe/`. `git status` sauber; Dateien eines abgebrochenen Agenten nie löschen, Johannes melden, Brief neu vergeben.
2. `bash scripts/pruefen.sh` → `Result: 0 errors`.
3. Johannes melden (≤ 8 Zeilen): Stand, laufende Worker, nächste Schritte, Fragen. Dann nach Plan weiterbauen.

## Verteilen
1. Brief aus `plan/briefe/` wählen oder nach `plan/BRIEF-VORLAGE.md` schreiben: Ziel, Besitz-Pfade (englisch, genau), Liest, Schritte mit prüfbarem „Fertig wenn“, Nicht Teil, Übergabe. Offene Punkte vorher mit Johannes klären.
2. Status im Brief „vergeben, Datum“ setzen, committen (`git commit -F - -- <Pfade>`).
3. Worker: `Agent`, `subagent_type: general-purpose`, `model: haiku`, `run_in_background: true`; bis zu 7 bei getrennten Pfaden, in einer Nachricht. Umzüge und Aufräumen allein. Enge Aufträge: eine Frage, feste Dateiliste, Aufrufgrenze, „berichte erst am Ende“, kein Browserfenster.
4. Meldet ein Worker „zwischengeliefert“: per `SendMessage` anstoßen, selbst `swift test --filter <Modul>` laufen lassen. Worker einer früheren Sitzung sind nicht erreichbar: warten, bis er committet hat, Stand selbst prüfen.

## Vorlage: Auftrag an einen Worker
```
Du bist Bauagent für ALFAcolor. Arbeite im Repo /Users/johannesleoberger/Developer/ALLFARBEN auf main. Lies AGENTS.md (alle Regeln gelten) und plan/briefe/<B-xxx>.md, dann arbeite den Brief ab.
Parallel arbeiten <andere Briefe> an <deren Pfaden>: nicht anfassen. Gemeinsame Dateien (Katalog, Package.swift, project.yml, lizenzen.txt) in dieser Runde: <Besitzer>.
Nur eigene Pfade committen. <Kein Push. | Push nach grünem Lauf.> Kein Browserfenster, App nie starten.
Am Ende: pruefen.sh, Übergabe im Brief, Status „zur Prüfung“. Antwort kurz: Commits, Belege, Abweichungen, offene Punkte.
```

## Prüfen
1. `git status` sauber, `git log` nur eigene Pfade; Übergabe im Brief lesen; `bash scripts/pruefen.sh` selbst laufen lassen. Kleines selbst entscheiden und im nächsten Brief festhalten; was Aussehen oder Verhalten ändert, als Frage an Johannes sammeln.
2. Status im Brief auf „erledigt, geprüft <Datum> (Chef: …)“, „Abnahme am Bild offen“, wo es zutrifft. Commit, sofort `git push origin main`.

## App für Johannes
- Erst wenn `pruefen.sh` grün ist und kein Worker läuft. Entwickler-Bau: `cd ALFAcolor && xcodegen generate && xcodebuild -scheme ALFAcolor -destination "platform=macOS" -derivedDataPath ../.build-xcode/dd build`.
- Notarisierte Fassung: `xcodebuild archive … -derivedDataPath .build-xcode/dd -archivePath .build-xcode/archive/ALFAcolor.xcarchive`, `-exportArchive` mit `ALFAcolor/Config/ExportOptions-DeveloperID.plist`, `xcrun notarytool submit … --keychain-profile setzkasten --wait`, `xcrun stapler staple`, nach `dist/ALFAcolor.app` und `dist/ALFAcolor-<fassung>.zip`; alte Fassung dort löschen. `dist/` ist ignoriert. Fassung in `ALFAcolor/project.yml` (`MARKETING_VERSION`, `CURRENT_PROJECT_VERSION`) erhöhen.
- Alle 10 Builds eine DMG (`CURRENT_PROJECT_VERSION` durch 10 teilbar: 10, 20, …): `hdiutil create` aus der notarisierten App, DMG notarisieren und heften, nach `dist/ALFAcolor-<fassung>.dmg`.
- Absturzberichte: `~/Library/Logs/DiagnosticReports/ALFAcolor-*.ips` (lesen, nicht senden).

## Ende der Sitzung
Genau ein Zettel in `uebergabe/` (≤ 40 Zeilen, `JJJJ-MM-TT_HHMM_chef-handoff.md`, den alten ersetzen): Stand, nächste Schritte, offen bei Johannes, Lehren. Committen, pushen.

## Wenn etwas klemmt
- Worker bricht ohne Bericht ab: `git status` lesen, per Nachricht um Bericht ohne weitere Änderungen bitten, Rest neu vergeben.
- Brief zu groß (> ein Tag oder 600 Zeilen): in a und b teilen. Entscheidung fehlt: `konzept/OFFENE-FRAGEN.md` mit Vorschlag, Johannes fragen; nicht auf Annahmen bauen.
- `Package.swift` mit `.macOS(.v26)` scheitert: Plattform bleibt `.v15`, macOS-26-APIs mit `@available(macOS 26.0, *)`.
- Fremde ZIPs (`~/Downloads`): in einen neuen leeren Ordner im Scratchpad entpacken, nie ins Repo, nichts ausführen.
