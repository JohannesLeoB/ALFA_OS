# Status

Quelle der Angaben: Briefköpfe in `plan/briefe/`, `git log` bis 2026-10-09 23:45, Zettel in `uebergabe/`. Neu geprüft hat sie bei dieser Straffung niemand. Brief-Index = Ordner `plan/briefe/` (B Bau, D Design, P Konten, C Codex ruht); Status steht im Brief.

## Stand
- Version 1.0.0 (6) notarisiert in `dist/` (nicht im Git). Bekannte Zahlen: 1989 Paket-Tests, `pruefen.sh` 0 errors (Chef, 2026-10-09, vor B-823/B-824).
- Code-Player liegt als Modul `app/Sources/CodePlayer` (B-824, Commit `f158874`); Aufräumen B-823 (Dateien eine Ebene höher) gebucht „zur Prüfung“. Beide vom Chef noch nicht abgenommen.
- Konto B (Design) lebt: D-007 (Design-System-Artifact) und D-008 (Ansichten als HTML-Entwürfe), ein Projekt, zwei Phasen; Briefings in `gestaltung/briefing-system/` und `gestaltung/briefing-ansichten/` fertig. Konto C und Codex ruhen.
- Gates entfallen. Branches: nur `main`; Zweige `knoten/*` folgen nach dem Umzug.

## Laufende Briefe
- B-821: Test-Ziel für App-Ansichten und unsichtbarer Layout-Prüfstand; Schritt 1 in `4cfed36`, Spike zuerst; ein Worker hat uncommittete Dateien in `ALFAcolor/AppTests/` (nicht anfassen).
- B-822: Labor-Vorschau, React-Karten über den TypeScript-Pfad; Commits `d90fac5`, `4159136`; Status „vergeben“, nicht geprüft.

## Nächste Schritte
1. B-823 und B-824 prüfen (`pruefen.sh`, `git status`), buchen, pushen.
2. B-821 abschließen (ohne `fittingSize` als Maß), B-822 prüfen; Nachtrag `.jsx`-Karten, mehrzeilige Importe in `stripModules`, `useReducer`/`useContext`/`forwardRef`.
3. Spezifikation Code-Player aus `plan/gates/codeplayer-1..5` und `konzept/10-MODUL-CODEPLAYER.md` schreiben (M1 bis M5), offene Punkte mit Johannes klären.
4. Anschlüsse: Sicherung/Journal (B-812), Reiter KI mit Stufen (B-814b), Chat (B-808b, wartet auf Design D-008).
5. B-820 Tests verdichten; Git Stufe 1 (Lesen); `scripts/lizenzen.txt` um fancy, blocks, motion-primitives ergänzen.
6. Offene Briefe: B-402, B-505, B-602, B-603, B-605, B-701, B-702, B-802 bis B-804, B-811, B-903 bis B-905 (siehe Köpfe).

## Offen bei Johannes
- Design-ZIP nach Konto B tragen und D-007 starten.
- Cloud-Sitzung starten (Paket in `ausgang/`).
- Gamut-Auslegung (Anzeige P3), Offline-Bündelgröße (Babel 2,3 MB, Tailwind 282 KB), GSAP/p5-Lizenzfrage, Cloud-Paket 2 „Attrappen und Korpus-Fabrik“.
- Abnahme am Bild für alles seit 0.2.2.
