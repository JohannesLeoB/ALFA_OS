# Audit-Auftrag · ALFA Design-Akte · Stand 18.10.2026, 21:18 MESZ
Export: 18.10.2026

Für eine fremde KI. Du prüfst, du änderst nichts. Ergebnis ist ein Bericht.

## 1 · Was das ist
Design-Entwürfe für die macOS-26-App ALFA (SwiftUI). Zwei Ansichtsbereiche (Mail, Einstellungen) in einer gemeinsamen Hülle (drei Bahnen, Blob-Menü). Code (Swift) baut nach und muss alle Maße des Entwurfs übernehmen.

## 2 · Regeln, gegen die du prüfst
1. `CLAUDE.md` (drei Regeln: Hülle nur einmal, Belegpflicht, keine ZIPs).
2. `entscheidungen.md`: einzige Quelle für Johannes' Worte, wörtlich, mit Datum. Spätere Einträge ersetzen frühere.
3. Johannes 17.10.: „CODE HAT NICHTS ZU SAGEN WAS MAßE ANGEHT … ER MUSS UNSERE ÜBERNEHMEN“.
4. Namen in Code und Tokens englisch („alles strikt englisch“, 13.10.).
5. Keine Mono-Schrift. Keine Zahlen in Ringen. Keine ⌘-Kürzel auf der UI. Farbe nie auf Aktionen, Signalrot nur für Destruktives. Fremdinhalt (Mail, PDF, Bild) nie eingefärbt. Tooltips = System (`title`). Keine farbigen Kanten an Elementen („NIEMALS never ever diese farbigen kanten“, 17.10.).

## 3 · Quellen der Wahrheit
| Was | Datei |
|---|---|
| Alle Werte (Farben, Maße, Radien, Abstände, Schrift, Bewegung) | `TOKENBOGEN.json` |
| Rechenregeln der Hülle (Breiten, Falten, Akkordeon) | `alfa-shell.js` (Konstanten `K`, `AREA`) |
| Farben als CSS-Variablen | `alfa-theme.css` |
| Johannes' Worte | `entscheidungen.md` |
| Schrift (Geist, OFL) | `lieferung-an-code/fonts/` (geist.css, Variable 100–900, Light/Regular/Medium) |
| Rückgabe an Code | `RUECKGABE-AN-CODE.md`, `lieferung-an-code/*.json` |
| Verzeichnis der Akte | `lieferung-an-code/akte.json` |

## 4 · Die Bögen (10)
`ALFA Mail`, `ALFA Einstellungen`, `ALFA Shell`, `ALFA Bestaetigen`, `ALFA Huelle`, `ALFA Tokenbogen`, `ALFA Designsystem` (Sichtbogen, liest TOKENBOGEN.json, neu 18.10.), `ALFA Dienste`, `ALFA Farbsystem`, `ALFA Entscheidungen` (je `.dc.html`). Rolle je Bogen: `akte.json`. Mail und Einstellungen teilen eine Logik (`ALFA Mail`, Prop `bereich`).

Öffnen: Ordner per lokalem Webserver ausliefern (z. B. `python3 -m http.server`), dann `http://localhost:8000/ALFA%20Mail.dc.html`. Direkt per `file://` laden `fetch` und Skripte nicht. `support.js` ist die Laufzeit der Bögen, nicht Teil des Entwurfs.

