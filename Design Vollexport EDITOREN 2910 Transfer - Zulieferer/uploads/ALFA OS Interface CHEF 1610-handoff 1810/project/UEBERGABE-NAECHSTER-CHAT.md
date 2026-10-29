# Übergabe an den nächsten Design-Chat · Stand 18.10.2026, 21:18 MESZ
Export: 18.10.2026

## Startprompt (so in den neuen Chat kopieren)
> Du übernimmst die Design-Sitzung ALFA (macOS-26-App, Swift/Claude Code). Lies zuerst vollständig: CLAUDE.md, UEBERGABE-NAECHSTER-CHAT.md, entscheidungen.md, lieferung-an-code/akte.json, RUECKGABE-AN-CODE.md, AUDIT.md, TOKENBOGEN.json. Jede Aussage, jeder Wert, jede Änderung braucht einen Beleg mit Datei und Zeile oder Johannes' Wortlaut aus entscheidungen.md – sonst nicht setzen, sondern als „von Design gesetzt“ markieren und auf ALFA Entscheidungen zeigen. Code übernimmt alle Maße von Design; Design gibt Namen und Werte vor. Hülle nur einmal (ALFA Shell, alfa-shell.js). Keine ZIPs, keine Downloads ohne Johannes' Freigabe. „Fehlerfrei geladen“ beweist nichts – messen. Arbeite die Liste „Johannes' Aufträge“ und Aufgabe 0 und 1 der Reihe nach ab, ziehe nach jedem Schritt Tokenbogen, akte.json, RUECKGABE-AN-CODE.md, AUDIT.md und entscheidungen.md nach, und melde erst „fertig“, wenn alles gemessen ist. Johannes' neue Worte sofort wörtlich in entscheidungen.md.

