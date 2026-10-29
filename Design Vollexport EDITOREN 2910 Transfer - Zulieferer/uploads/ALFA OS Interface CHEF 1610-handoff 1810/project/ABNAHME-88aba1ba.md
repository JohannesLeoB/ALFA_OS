# Abnahme · Wann ist Design „fertig fertig“? · Stand 18.10.2026, 21:18 MESZ
Export: 18.10.2026

Johannes 18.10.: „wann weiß ich sicher, dass du fertig fertig bist?“

„Fertig“ melde ich nur, wenn **jede** Zeile unten auf ✅ steht. Zu jedem ✅ gehört eine Belegdatei, die du oder die fremde KI öffnen und nachprüfen kann. Ein „lädt fehlerfrei“ zählt nirgends als Beleg.

| Nr | Kriterium | Beleg (Datei) | Stand |
|---|---|---|---|
| 1 | Jeder Wert in jedem Bogen und in jeder Logik (px, ms, ohne Einheit, rgba, Grad, Deckkraft, Skalierung) hat einen Token mit Fundstelle | `lieferung-an-code/werte-abgleich.json`: 0 × „kein Token“ in App-Bögen | ⏳ px/ms/Hex und Logik erledigt (0 ohne Token); rgba/Grad/Deckkraft in Template-Styles offen |
| 2 | Jeder Token hat die passende Rolle, nicht nur den gleichen Wert | `werte-abgleich.json`, Feld `rolle` je Wert | ⏳ |
| 3 | Jeder Token hat `source` (dein Wortlaut, Zeile in entscheidungen.md) oder `status` (`freigegeben`, `freigabe-orange`, `von-design-gesetzt`) | Prüfskript-Ausgabe in `AUDIT-BERICHT.md` B | ⏳ |
| 4 | 4er-Leiter: jede Abweichung ist freigegeben oder steht auf ALFA Entscheidungen 6 | `AUDIT-BERICHT.md` F | ⏳ |
| 5 | Mail und Einstellungen sind zwei Logiken, die gemeinsamen Teile gibt es genau einmal | Messung v2 gegen heute, 1512 × 982, hell und dunkel: alle Maße gleich | ⏳ |
| 6 | Jeder Zustand und Übergang ist beschrieben und gemessen | `lieferung-an-code/mechanik.json` + Messprotokoll | ⏳ |
| 7 | Jedes Bauteil (`data-part`) ist verzeichnet: englischer Name, Rolle, Ebene, Tokens | `lieferung-an-code/bauteile.json` | ⏳ |
| 8 | Keine doppelten oder überholten Bögen; keine toten Verweise; keine Fehlanfragen | `AUDIT-BERICHT.md` G | ⏳ |
| 9 | Federn gegen `motion.*` und Apples SwiftUI-Vorgaben geprüft, mit Quelle | `motion-springs.json` + `AUDIT-BERICHT.md` C | ⏳ |
| 10 | Kontrast ≥ 4,5:1 in jedem Zustand, hell und dunkel | Messprotokoll | ⏳ nur Ausgangszustand |
| 11 | akte.json, RUECKGABE-AN-CODE.md, AUDIT.md, Übergabe sagen dasselbe wie die Bögen | `AUDIT-BERICHT.md` C: 0 Widersprüche | ⏳ |
| 12 | Audit A–G von Design selbst durchlaufen: 0 Funde „blockiert Code“ und 0 Funde „Fehler“ | `AUDIT-BERICHT.md` | ⏳ |

**Danach:** Du lässt die fremde KI prüfen (AUDIT.md). Jeden Fund behebe ich, dann geht es zurück auf Zeile 12. Das Paket gibt es erst, wenn du „raus“ sagst.

## Zu erledigen (Johannes 18.10.: „schreibe das bitte auf als zu erledigen“)
Befund 18.10. (Antwort auf „ist alles auch für Swift code …“), Reihenfolge wie Plan; 2a–2c vor Schritt 3.

| Nr | Aufgabe | Befund mit Fundstelle | Fertig, wenn |
|---|---|---|---|
| 2a | Namen englisch | Statuswerte `von-design-gesetzt`, `freigabe-orange`, `freigegeben`; Felder `formerName`/`where`/`decide` mit deutschem Inhalt; Props `bereich`, `licht`, `grund`, `schrift`, `griff`, `stapel`, `assistentGesicht`; `kind: "setting"`; Zustandswörter der Logik; CSS-Kürzel `--c-ink-2`, `--c-inv` | Prüfskript: 0 deutsche Namen; je alter Name ein `formerName` |
| 2b | Token-Gruppen nach DTCG | `count`, `stack` sind eigene Gruppen | `$type` je Token nach DTCG (dimension, duration, number, fontWeight, cubicBezier, shadow, color) |
| 2c | Eindeutig | `typography.weight.semibold` 600 (Shell:216, Mail:883) gegen 300/400/500; `size.focusRingOffset` 2 (alfa-theme.css:6) gegen 1 (Bestaetigen:19, :27, :28, :38); 7 Menübreiten `size.menuWidth*` | Johannes entscheidet auf ALFA Entscheidungen 6; 0 Widersprüche |
| 2d | Ebenen | z-index nur im Markup: Bahn 1, Griff 2, Abgleich 9, Blob 10, Notch 30, Toast 40, Übersicht/Menü 50 (Shell:24/40/46/52/21, Mail:336/342/311/346) | Tokens `layer.*`; Blob über allem außer Notch, gemessen angedockt links und rechts, mit offenem Menü, Toast, Übersicht |
| 2e | Schrift | Schnitt 600; 300 nur 1 ×; 2 Stellen Systemschrift statt Geist; keine Textstile, keine Laufweite (`.04em`, `.06em` im Markup), kein Dynamic Type | Tokens `typography.textStyle.*` (Größe, Zeilenhöhe, Schnitt, Laufweite, Apple-Entsprechung) |
| 5 | Bauteile | 72 `data-part` ohne Beschreibung | `bauteile.json`: Name, Rolle, Datei:Zeile, Ebene, Zustände, Tokens, Maße gemessen |
| 5b | Grenzfälle | Daten-Schalter `daten` in ALFA Mail vorhanden; Grenzfälle nicht systematisch geprüft | Grenzfall-Lauf nach uploads/SKILL.md (break-ui) je Bauteil, Bericht mit Datei:Zeile |
