# Status

Quelle der Angaben: Briefköpfe in `plan/briefe/`, `git log` bis 2026-10-09 23:45, Zettel in `uebergabe/`. Neu geprüft hat sie bei dieser Straffung niemand. Brief-Index = Ordner `plan/briefe/` (B Bau, D Design, P Konten, C Codex ruht); Status steht im Brief.

## Stand
- Version 1.0.0 (6) notarisiert in `dist/` (nicht im Git). `pruefen.sh` 0 errors (Chef, 2026-10-10 00:10, nach B-821, B-823, B-824).
- **Im Programm wirkt noch nicht (Version 1.0.0):** Sicherung, Absturzkopie, Rückgängig nach Neustart, Chat-Speicher, Assistent mit Brett, Lesezeichen- und Gist-Import. Die Pakete sind getestet, die App ruft sie nicht auf (Cloud-Review 2026-10-09, von mir nachgeprüft 2026-10-10).
- Abgenommen: B-821 (Layout-Prüfstand, 11 Tests, 4 bekannte Fehler: Token-Satz-Knöpfe der Seitenleiste brechen bei 200/240/320 und in der Fensterspalte), B-823 (Aufräumen), B-824 (Modul `app/Sources/CodePlayer`).
- Konto B (Design): D-007 (System, Phase 1) läuft, D-008 (Ansichten als HTML-Entwürfe) folgt im selben Projekt. Konto C und Codex ruhen.
- Gates entfallen. Branches: nur `main`; Zweige `knoten/*` folgen nach dem Umzug.

## Laufende Briefe
- B-822: Labor-Vorschau, React-Karten über den TypeScript-Pfad; Commits `d90fac5`, `4159136`; nicht geprüft.

## Nächste Schritte
0. Abnahme Johannes 2026-10-10 (Bilder der 1.0.0), Vorrang vor allem anderen:
   - Linke Spalte: Werkzeuge in Symbolgruppen mit Hover-Hinweis; Bausteinsammlung (Farbpaletten wie in Photoshop, Rahmen, Maße, Einrasten, Knöpfe, Pillen, Schalter, Standardelemente). Token-Satz-Knöpfe brechen in Silben.
   - Rechte Spalte (Inspektor) bricht: Werte rechts abgeschnitten, Beschriftungen links abgeschnitten. Unbenutzbar.
   - Code-Player: zu kompliziert. Ziel: alles einfügen, automatisch erkennen, kurze Fragen, dann spielbare Karte; auf der Leinwand ablegbar und eigenständig; Claude-API liest, versteht, baut nach, bearbeitet. Heute: "No component found", "Keine CSS-Variablen gefunden".
1. Reparaturbrief aus den 4 bekannten Fehlern von B-821 (Sollbreiten klären, siehe Offen); B-822 prüfen; Nachtrag `.jsx`-Karten, mehrzeilige Importe in `stripModules`, `useReducer`/`useContext`/`forwardRef`.
3. Spezifikation Code-Player aus `plan/gates/codeplayer-1..5` und `konzept/10-MODUL-CODEPLAYER.md` schreiben (M1 bis M5), offene Punkte mit Johannes klären.
4. Anschlüsse: Sicherung/Journal (B-812), Reiter KI mit Stufen (B-814b), Chat (B-808b, wartet auf Design D-008).
5. B-820 Tests verdichten; Git Stufe 1 (Lesen); `scripts/lizenzen.txt` um fancy, blocks, motion-primitives ergänzen.
6. Offene Briefe: B-402, B-505, B-602, B-603, B-605, B-701, B-702, B-802 bis B-804, B-811, B-903 bis B-905 (siehe Köpfe).

## Offen bei Johannes
- D-007 Phase 1 liefern lassen und als ZIP zurückgeben.
- Cloud-Paket 2 (`ausgang/cloud-attrappen_2026-10-10.zip`) starten, mit den drei Korpus-ZIPs.
- Seitenleiste und Inspektor: gleiche Zustände (ausgeblendet, nur Symbole, schmal, normal, breit), Arbeitswerte 240/300/380; Design (D-008) darf verfeinern.
- Gamut-Auslegung (Anzeige P3), Offline-Bündelgröße (Babel 2,3 MB, Tailwind 282 KB), GSAP/p5-Lizenzfrage, Cloud-Paket 2 „Attrappen und Korpus-Fabrik“.
- Abnahme am Bild für alles seit 0.2.2.
