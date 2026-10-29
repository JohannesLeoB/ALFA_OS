
Export: 19.10.2026

> **Veraltet im Hauptteil (19.10. abends).** Gültig ist `HANDOFF-SESSION-4.md`. Aufgabe 1 (Trennung) ist erledigt, der Anhang unten ist weiter lesbar.

# Übergabe an den nächsten Design-Chat · Stand 19.10.2026, 00:40 MESZ

## Startprompt (so in den neuen Chat kopieren)
> Du übernimmst die Design-Sitzung ALFA (macOS-26-App, Swift/Claude Code). Lies zuerst vollständig: CLAUDE.md, UEBERGABE-NAECHSTER-CHAT.md, ABNAHME.md, AUDIT-BERICHT.md, entscheidungen.md (ab 18.10.), lieferung-an-code/akte.json, github.md. Jede Aussage, jeder Wert, jede Änderung braucht einen Beleg mit Datei und Zeile oder Johannes' Wortlaut aus entscheidungen.md – sonst „designSet“ und auf ALFA Entscheidungen zeigen. Code übernimmt alle Maße von Design. Hülle nur einmal (ALFA Shell, alfa-shell.js). Keine ZIPs ohne Johannes' Freigabe („raus“). „Fehlerfrei geladen“ beweist nichts – messen (Übergänge für Messungen abschalten, das Prüf-Fenster rendert keine Frames). Lauf `lieferung-an-code/pruefung.js` nach jeder Änderung (grün oder rot). Arbeite ABNAHME.md „Zu erledigen“ in der Reihenfolge unten ab, ziehe danach akte.json, RUECKGABE-AN-CODE.md, AUDIT-BERICHT.md und entscheidungen.md nach und melde „fertig“ nur, wenn alle zwölf Zeilen in ABNAHME.md ✅ sind. Johannes' neue Worte sofort wörtlich in entscheidungen.md, mit Uhrzeit (deutsche Zeit).

## Reihenfolge
1. **Trennung Mail/Einstellungen** (größter Umbau). Heute trägt `ALFA Mail.dc.html` (1100 Zeilen) die Logik beider Bereiche (Prop `area`). Ziel: `ALFA Mail v2` und `ALFA Einstellungen v2`, gemeinsam genau einmal: Hülle (ALFA Shell, alfa-shell.js), Zeile, Kartenkopf, Kartenfuß, Menü, Toast, Zustandswörter (`csOf`). Inventar der Teile: ABNAHME.md und die Zeilennummern in der Rubrik „Aufgabe 1“ weiter unten. Beide bei 1512 × 982 hell und dunkel gegen heute messen (Bahnen, Köpfe, Zeilen, Karten, Kontrast), erst bei Gleichheit die alten ersetzen.
2. **Break-UI-Lauf** („Zuerst prüfen“, Johannes 18.10.): `uploads/SKILL.md` und `uploads/CATALOG.md`. Erst Bericht, nichts ändern, dann Freigabe holen.
3. **Kontrast** der übrigen Zustände (ALFA Mail, Übersicht, Schreiben, Fehler, Kontextmenü, Toast), hell und dunkel. Bereits gemessen: Einstellungen Ausgangszustand, Blob-Menü, Assistent.
4. **Blob über Menü und Toast**: Überlappung im Bild messen (heute nur: Blob liegt an seiner Mitte oben, z 6).
5. **Textstile** (`typography.textStyle.*` angelegt): Apple-Zuordnung und Dynamic Type mit Johannes klären.
6. **ALFA Huelle** und **ALFA Farbsystem**: Löschen oder behalten, Johannes entscheidet.
7. **Assistent ausarbeiten** (To-do, Johannes 18.10.: „bitte als Tod Do merken!“): Zustände, Eingabe, Verlauf, voller Ansichtsbereich, Menüeintrag.

