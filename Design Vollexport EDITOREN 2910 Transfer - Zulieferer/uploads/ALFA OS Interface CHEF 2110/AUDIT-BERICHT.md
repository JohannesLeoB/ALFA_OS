Export: 18.10.2026
# Audit-Bericht · Design-Selbstlauf · Export 18.10.2026
Von Design selbst ausgeführt (AUDIT.md A–G). Kein Ersatz für die fremde KI. Beleg: `lieferung-an-code/pruefung.js` (grün), `werte-abgleich.json`, `bauteile.json`, `mechanik.json`. Nicht im Render bewegt gemessen (Prüf-Fenster ohne Frames).

| Auftrag | Ergebnis | Beleg | Schwere offen |
|---|---|---|---|
| A Werte | px/ms/Hex der App-Bögen: 0 ohne Token (1037 Werte); Logik: 0 ohne Token, Rest klassiert (Dummy, Simulation, Index, Kürzen, technisch). Nicht erfasst: rgba/Grad/Deckkraft/Skalierung in Template-Styles; Rolle der Template-Werte | pruefung.js, werte-abgleich.json | Hinweis |
| B Beleg | 26 Tokens approved/provisionalApproval: Zitat wörtlich in entscheidungen.md (0 unbelegt). 87 Tokens designSet (kein Wort von Johannes), Fundstelle je Token, offen auf ALFA Entscheidungen 6. Fund: Zitat „gführt“ war als „geführt“ abgeschrieben, korrigiert in 11 Stellen | pruefung.js | Hinweis |
| C Widersprüche | size.focusRingOffset: alfa-theme.css:6 = 2, ALFA Bestaetigen = 1 (offen, Johannes nicht beantwortet) | TOKENBOGEN.json | Fehler |
| D Hülle nur einmal | Mail und Einstellungen laufen über dieselbe Logik und dieselbe ALFA Shell; Abweichung zwischen beiden strukturell ausgeschlossen, im Bild nicht verglichen. Trennung 19.10. gebaut und eingesetzt: ALFA Mail, ALFA Einstellungen, alfa-bausteine.js; im Bild alt gegen neu 0 Abweichungen (Ausgangszustand hell/dunkel, 15 Zustände dunkel); Markup je Seite doppelt | TRENNUNG-BERICHT.md | Hinweis |
| E Nomenklatur | Token-Namen und Status englisch (designSet, approved, provisionalApproval), 75 data-part englisch, Props englisch. Deutsch noch: Prop-Werte (hell/dunkel, weiß, Lack/Glas/flach …), data-licht/data-grund in alfa-theme.css, Zustandswörter in der Logik, Statuswörter der Dienste | bauteile.json | Fehler |
| F Layout | Kachelraster 56/4 (112, 8-er Fuge), Menübreiten 56er, Ebenen layer.*; Hülle 17.10. gemessen, danach nicht neu; Blob über Menü/Toast nur aus z-index abgeleitet, nicht im Bild gemessen; Kontrast gemessen 19.10. (ALFA Einstellungen, hell/dunkel): Ausgangszustand, Blob-Menü, Assistent 0 Fehler; Mail und weitere Zustände offen | TOKENBOGEN.json | Fehler |
| G Vollständigkeit | dc-import: 0 fehlend; Dateiverweise: 0 tot; Reste gelöschter Seiten: 0; Fehlanfrage in Mail (t.logo) und Dienste (ic.src) behoben | Skript 18.10. | – |

## Offen, klemmt
1. Trennung Mail/Einstellungen (Aufgabe 1) gebaut und eingesetzt 19.10. (TRENNUNG-BERICHT.md).
2. Break-UI-Lauf („Zuerst prüfen“, Johannes 18.10.): Teilbericht 19.10. in BREAK-UI-BERICHT.md (nur Mail, Schlimmster Fall); Funde 1, 2, 3, 5 behoben, 4 war Fehlbefund; Rest (Einstellungen, 320 px, Zoom, RTL) offen.
3. Federn gegen Apple: erledigt 19.10., Sekundärquellen belegt, Befund in motion-springs.json „apple“; developer.apple.com selbst nicht abgerufen.
4. Textstile angelegt 19.10., Apple-Zuordnung als Vorschlag im Token (Dynamic Type unter macOS ohne Beleg), Prop-Werte englisch erledigt 19.10. (typeface, symbols, Bereichsnamen bleiben); Kontrast: Einstellungen Ausgangszustand, Blob-Menü, Assistent gemessen, Mail 19.10. gemessen (KONTRAST-PROTOKOLL.md), Fund Mehrfachauswahl behoben; Einstellungen übrige Zustände offen; Blob-Ebene: über Menü gemessen (z 6, elementFromPoint), Toast überlappt in Ruhelage nicht, Docking seitlich offen.
5. focusRingOffset: 19.10. von Design auf 1 vereinheitlicht (alfa-theme.css:6, Token); Johannes: „fokusring“.

## Nachtrag 19.10.
L-015 Fokusring-Abstand 1 und L-016 menu-row 12 / 12 vereinheitlicht (BRIEF-V9-ABGLEICH.md). Zwei Widersprüche aus Brief v9 damit zu.
