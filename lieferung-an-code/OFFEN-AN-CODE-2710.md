# Offen an Code · 27.10.2026
Von Design. Auftrag Johannes 27.10.: „melde bei Code deine nicht erledigten Dinge als durch Code nach Schema zu suchende und an dich nach bedarf zurückzugebende Einträge“.

So arbeitest du damit: Jeder Eintrag nennt, was fehlt, wo du suchst (Schema, Datei) und was du an Design zurückgibst. Rückgabe als Liste `id · Fund · Datei:Zeile`, nur nach Bedarf (wenn du es beim Bauen brauchst). Design zeichnet oder benennt dann und liefert über contract/.

## A · Brief A1: Zahlen in der Logik (BRIEF.txt:27)
- Stand: `alfa-shell.js` liest alle Maße und Zeiten aus Tokens (K, AREA). In den Bögen sind die Stile umgestellt (T10, 21.10.), die Logik nicht.
- Gezählt 27.10. (Zahlen außer 0, 1, 2 im Logikteil): Shell 82, Mail 482, Einstellungen 226, Bestaetigen 14, alfa-bausteine.js 775.
- Davon haben einen Token, werden aber als Zahl geschrieben: 146 (Liste unten C). Ohne Token: unter anderem Lid-Skalierung 0.1 und 0.45 (Shell :142, :266), Doppelklick-Lid 0.08 (Shell :190), Hover der Übersicht 1.012 und 0.988 (Mail :800), Schatten als rgba in der Logik (Mail :627, :698, :800; Einstellungen :433).
- Vorschlag Ausnahmen (von Johannes noch nicht entschieden): Pfade der Symbole, Beispieldaten, Umrechnungen und Mathematik (/ 1000, Math.max(1, …), .5).
- Suche: jede Zahl, die du aus der Logik eines Bogens übernimmst, gegen `contract/base.tokens.json` (Wertgleichheit und Rolle). Rückgabe: Zahl ohne Token, mit Datei:Zeile und Rolle.

## B · Tokens ohne Fundort im Bogen
- `size.recipientPaddingOpen` 8, `size.composeColumnMinWidth` 96, `count.senderSuggestions` 8.
- Suche: dein Code. Rückgabe: baust du sie, Datei:Zeile; sonst streicht Design.

## C · 146 Tokens, die die Bögen nicht per Namen lesen
- 82 als Zahl in der Logik, Fundstelle je Token in `TOKENBOGEN.json` ($extensions.alfa.where, 168 Zeilen geprüft).
- etwa 35 unter Kurznamen in `alfa-shell.js` (jetzt aus Tokens gelesen).
- 3 doppelt zu Abständen: `size.symbolSize` 28, `size.menuRowHeight` 28 (= spacing.step28), `size.chipHeight` 24 (= spacing.step24).
- 26 ohne Zeilenangabe: Zeilenhöhen 1.35, 1.25, 1.6, 1; Kachelmaße der Übersicht (Mail :798); Orb-Umläufe 7000, 9000, 11000; blink, pulse, thinking, searchUnderline, overviewEnter, overviewStagger, tileActions, confirmHold; cardInset 0, radius.cardBottom 0; blobStretchMax 0.16, blobWakeDistance 212.
- Suche: welche davon dein Code liest. Rückgabe: doppelte oder ungenutzte; Design legt zusammen oder streicht.

## D · Lieferschein (contract/LIEFERUNG.json)
- open (nicht gezeichnet): N27, N28, N29, N30, N31, N33, N37, N38.
- question: T5, T6, N15, N20, N26, N32, N35, N43 (Text je Punkt im Lieferschein).
- LIEF-T8: T8 hat keine Zeile im Bogen; `where` ALFA Mail.dc.html:289 ist Platzhalter. Bitte where für Dateiergebnisse (T1, T7, T8) im Schema zulassen.
- Suche: `.claude/memory/spec-*.md` je Punkt. Rückgabe: Daten je Dienst (N28, N29, N31), Quellen (N33), Verlauf und Anhänge (N37), Zustand bei „Assistent ganz aus“ (N38).