## 5 · Prüfaufträge
A. **Werte-Abgleich.** Jede Zahl und Farbe in allen `.dc.html` (Inline-Styles und Logik), `alfa-shell.js`, `alfa-theme.css`, `design-system/*` gegen `TOKENBOGEN.json`. Je Fund: Wert, Datei:Zeile, Token oder „kein Token“.
B. **Belegpflicht.** Jeder Token mit `source` oder `status`: Steht das Zitat wörtlich in `entscheidungen.md`? Tokens mit `status: von Design gesetzt` gesondert auflisten.
C. **Widersprüche.** Derselbe Wert verschieden in zwei Dateien. Ein Wert gegen ein späteres Wort von Johannes. Eine Doku-Aussage gegen den Code.
D. **Hülle nur einmal.** Mail und Einstellungen: identische Hülle (Bahnen, Köpfe 44, Fuß 44, Griffe, Abstände 16/12, Radien 20/12, Blob, Menü, Bewegungen, Hover). Jede Abweichung zwischen den beiden Bögen.
E. **Nomenklatur.** Token-Namen englisch und einheitlich (camelCase im JSON, `--c-*` in CSS, `data-part` in den Bögen). Deutsche Reste, doppelte Namen für dasselbe, verwaiste Namen.
F. **Layout und Raster.** Fluchten, gleiche Abstände, Radien verschachtelt korrekt, Symbolknöpfe auf gleicher Mittellinie, 56er-Raster der Bahnen. Bei 1512 × 982 hell und dunkel.
G. **Vollständigkeit.** Tote Verweise (Dateien, Bilder, `dc-import`), Reste gelöschter Seiten (`ALFA Einstellungen Inhalt`, `ALFA Johannes entscheidet`, `ALFA Tooltip`, `ALFA Bestaetigen Bogen`, `ALFA Shell Bogen`, `PLAN.md`, `HANDOFF-ARBEITSCHAT.md`, `EINSTELLUNGEN-ABGLEICH.md`), veraltete Zahlen (224, 560, 960, 400 als Bahnbreite).

## 6 · Bekannt offen (nicht als Fehler melden, nur bestätigen)
1. (erledigt 17.10.) `size.blobAwakeWidth` 124, sonst Schritt auf 280.
2. Einstellungen: Gruppen gebaut, eine Logik mit Mail; Kacheln als Start nur als Entwurf auf ALFA Entscheidungen.
3. Mehrfachauswahl in ALFA Mail gebaut, nicht abgenommen.
4. `ALFA Farbsystem` nicht entschieden.
5. Freigabe Orange (18.10., Status `freigabe-orange` im Tokenbogen): `confirm.*`, `confirmHold`, `confirmRelease`, `color.dark.onSignal`, `size.trailingTextInset`. Nicht als Fehler melden.
6. `github.md`: letzter Sync 13.10.
7. `ALFA Designsystem` und `design-system/*`: Farben = ersetzte Leiter „Stahl“, nur in diesem Bogen. App-Farben: `alfa-theme.css`.
8. `material/icons/s1–s7.png`, `entwuerfe-v3.zip`: Referenzmaterial, von keinem Bogen geladen.

9. Mail und Einstellungen teilen eine Logikdatei; Trennung geplant (`UEBERGABE-NAECHSTER-CHAT.md`).
10. 24 Tokens mit `status: von-design-gesetzt` (Werteabgleich 18.10., Fundstelle im Feld `where`): kein Wort von Johannes, offen auf `ALFA Entscheidungen` 6. Bei B gesondert auflisten, nicht als fehlender Beleg melden.
12. Exportvermerk 18.10.: jede Datei trägt „Export 18.10.2026“ (meta, Feld, Zeile, Kommentar); Ausnahmen und Gründe in entscheidungen.md (18.10.). Fehlender Vermerk = Fehler.
11. Design-eigener Werteabgleich 18.10.: `lieferung-an-code/werte-abgleich.json` (Gleichheit nur nach Wert). Prüfe gegen: Wert gleich, Bedeutung falsch; Zahlen ohne Einheit, rgba(), Grad, Deckkraft – dort nicht erfasst.

## 7 · Ausgabe
Eine Datei `AUDIT-BERICHT.md`, eine Tabelle je Prüfauftrag A–G:

| Nr | Datei:Zeile | Befund | Beleg (Zitat oder Wert) | Schwere (blockiert Code / Fehler / Hinweis) |

Dazu eine Datei `AUDIT-WERTE.jsonl`, eine Zeile je Wert aus Auftrag A. Keine Vorschläge für neue Werte, keine Deutung von Johannes' Worten.
