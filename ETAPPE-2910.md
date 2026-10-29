# Etappenprotokoll · 29.10.2026 · Mail, Einstellungen, Hülle
Arbeitsstand, nicht freigegeben (CLAUDE.md). Wortlaut aller Ansagen: `entscheidungen.md` (Ende, ab Zeile 532).

## 1 · Soll und Ist
| Soll | Ist | Beleg |
|---|---|---|
| Vertrag gültig, stimmig, Protokoll passt | P1 [] · P2 [] · P3 829/829 | Lauf 2026-10-29T16:00 (contract/PRUEFUNG.txt) |
| Prüfprogramm grün | pruefung.js grün, keine Fehler | Lauf 16:00 |
| Lieferpunkte 44 | 37 erledigt · N15 Frage · N27–N31, N33 offen (Hub, wartet auf Code) | contract/LIEFERUNG.json items |
| Jedes Bauteil der Bögen im Vertrag | Mail 54 · Einstellungen 34 · Hülle 30 · Bestätigen 6 Teile, 0 fehlen | data-part der Bögen gegen contract/components.json |
| Keine losen Werte in style-Attributen | 0 in Mail, Einstellungen, Bestätigen · Hülle 1: max-width:240px am Hinweis | t10-literals.js · ALFA Shell.dc.html:23 |
| Zustände je Bauteil (A6) | 59 von 97 Bauteilen, 112 Zustände mit Tokens | contract/components.json |
| Logik ohne feste Zahlen (A1) | rund 58 Tokens, deren Wert noch als Zahl in der Logik steht (Liste Abschnitt 4) | Zählung 29.10. |
| Texte | 388 Einträge | contract/texts.json |

## 2 · Zuletzt ausgeführt (28.–29.10.)
- Entwurf: Textfeld wächst mit, nur die Karte scrollt (ALFA Mail.dc.html:263).
- Dunkel: Einstellungen, gewählte Kachel und Zahl in gewählter Zeile in Auswahlfarbe (c-inv/c-on-inv).
- Kapsel „Gesperrt“ in fünf Bögen: Abstände der 4er-Leiter, Farbe sichtbar; Tokenbogen und Icon laden alfa-theme.css.
- A6: 59 Bauteile mit Zuständen, durch Durchklicken aller Fehler- und Menüzustände.
- A1: Drücken/Hover (55 Stellen), Übersicht-Kachel, Menügröße, Blob, Umbrüche, Fächerschritt, Kartenkopf, Filterknopf, Bestätigen (Radieren/Zittern) auf Tokens. Werkzeug: AlfaShell.tok(name); t9-css.js nimmt Gruppe confirm.
- Einstellungen: Feldzeile rechts 16 wie links (ALFA Einstellungen.dc.html:113).
- Bildlaufleiste nur beim Scrollen, kein seitlicher Scroll (alfa-shell.js, data-alfa-bar in 11 Flächen).
- An Code (lieferung-an-code/AN-CODE-2810.md:27–30): Happa Happa nicht einrichtbar, DHL zweigeteilt, DHL-Prüfung meldet immer Erfolg, Google nur mit Client-Konfiguration.
- Projektakte aufgeräumt (Abschnitt 5).

## 3 · Unerledigte Papercuts
1. Bild 14.33 (Einstellungen, rechte Bahn gefaltet, mittlere Bahn leer): nicht nachgestellt. Frage an Johannes offen: bleibt leer oder nur kurz?
2. Hülle: Hinweis max-width:240px ohne Token (ALFA Shell.dc.html:23).
3. Hülle: Blob-Breite 6 + 28 + 8 (ALFA Shell.dc.html:175) und Stapelköpfe 8 (Mail :782, Einstellungen :429) ohne passenden Token.
4. A6: 4 Fälle mit Farbe je Ort verschieden (mark, symbol-button, counter Ruhe, card-header Ring) — Entscheidung je Ort.
5. Demo-Werte in Einstellungen („vor 2 Minuten“, „9. Okt.“, „Projekte 412 von 1.280“) nicht gekennzeichnet (Nacharbeit 7).
6. Werkzeuglücke: apply.js schreibt neue Themenfarben nicht in alfa-theme.css (Nacharbeit 6).
7. lieferung-an-code/akte.json, Feld material: nennt s1–s7.png und entwuerfe-v3.zip (jetzt ARCHIV) und clockodo.png als benutzt (benutzt wird clockodo-kreis.png). Nur über lauf.js/apply.js zu ändern.
8. SPEC.md Stand 21.10., Abgleich mit Codes Spec offen.

