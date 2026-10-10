# Status

Quelle der Angaben: Briefköpfe in `plan/briefe/`, `git log` bis 2026-10-10 17:05, Zettel in `uebergabe/`. Der Zettel ist neuer als diese Datei und gilt bei Widerspruch. Brief-Index = Ordner `plan/briefe/` (B Bau, D Design, P Konten, C Codex ruht); Status steht im Brief.

## Stand
- Version 1.0.2 (8) notarisiert in `dist/` (nicht im Git). Abnahme am Bild steht aus.
- **Im Programm wirkt noch nicht (Version 1.0.2):** Sicherung (`BackupStore`), Absturzkopie (`CrashAutosave`), Chat-Speicher, Assistent mit Brett, Lesezeichen- und Gist-Import. Die Pakete sind getestet, die App ruft sie nicht auf (Cloud-Review 2026-10-09, von mir nachgeprüft 2026-10-10).
- **Neu im Programm (Quelltext, Tests, nicht am Bild gesehen; 2026-10-10):** Rückgängig-Verlauf (bis 20 Schritte) kommt nach dem Neustart zurück. Jede Änderung schreibt `history/undo.json` im Hintergrund ins Paket, Schließen und ⌘Q warten darauf. Das Journal trägt eine Brett-Prüfsumme; passt sie nicht, wird es verworfen (F04). `AutosaveSchedule` ist gelöscht (F03).
- Abgenommen: B-821 (Layout-Prüfstand, 11 Tests, 4 bekannte Fehler: Token-Satz-Knöpfe der Seitenleiste brechen bei 200/240/320 und in der Fensterspalte), B-823 (Aufräumen), B-824 (Modul `app/Sources/CodePlayer`).
- Design: Entwurf 4 „ALFAcolor Werkbank“ (Artifact, Adresse im Zettel) ist die Vorlage für Hülle, Bahnen, Blob, Farbe und Tokens. Die App ist noch nicht danach gebaut. D-007 und D-008 sind überholt (vier Farbwelten). Konto C und Codex ruhen.
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
4. Anschlüsse: Sicherung und Absturzkopie (B-812, Journal steht), Reiter KI mit Stufen (B-814b), Chat (B-808b, wartet auf Design D-008).
5. B-820 Tests verdichten; Git Stufe 1 (Lesen); `scripts/lizenzen.txt` um fancy, blocks, motion-primitives ergänzen.
6. Offene Briefe: B-402, B-505, B-602, B-603, B-605, B-701, B-702, B-802 bis B-804, B-811, B-903 bis B-905 (siehe Köpfe).

## Offen bei Johannes
- Cloud-Paket 2 (`ausgang/cloud-attrappen_2026-10-10.zip`) starten, mit den drei Korpus-ZIPs.
- Hülle nach Entwurf 4 jetzt in die App bauen, oder erst Code-Player fertig? Grund im Vollbild: weiß oder hellgrau? D-007 streichen und D-008 auf Entwurf 4 stellen?
- Gamut-Auslegung (Anzeige P3), Offline-Bündelgröße (Babel 2,3 MB, Tailwind 282 KB), GSAP/p5-Lizenzfrage, Cloud-Paket 2 „Attrappen und Korpus-Fabrik“.
- Abnahme am Bild für 1.0.2 und alles seit 0.2.2.