## E · Arbeitsliste START-HIER Abschnitt 4, nicht erledigt
- 6 Zeichnen (N27, N28, N29, N31, N33, N37, N38, Abgleich je Bereich, Zeit im Tooltip): offen, siehe D.
- 7 Erst-Setup: offen, wartet auf Wort von Johannes.
- 8 Vermessung (Ringachsen, lange Inhalte bei 280/308/320, Kontrast): in dieser Sitzung nicht gelaufen. Gelaufen: Bahnen (alle Breiten 640–2200, alle Falt- und Groß-Zustände, 0 Funde), Fundstellen der Tokens, Texte de/en.
- 9 Zustandsbogen (jede Mail-Ansicht in vier Modi): nicht gebaut.
- Rückgabe: was du beim Bauen anders misst als der Bogen.

## F · Nicht im Vertrag, nach Bedarf
- Bauteile aus ALFA Dienste und ALFA Widgets (13 data-part, 7 data-id): Johannes 27.10. „nur nach Bedarf“. Brief T3 nennt shell, mail, settings.
- Rückgabe: wenn ein Bereich sie braucht.

## G · Prüfer
- `lieferung-an-code/pruefung.js` liest nur px, ms, Farben und Ebenen im Markup, keine Zahlen in der Logik.
- `contract-build/diff.js` (P3) am 27.10. an `DESIGN/brief/diff_contract.py:85–96` angeglichen. Bitte mit diff_contract.py gegen `contract-build/previous/2026-10-23T-vor-uebergabe` gegenprüfen.

## H · Symbole
- 52 Zeichen als Pfade, bisher nur in alfa-bausteine.js (Objekt P), nicht im Vertrag. Jetzt als lieferung-an-code/symbols.json (Name, Pfad, viewBox 16, Strich 1.3, Enden rund).
- Offen: eigene Zeichen (Pfade) oder SF Symbols? Kein Beleg im Projekt für eine Entscheidung. Rückgabe: deine Wahl; bei SF Symbols die Zuordnung Name → SF-Name, Design prüft das Bild.

## I · Nicht prüfbar von Design
- Swift baubar: Design kann keinen Swift-Build laufen lassen. Geprüft: Token-Namen gültige Swift-Bezeichner (keine Schlüsselwörter, camelCase), jeder Token mit $type und Einheit, Farben mit Komponenten, Verweise auflösbar, Textschlüssel nach texts.schema.json, Platzhalter de = en. Rückgabe: was der Generator (GeneratedTokens.swift, Localizable.xcstrings) ablehnt.
- Ebenen: layer.hint 40 und layer.lockScreen 40 gleich hoch; der Hilfetext erscheint nur an Griff und Blob, die der Sperrbildschirm verdeckt.

## J · Zustände und Bewegung je Bauteil (Brief A6, BRIEF.txt:32)
- Gefunden 27.10. (Skript über Mail, Einstellungen, Shell, Bestaetigen): 39 Bauteile haben im Bogen Zustände oder hover/active/focus, im Vertrag aber nur „rest“. Liste: list-row, account-card, input-field, content-state, lane-content, overview-tile, message-row, mark, text-button, lane-header, card-stack, card, symbol-button, recipient-field, drop-overlay, message-body, card-overview, compose-button, card-header, recipient-row, attachment-chip, address-button, menu-row, settings-tile, connection-status, field-row, option, toggle, area-page, lane, handle, sync-button, blob, thinking-orb, confirm, confirm-open, confirm-no, confirm-yes, confirm-undo.
- Abläufe (flow) stehen für 8 Bauteile: anchored-menu, blob, card, card-stack, confirm-pill, lane, toast, lock-screen. Feld mechanics (Schema) bei keinem Bauteil; Bewegung steht in lieferung-an-code/mechanik.json (blob, lanes, scroll, stack, menu, toast, confirm, tile, reducedMotion) und motion-springs.json, Dauern und Kurven als Tokens (54 duration, 4 cubicBezier, 3 transition).
- Folge laut A6: „Was nicht angegeben ist, baut Code ohne Übergang.“ Bis Design nachliefert: Zustände, Hover und Übergänge aus dem Bogen (style-hover, style-active, data-state, transition im style) und mechanik.json lesen, nicht weglassen.
- Rückgabe: je Bauteil, was dir fehlt; Design trägt Zustände mit Tokens in components.json nach (über apply.js).