## Von Johannes offen
- `size.focusRingOffset`: 19.10. auf 1 gesetzt (alfa-theme.css:6, Token, Bestätigen).
- Kachelhöhe 112 (2 × 56, jetzt) oder 96.
- Menü „Diagonale Toleranz“: beantwortet, nicht gebaut; Blob-Hover wechselt heute nach 160 ms Stillstand.
- 87 Tokens `designSet` auf ALFA Entscheidungen 6 (kein Wort von Johannes).
- Repo: Code liest die neuen Werte noch nicht (design.stamp.json). Abweichungen Code gegen Entwurf: ALFA Huelle, github.md.

## Was neu gebaut ist (18./19.10., alles in entscheidungen.md belegt)
Blob-Orb (Vorgabe Orb), „Assistent“ im Blob-Kopf; Toast 8 über dem Kartenfuß; Kontextmenü: Breite nach Inhalt auf 56er-Raster (168/224/280) und Ausrichtung nach Lage in der Bahn; Doppelklick auf gefaltete Bahn = Ruhemaß; Symbol in gefalteter Bahn öffnet genau diesen Eintrag samt Bahn; freie Fläche = letzter Zustand; Kacheln (Radius 12, Höhe 112, Hover-Schatten, Drücken 0,98, scroll-snap je Reihe, Gruppentitel im Kopf); Haarlinie unter dem Kopf nur beim Scrollen; Ebenen `layer.*` (Blob 6 über Menü 5, Toast 4, Notch 7); Status englisch (designSet, approved, provisionalApproval); CSS-Vertrag englisch (`data-appearance`, `data-ground`; Werte light/dark, white/lightGray, lacquer/glass/flat, hairline/fine); `bauteile.json` (75), `mechanik.json`, `motion-springs.json` „apple“, `AUDIT-BERICHT.md`.

## Nicht tun
Keine Werte ohne Johannes' Wort ohne Status `designSet`. Keine ZIPs. Keine Navigation Mail → Einstellungen. Keine farbigen Kanten. Tooltips = System (`title`). Kein Liquid Glass (Johannes 18.10.: „lassen wir liquid glass fürs erste“). Keine Mono.

## Aufgabe 1 · Inventar `ALFA Mail.dc.html`
Gemeinsam: P, LEVELS, state/geo/lay/grow/mem/setMem, anim/still/frame, openMenu/menuW/menuX/mi/tb, toastIt, csOf, row/toggleRow/notice, renderVals-Gerüst (Bahnen, Stapel). Nur Mail: FOLDERS, LABELS, ME, seed*/data*/manyMsgs, mailList … send/reply, Kontakte, Übersicht. Nur Einstellungen: CATS, SVC, SET, CATSET, svcStates, openSet/closeSet/setSvc/connect/syncNow/tog, blocks, setEntries/setTitle, Kacheln (Template), Karte `c.isSet`. `isMail`-Weichen in renderVals. Vorschlag: gemeinsame Teile als Hilfsdatei (`alfa-bausteine.js`, global wie `alfa-shell.js`).

## Anhang · Die wichtigsten Infos (19.10.2026, 00:50 MESZ)

### Johannes' Entscheidungen 18./19.10. (Wortlaut: entscheidungen.md, Datum und Uhrzeit dort)
- Schnitt 600 übernehmen. Blob, Orb im Blob, Weichzeichnung und Versatz sind freigegeben (Ausnahmen von der 4er-Leiter). Statuspunkt 8, Empfängerzeile 8, Ring um Etikett = 2 + Haarlinie.
- Menübreiten auf das 56er-Raster, Ausrichtung nach Lage in der Bahn. Menü: „Diagonale Toleranz“ (nicht gebaut).
- Blob weicht der Maus **nicht** aus (Variante ①: „Ich muss den BLOB ja klicken können“). Augen folgen der Maus ist gebaut.
- Gefaltete Bahnen: Symbol öffnet genau diesen Eintrag samt Bahn; freie Fläche = letzter Zustand; Doppelklick = Ruhemaß.
- Kacheln: Form wie vorher (Radius 12), nur Kante der Stapelkarten, dann „ohne Hairline“; in Ruhe ohne Kante, beim Überfahren Schatten; Einrasten als „Walze“ (Kachel oben auf Abstand); Gruppentitel im Kopf statt „Verbindungen“.
- Haarlinie unter dem Kopf: nur beim Scrollen langsam ein, im Ruhezustand wieder aus. Verlauf („Scroll-Kante“) verworfen („zu heavy“).
- Liquid Glass später. Zeitstempel deutsche Zeit. Export-Datum in jeder Datei. „Break UI“: erst prüfen. Assistent ausarbeiten = To-do.
- Bezugsregel (bestätigt: „so hatte ich das gehofft“): Teile der Hülle (Blob, Assistent, Bahnen, Griffe, Köpfe, Menü, Toast, Falten) gelten für beide Ansichten; Inhalt (Kacheln, Zeilen, Karten) für die Ansicht, in der er sitzt. Nachfragen: „nur Mail“, „nur Einstellungen“ oder „beide“.

