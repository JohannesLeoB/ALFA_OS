> Stand 19.10. abends: Offene Zeilen und Altlasten stehen in HANDOFF-SESSION-4.md Abschnitt 5 und 6.

# Abnahme · Wann ist Design „fertig fertig“? · Stand 18.10.2026, 21:18 MESZ
Export: 18.10.2026

Johannes 18.10.: „wann weiß ich sicher, dass du fertig fertig bist?“

„Fertig“ melde ich nur, wenn **jede** Zeile unten auf ✅ steht. Zu jedem ✅ gehört eine Belegdatei, die du oder die fremde KI öffnen und nachprüfen kann. Ein „lädt fehlerfrei“ zählt nirgends als Beleg.

| Nr | Kriterium | Beleg (Datei) | Stand |
|---|---|---|---|
| 1 | Jeder Wert in jedem Bogen und in jeder Logik (px, ms, ohne Einheit, rgba, Grad, Deckkraft, Skalierung) hat einen Token mit Fundstelle | `lieferung-an-code/werte-abgleich.json`: 0 × „kein Token“ in App-Bögen | ⏳ px/ms/Hex und Logik erledigt (0 ohne Token); rgba/Grad/Deckkraft in Template-Styles offen |
| 2 | Jeder Token hat die passende Rolle, nicht nur den gleichen Wert | `werte-abgleich.json`, Feld `rolle` je Wert | ⏳ |
| 3 | Jeder Token hat `source` (dein Wortlaut) oder `status` | Prüfskript | ✅ 26 belegt, 0 unbelegt, 87 designSet mit Fundstelle |
| 4 | 4er-Leiter: jede Abweichung ist freigegeben oder steht auf ALFA Entscheidungen 6 | `AUDIT-BERICHT.md` F | ⏳ |
| 5 | Mail und Einstellungen sind zwei Logiken, die gemeinsamen Teile gibt es genau einmal | Messung v2 gegen heute, 1512 × 982, hell und dunkel: alle Maße gleich | ⏳ 19.10.: `ALFA Mail`, `ALFA Einstellungen` getrennt, `alfa-bausteine.js` gemeinsam; vor dem Ersatz Ausgangszustand hell und dunkel 0 Abweichungen, 15 Zustände dunkel 0 Abweichungen (TRENNUNG-BERICHT.md). Offen: hell je Zustand, Datensätze neu, Markup der Bausteine je Seite doppelt |
| 6 | Jeder Zustand und Übergang ist beschrieben und gemessen | `lieferung-an-code/mechanik.json` + Messprotokoll | ⏳ beschrieben ✅, gemessen im Render ⏳ |
| 7 | Jedes Bauteil (`data-part`) ist verzeichnet: englischer Name, Rolle, Ebene, Tokens | `lieferung-an-code/bauteile.json` | ✅ 75 Bauteile, Rolle, Fundstellen, Zustände, Ebene; Maße = Inline-Werte, nicht im Render gemessen |
| 8 | Keine doppelten oder überholten Bögen; keine toten Verweise; keine Fehlanfragen | `AUDIT-BERICHT.md` G | ⏳ Verweise ✅, Fehlanfragen ✅; ALFA Huelle bleibt (Register, github.md), ALFA Farbsystem bleibt bis Farbleiter entschieden, design-system/ gelöscht (nicht geladen, 19.10.), Proben 7 A/B in ALFA Entscheidungen entfernt (TODO-ABGLEICH A20, A21) |
| 9 | Federn gegen `motion.*` und Apples SwiftUI-Vorgaben geprüft, mit Quelle | `motion-springs.json` „apple“ + `AUDIT-BERICHT.md` C | ✅ 19.10., Sekundärquellen; Apple-Doku selbst nicht abgerufen |
| 10 | Kontrast ≥ 4,5:1 in jedem Zustand, hell und dunkel | Messprotokoll | ⏳ 19.10. gemessen (ALFA Einstellungen, Transitionen aus): Ausgangszustand hell 65 Texte / dunkel 65 Texte, Blob-Menü offen 4, Assistent 3, alle ≥ 4,5:1, 0 Fehler. ALFA Mail und ALFA Einstellungen 19.10. gemessen (KONTRAST-PROTOKOLL.md): hell und dunkel, Mail 17 Zustände, Einstellungen 7; 2 Funde (Mehrfachauswahl 1:1, tiefe Kartenköpfe 3,5:1) behoben, danach 0 Fehler. Offen: Hover, Fokusring, Symbole ohne Text |
| 11 | akte.json, RUECKGABE-AN-CODE.md, AUDIT.md, Übergabe sagen dasselbe wie die Bögen | `AUDIT-BERICHT.md` C: 0 Widersprüche | ⏳ |
| 12 | Audit A–G von Design selbst durchlaufen: 0 Funde „blockiert Code“ und 0 Funde „Fehler“ | `AUDIT-BERICHT.md` | ⏳ durchlaufen ✅, Fehler offen (siehe Bericht) |