## 4 · Logikzahlen noch ohne Token (A1, Rest)
Wert steht als Zahl in der Logik von Mail/Einstellungen/Hülle; viele kommen so oft vor, dass jede Stelle einzeln zugeordnet werden muss.
size: cardInset 0, blobPopupFallbackWidth 280, blobEye* 4/8/4, suggestionRowHeight 44, chipHeight 24, headPad*/headGap* 8/16/8/8/4, menuEdge 8, menuSeparatorInset 12, menuSeparatorSpace 4, assistantFieldHeight 40, trailingTextInset 12, handleLength 64/96, handleThicknessActive 2, composeColumnMinWidth 96, toggleKnobOffset 14/2, selectionRingWidth 2, blobLidOffset 1.4, confirmEnterBlur 3, blobDragThreshold 3, blobHomeRadius 200, overviewActionsOffset 6, reelTopOffset 8, accountFanWidth 220, accountClosedWidth 260, stackDrop*/stackFlat* (Schatten), statusDot 8 · radius.cardBottom 0 · typography: semibold 600, lineHeight title 1.25 / mailBody 1.6 · motion: tileActions 240, searchFocusDelay 40 · count: stackMaxCards 6, contactSuggestions 5, senderSuggestions 8, stackHeads 3 · opacity: ringOnColor 0.3, ringOnMark 0.22 · layer: syncButton 3, safeArea 7, inLane.overview 2 · confirm.originDefault 40.
(Übersicht-Größen size.overviewTile* und count.overviewLines* sind über ovZ() angebunden, zusammengesetzter Name.)

## 5 · Nicht erfolgte Kontrollen
- Halten am Bestätigen-Knopf live (Vorschau verborgen; nur Rechengegenprobe an 8 Füllständen).
- Echtes Falten einer Bahn im sichtbaren Fenster (Übergänge im Hintergrund angehalten).
- Dienste im Dunkel-Modus; Widgets dunkel.
- Bildlaufleiste mit „Rollbalken immer einblenden“ (Mac-Einstellung) im echten Browser.
- Verbindungen der Konten real (nur Code gelesen, keine Anmeldung getestet).

## 6 · Projektakte
Projektstamm = Entwurfsordner. Die Werkzeuge (contract-build/lauf.js, apply.js, lieferung-an-code/pruefung.js) lesen die Bögen am Stamm; deshalb liegen sie dort.
- Entwurf: ALFA Mail, ALFA Einstellungen, ALFA Shell, ALFA Bestaetigen (Hülle-Teile); weitere Bögen ALFA Dienste, Widgets, Designsystem, Tokenbogen, Icon.
- Laufzeit und Werte: alfa-shell.js, alfa-bausteine.js, alfa-theme.css, TOKENBOGEN.json, INHALT.json, support.js.
- Vertrag: contract/ · Werkzeuge: contract-build/ (previous/2026-10-23T-vor-uebergabe bleibt, lauf.js liest es) · Code-Brief: DESIGN/brief/.
- An Code (Lesereihenfolge lieferung-an-code/START-CODE-2810.md): AN-CODE-2810, ANTWORT-2810, OFFEN-AN-CODE-2710, ENTSCHEIDUNGEN-AN-CODE-2310, SPEC-NACHTRAG-2310, *.json, fonts/.
- Material: material/icons (benutzt), material/logos (Originale).
- Führung: CLAUDE.md, START-HIER-NEUE-SITZUNG-2810.md, entscheidungen.md, github.md, dieses Protokoll.
- uploads/ unverändert (Eingänge von Johannes).
- ARCHIV/: alles Überholte, Doppelte, Altmaterial — Liste in ARCHIV/INHALT.md.