### Tweaks (Props der Bögen, englisch seit 19.10.)
area (Mail|Einstellungen), appearance (light|dark), ground (white|lightGray), typeface (system|geist), surface (flat|lacquer|glass; Vorgabe flat), handle (hairline|fine|gray), stack, symbols (ring), settingsGroup, services, assistantFace (eyes|Orb, Vorgabe Orb; im Code noch „Augen“/„Orb“), dataset, draft, recipients, front, highlight.

### Flags und Fallen
- **Prüf-Fenster rendert keine Frames**: Scroll-Ereignisse, Übergänge und requestAnimationFrame laufen nicht. Für Messungen `*{transition:none!important}` einfügen; Animationen und Einrasten nur mit echter Maus bestätigbar.
- Einrasten der Kacheln jetzt **CSS scroll-snap (y mandatory)** auf jeder Kachel, Gleiter entfernt. Mit echter Maus nicht bestätigt.
- Doppelklick auf gefaltete Bahn: bei zwei anderen gefalteten Bahnen faltet zusätzlich die Mitte auf (Löser gibt der einzigen offenen Bahn sonst alles). Zweite Messung des Prüfers nicht abgewartet.
- Fokus-Abstand: `alfa-theme.css:6` = 2, Bestätigen = 1 (offen).
- `typography.weight.semibold` 600 nur über die Variable-Datei.
- ALFA Entscheidungen 7: die Proben A und B sind überholt (beide entschieden), gehören entfernt oder archiviert.
- ALFA Entscheidungen 6 listet 87 Tokens `designSet` (kein Wort von Johannes).
- Kacheln: Logos für 8 von 10 Diensten fehlen.
- Zustandswörter der Logik und Dienste, `kind: "setting"`, Prop-Werte `System`/`Geist`/`Ring` und Bereichsnamen sind noch deutsch bzw. Eigennamen (Entscheidung offen).
- `pruefung.js` prüft Wertgleichheit, nicht die Rolle; rgba, Grad, Deckkraft und Skalierung in Template-Styles sind nicht erfasst.
- Kartenkopf-Linie (card-header) ist statisch und bleibt.
- Repo (github.md): Code liest die neuen Werte noch nicht; Abweichungen blob-throw 0,12, feste Menübreite, font-mono.
- Federn: `motion-springs.json` „apple“ stützt sich auf Sekundärquellen, nicht auf developer.apple.com.

### Offene Löcher
Trennung Mail/Einstellungen; Break UI; Kontrast in Mail und den restlichen Zuständen; Blob über Menü/Toast im Bild; Textstile ↔ Apple/Dynamic Type; Menü-Zielvorhersage; Assistent; Sperre je Ansicht (Johannes später); ALFA Huelle/Farbsystem löschen?; ZIP erst nach „raus“.


## Nachtrag 19.10.2026
Gelesen und umgesetzt: TRENNUNG-BERICHT.md, BREAK-UI-BERICHT.md, KONTRAST-PROTOKOLL.md, TODO-ABGLEICH.md. `ALFA Mail` und `ALFA Einstellungen` sind getrennt (eigene Logik, `alfa-bausteine.js`); `design-system/` gelöscht; ALFA Entscheidungen: Proben 7 A/B entfernt, neuer Abschnitt 7 Assistent (Entwurf).