**Danach:** Du lässt die fremde KI prüfen (AUDIT.md). Jeden Fund behebe ich, dann geht es zurück auf Zeile 12. Das Paket gibt es erst, wenn du „raus“ sagst.

## Zu erledigen (Johannes 18.10.: „schreibe das bitte auf als zu erledigen“)
Befund 18.10. (Antwort auf „ist alles auch für Swift code …“), Reihenfolge wie Plan; 2a–2c vor Schritt 3.

| Nr | Aufgabe | Befund mit Fundstelle | Fertig, wenn |
|---|---|---|---|
| 2a | Namen englisch | Statuswerte `von-design-gesetzt`, `freigabe-orange`, `freigegeben`; Felder `formerName`/`where`/`decide` mit deutschem Inhalt; Props `bereich`, `licht`, `grund`, `schrift`, `griff`, `stapel`, `assistentGesicht`; `kind: "setting"`; Zustandswörter der Logik; CSS-Kürzel `--c-ink-2`, `--c-inv` | ⏳ Props englisch 18.10. (Liste akte.json); offen: Prop-Werte, Platzhalter-Namen, data-licht/data-grund, Statuswerte, CSS-Kürzel |
| 2b | Token-Gruppen nach DTCG | `count`, `stack` sind eigene Gruppen | `$type` je Token nach DTCG (dimension, duration, number, fontWeight, cubicBezier, shadow, color) |
| 2c | Eindeutig | ~~Schnitt 600~~ entschieden 18.10. („600 übrnehmen.“); `size.focusRingOffset` 2 (alfa-theme.css:6) gegen 1 (Bestaetigen:19, :27, :28, :38); 19.10. auf 1 vereinheitlicht (Design-Wahl, Brief L-015); ~~7 Menübreiten~~ ersetzt 18.10. (56er-Raster, `size.menuMinWidth`/`menuMaxWidth`) | Johannes entscheidet auf ALFA Entscheidungen 6; 0 Widersprüche |
| 2d | Ebenen (19.10.: Blob-Menü offen: Blob z 6 liegt an seiner Mitte oben, elementFromPoint; Überlappung mit Menü/Toast im Bild nicht gemessen) | z-index nur im Markup: Bahn 1, Griff 2, Abgleich 9, Blob 10, Notch 30, Toast 40, Übersicht/Menü 50 (Shell:24/40/46/52/21, Mail:336/342/311/346) | ⏳ Tokens `layer.*` gesetzt 18.10. (Blob 6 über Menü 5, Toast 4; Notch 7); Messung 19.10.: Mail, Blob über Menü (elementFromPoint blob-face, z 6 über 5); Toast überlappt Blob in Ruhelage nicht; seitlich gedockt nicht gemessen |
| 2e | Schrift (19.10.: textStyle.* und tracking.* angelegt, Schnitt 600 entschieden, Apple-Zuordnung als Vorschlag im Token; offen: Dynamic Type unter macOS ohne Beleg, 2 Stellen Systemschrift) | Schnitt 600; 300 nur 1 ×; 2 Stellen Systemschrift statt Geist; keine Textstile, keine Laufweite (`.04em`, `.06em` im Markup), kein Dynamic Type | Tokens `typography.textStyle.*` (Größe, Zeilenhöhe, Schnitt, Laufweite, Apple-Entsprechung) |
| 5 | Bauteile | 72 `data-part` ohne Beschreibung | `bauteile.json`: Name, Rolle, Datei:Zeile, Ebene, Zustände, Tokens, Maße gemessen |
| 5b | Grenzfälle | Daten-Schalter `daten` in ALFA Mail vorhanden; Grenzfälle nicht systematisch geprüft | Grenzfall-Lauf nach uploads/SKILL.md (break-ui) je Bauteil, Bericht mit Datei:Zeile |

## Später (Johannes 18.10.: „Assistent können wir noch richtig ausarbeiten - bitte als Tod Do merken!“)
| Nr | Aufgabe | Stand | Beleg |
|---|---|---|---|
| 6 | Assistent ausarbeiten | Mini-Chat per Doppelklick, Orb im Blob freigegeben; 19.10.: Zustände Ruhe, Eingabe, Denkt, Verlauf, Fehler als Entwurf in ALFA Entscheidungen 7 (nicht in ALFA Shell gebaut, nicht abgenommen); voller Ansichtsbereich samt Menüeintrag „später“ | Rückgabe 16.10. „Menüeintrag ja, aber später“; Johannes 18.10. |