## Zuerst lesen, in dieser Reihenfolge
1. `CLAUDE.md` (drei Regeln: Hülle nur einmal · Belegpflicht · keine ZIPs)
2. `entscheidungen.md` (Johannes' Worte, wörtlich, nach Datum; spätere ersetzen frühere)
3. `lieferung-an-code/akte.json` (Seiten, Rollen, gemessen, offen, Statuslegende)
4. `RUECKGABE-AN-CODE.md` (was an Code geht)
5. `TOKENBOGEN.json` (einzige Quelle aller Werte)

## Stand, geprüft 18.10.
- 10 Bögen, alle laden ohne Konsolenfehler, keine fehlenden Importe, kein Google-Fonts-Link, keine Mono.
- `alfa-shell.js` = `TOKENBOGEN.json` (15 Konstanten gleich). Minima 280/280/280. Wach 124, sonst Schritt 280.
- Hülle bei 1512 × 982 gemessen = Entwurf. Kontrast Mail und Einstellungen hell und dunkel ≥ 4,5:1.
- Schrift Geist lokal (`lieferung-an-code/fonts/`, OFL).
- Status „Freigabe Orange“ = vorläufig abgenommen (Bestätigen, onSignal dunkel, trailingTextInset 12).

## Neu 18.10.
- `size.hairline` 1 (Johannes: „token für haarlinie anlegen bitte.“).
- `ALFA Designsystem` neu gebaut: liest nur `TOKENBOGEN.json`, zeigt die echte `ALFA Mail`. Die alte Fassung hatte eine eigene Kopie der Mail-Logik und Radius 14 ohne Token; beides ist weg.

## Aufgabe 0 · Werte im Markup gegen Tokens
**Stand 18.10., zweiter Chat:** px/ms/Hex abgeglichen, Ergebnis `lieferung-an-code/werte-abgleich.json`. App-Bögen Mail, Shell, Bestätigen, `alfa-theme.css`: 0 Werte ohne Token. Dazu 24 Tokens `von-design-gesetzt` angelegt (Feld `where` = Datei:Zeile), offen auf ALFA Entscheidungen 6. Dienste 11 → 11,5. Entscheidungen 3 Kachel 112 → 132. Offen: Zahlen ohne Einheit in der Logik, rgba() (Mail:926–940 = Glas/Lack, nicht Vorgabe), Grad, Deckkraft; Bedeutung der Wertgleichheit; Dienste-Grautöne Z. 13, 31, 56, 82, 109.

Vorher:
Prüfung 18.10.: 1490 px-Angaben in den Bögen, 153 ohne passenden Token (vor Neubau Designsystem; dessen 42 sind weg). Rest: Mail 19 (Haarlinie 1 → jetzt Token, dazu 308, 96, 48), Shell 6 (Haarlinie), Farbsystem 37 (eigene Schriftgrößen), Dienste 18, Huelle/Entscheidungen/Tokenbogen = Seitenlayout der Bögen. Jeden App-Wert einem Token zuordnen oder als Token anlegen; Bogen-Layout ausnehmen.

## Aufgabe 1 · Mail und Einstellungen trennen
Heute: `ALFA Mail.dc.html` trägt die Logik beider Bereiche (Prop `bereich`), `ALFA Einstellungen.dc.html` lädt sie mit `bereich="Einstellungen"`. Johannes: „MAIL ANSICHT als Page, EINSTELLUNGEN als Page“.
Ziel:
- `ALFA Mail`: nur Postfach, Liste, Stapel, Lesen, Schreiben, Mehrfachauswahl, Übersicht.
- `ALFA Einstellungen`: nur Gruppen (Ich, Firma, Verbindungen, Schutz und System), Abschnitte, Karten (`B`), Dienste (`SVC`), Kacheln bei Verbindungen.
- Gemeinsam genau einmal: Hülle (`ALFA Shell`, `alfa-shell.js`), Bausteine für Zeile, Kartenkopf, Kartenfuß, Menü, Toast, Zustandswörter (`csOf`). Ort: `ALFA Shell` oder eine gemeinsame Hilfsdatei.
Inventar 18.10. (`ALFA Mail.dc.html`, 1092 Zeilen, Logik ab :358): gemeinsam = P, LEVELS, state/geo/lay/grow/mem/setMem, anim/still/frame, openMenu/mi/tb, toastIt, csOf (:703), row/toggleRow/notice (:723–725), renderVals-Gerüst (Bahnen :818, Stapel :919). Nur Mail = FOLDERS, LABELS, ME, seed*/data*/manyMsgs, mailList … send/reply (:574–:700), Kontakte (:687–:693), Übersicht (:951–). Nur Einstellungen = CATS, SVC, SET, CATSET, svcStates, openSet/closeSet/setSvc/connect/syncNow/tog (:716–:722), blocks (:726), setEntries/setTitle (:778–:782), Kacheln (Template :73), Karte `c.isSet` (Template :262). `isMail`-Weichen in renderVals: :796–:956. Offene Frage für die Trennung: gemeinsame Teile als Hilfsdatei (`alfa-bausteine.js`, global wie `alfa-shell.js`) – Hülle bleibt in ALFA Shell.
Vorgehen: Kopie anlegen (`ALFA Mail v2`, `ALFA Einstellungen v2`), Teile trennen, beide bei 1512 × 982 hell und dunkel gegen heute messen (Bahnen, Köpfe, Zeilen, Karten, Kontrast). Erst wenn gleich, die alten ersetzen. Danach `akte.json`, `RUECKGABE-AN-CODE.md`, `AUDIT.md` nachziehen.

## Johannes' Aufträge, noch nicht vollständig erledigt (Wortlaut: entscheidungen.md, Abschnitte 17.10. und 18.10.)
1. **Mail und Einstellungen trennen** („ist Mail und Einstellungen immernoch logisch verzwittert?“) → Aufgabe 1.
2. **Jeder Wert im Markup = Token** („sind dann auch alle token, abstände radien etc korrekt?“) → Aufgabe 0. „Fehlerfrei geladen“ ist kein Beweis; Beweis = Messung gegen TOKENBOGEN.json.
3. **Audit durch fremde KI bestehen** („du willst den audit auf garkeinen fall nicht bestehen!“): AUDIT.md ist der Prüfauftrag. Nach jeder Änderung AUDIT.md, akte.json, RUECKGABE-AN-CODE.md nachziehen.
4. **Ein einziger Bogen für alles Offene** (ALFA Entscheidungen); doppelte, überholte, nutzlose Bögen löschen. Kandidaten prüfen: ALFA Huelle (Register) gegen Tokenbogen/Designsystem; ALFA Farbsystem (Vorschlag) gegen Entscheidungen 5.
5. **Kacheln bei Integrationen**: Namen – Einzüge, Kerning, Ausrichtung verbessern; prüfen, ob verständlichere deutsche Namen oder geläufige Anglizismen besser sind; Rechtsbündigkeit prüfen. Hell und Dunkel 1:1 nach Tokenbogen zeigen. Stand: Frage zur Blob-Namens-Ausrichtung gestellt, keine Antwort.
6. **Wortenden rechts auf einer Linie** („Wieso sind die nicht auf Linie Bündig gesetzt seitlich ??“): in Einstellungen-Karten gemessen; Mail-Liste und Dunkel nicht gemessen.
7. **Bewegung wie Apple** („DRINGEND prüfen, auch wie das in APPLE SWIFT gehandhabt und beschrieben wird!“; „die federn sollten aber auch unser design erhalten“): motion-springs.json gegen TOKENBOGEN.json abgleichen (seit 17.10. nicht geprüft).
8. **Assistent**: später eigener Ansichtsbereich und Menüeintrag („folgt“); heute Mini-Chat per Doppelklick. Nichts bauen ohne Auftrag.

## Offen, Johannes entscheidet (Bogen `ALFA Entscheidungen`)
- Kacheln bei den Integrationen: gebaut, nicht abgenommen; Logos fehlen für 8 Dienste (nur Clockodo, DHL).
- Mehrfachauswahl: in Mail gebaut, nicht abgenommen.
- Farbsystem: Vorschlag, nicht entschieden.
- Blob-Name: Ausrichtung am Gesicht oder rechtsbündig; „Einstellungen“ oder kürzer (Frage gestellt 18.10., keine Antwort).

## Nicht gemessen
**Inline-Werte nie vollständig geprüft:** Abstände, Radien, Schriftgrößen, Farben, die direkt in den Bögen stehen (Mail, Einstellungen, Shell, Bestätigen, Dienste, Designsystem, Entscheidungen, Farbsystem), sind nicht gegen `TOKENBOGEN.json` abgeglichen. „Lädt fehlerfrei“ belegt keinen Wert. Gemessen sind nur: Hülle bei 1512 × 982 hell, Kontrast Ausgangszustand hell und dunkel, Wortenden in den Einstellungen-Karten; verglichen nur alfa-shell.js, alfa-theme.css, alfa-ds-tokens.js gegen den Tokenbogen. Erste Aufgabe vor allem anderen: AUDIT.md Prüfauftrag A selbst ausführen (jede Zahl und Farbe je Bogen, Datei:Zeile, Token oder „kein Token“). `lieferung-an-code/motion-springs.json` gegen `motion.*` prüfen.
Halten mit echter Maus. Zeilen der Mail-Liste nach der Einzug-Vereinheitlichung (12). Wach-Zustand mit echter Maus.

## Nicht tun
Keine Werte ohne Johannes' Wort setzen, ohne es als „von Design gesetzt“ zu markieren. Keine ZIPs. Keine Navigation Mail → Einstellungen. Keine farbigen Kanten an Elementen. Tooltips = System (`title`).
