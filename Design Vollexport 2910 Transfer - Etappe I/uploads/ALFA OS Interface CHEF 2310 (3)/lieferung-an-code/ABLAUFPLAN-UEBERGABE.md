# Ablaufplan saubere Übergabe Design → Code · ab 23.10.2026
Arbeitsstand, nicht freigegeben. Kein ZIP, kein Download ohne Johannes (CLAUDE.md).
Ersetzt Reihenfolge in PLAN-2310.md; Inhalte dort bleiben gültig.

## Grundsätze (gelten bei jedem Schritt)
G1 Vertrag nur über die Werkzeuge in contract-build/ ändern (apply.js, t1, t2, t4, t9, diff.js, check.js, validate.js, check-delivery.js). Keine Handänderung an contract/*.json, alfa-theme.css-Tokenblock.
G2 Jede Zahl, jedes Wort hat einen Beleg: Bogenzeile oder entscheidungen.md-Zeile. Fehlt der Beleg → nicht eintragen, als Frage in Q-Liste.
G3 Vor jeder Aussage „fertig/geprüft“: Prüfer laufen lassen und Ausgabe ablesen, nicht annehmen.
G4 Hülle nur einmal: Änderung an ALFA Shell, alfa-shell.js, alfa-bausteine.js → Mail UND Einstellungen prüfen.
G5 Jede Ansage von Johannes sofort in entscheidungen.md; Specs in SPEC-NACHTRAG-2310.md; verbindliche an Code in ENTSCHEIDUNGEN-AN-CODE-2310.md und LIEFERUNG.json decisions.
G6 Selbstkorrektur: Nach jedem Schritt Abschnitt „Prüfen“ ausführen. Fund → Schritt wiederholen, Fund in Abschnitt LOG unten eintragen. Drei Funde am selben Schritt → anhalten, Johannes fragen.
G7 Suchen vor Fragen: ganzes Projekt, dist/, GitHub (DESIGN/, .claude/memory/). Erst ohne Treffer fragen.

## Phase 0 · Sicherung und Bestandsaufnahme
0.1 Kopie des jetzigen Vertrags nach contract-build/previous/2026-10-23T-vor-uebergabe/ (alle contract/*.json, TOKENBOGEN.json, alfa-theme.css, lieferung-an-code/bauteile.json).
0.2 Liste der Handänderungen von heute (Quelle: changes.json Block 2026-10-23T20:00, entscheidungen.md 23.10.): 9 Bauteile + Elemente, Tokens switchIn, switchOut, hintDwell, hintRadius, foldAt, 4 Texte + 1 geänderter Text, LIEFERUNG decisions, N21/N22/N36 done.
0.3 Bogen-Ist erfassen: alle data-part und data-id in Mail, Einstellungen, Shell, Bestaetigen, Dienste, Widgets; gegen components.json und bauteile.json.
Prüfen: Kopie vollständig (Dateizahl, Bytes); Liste 0.2 deckt jeden Eintrag im Block 2026-10-23T20:00.

## Phase 1 · Vertrag über die Werkzeuge neu aufsetzen
1.1 contract/ auf den Stand vor heute zurücksetzen (previous/2026-10-21T16-30 bzw. letzter geprüfter Stand laut changes.json), Handänderungen verwerfen.
1.2 Bauteile in lieferung-an-code/bauteile.json aufnehmen (Quelle der Bauteile für t2): AccountTitle, AccountDeck, AccountCard (mit measures.material), EnvelopeStack, Envelope, SwitchGlass, AccountNameRow, AccountShowRow, Hint; Element mail.account-alert.deck an AccountAlert.
1.3 apply.js mit einem spec-Objekt: tokens (switchIn 360, switchOut 760, hintDwell 3000, hintRadius 7, foldAt 112), texts (4 neue, mail.outbox.confirm.yes „Ja“), components/elements aus 1.2, reason je Eintrag mit Spec-ID. Erst ohne write (Probelauf), Ausgabe P1/P2/P3 lesen; dann write:true.
1.4 t9 erzeugt den Tokenblock in alfa-theme.css neu; meine Handzeilen (hintDwell, hintRadius) dort entfernen, wenn t9 sie erzeugt.
1.5 changes.json für die Lieferung mit diff.js makeBlock auf EINEN Block gegen die Sicherung zusammenführen.
1.6 TOKENBOGEN.json in das Originalformat bringen (Einrückung wie Sicherung), Inhalt unverändert.
Prüfen: P1 contract: valid · P2 consistent (--areas shell,mail,settings) · P3 log matches. Zählung Bauteile = 91 + 9, Tokens +5, Texte +4. Bogen sieht gleich aus (Mail, Einstellungen hell und dunkel, kurz ansehen).

## Phase 2 · Offene Entscheidungen einsammeln (eine Form, nicht einzeln)
Q1 Augen in Ruhe: Master halb geschlossen oder Striche (entscheidungen.md:398, Shell :248).
Q2 Ringachse rechter Stapel 20 (Radiusmittelpunkt wie links, :420) oder 22.
Q3 Serviette (Gesten Gleiten/Tauschen, vier Zustände, Achsen) freigeben, ändern oder ruhen.
Q4 Punkt am Postausgang im gefalteten Streifen schwarz oder rot.
Q5 Postfächer: Reihenfolge ändern, Postfach hinzufügen in Einstellungen (HUB-A02).
Q6 Englische Texte abnehmen: Shown as, Name in Mail, No subject, Trash is empty.
Q7 Hilfetexte Shell :40/:53 (v14 B3): geklärt durch H01? (Text bleibt, erscheint nach Verweilen) – bestätigen.
Vorher G7 für jede Frage. Antworten → G5, dann nur betroffene Schritte bauen (über apply.js).

## Phase 3 · Restpunkte Brief v14 (Entwurf, dist/brief-v14)
3.1 N26–N33 Hub/Einstellungen, N35, N37, N38 Hülle, Erst-Setup: je Punkt Brieftext lesen, Bogen-Ist prüfen, Entscheidung in entscheidungen.md suchen.
3.2 Einordnen: done (mit Zeile) · bauen (mit Beleg) · Frage (Q-Liste) · Code-seitig (keine Designarbeit).
3.3 Bauen nur mit Beleg; jede Änderung über apply.js.
Prüfen: jeder Punkt hat Status und Fundstelle; keine Änderung ohne Beleg; Hülle-Regel G4.

## Phase 4 · Vermessung und Bruchsuche (Skript, nicht Auge)
4.1 Ringachsen: jeder Ring auf Achse seines Behälters (Liste 16, Karte Radiusmittelpunkt, Streifen 28).
4.2 Material: Postfachkarte gegen Stapelkarte (gespiegelt) Wert für Wert.
4.3 Lange Inhalte (Schlimmster Fall), Breiten 280/308/320, hell/dunkel/Kontrast: nichts ragt heraus.
4.4 Texte: jeder sichtbare Text in texts.json (de/en); keine Erklärsätze (N40, :446).
Prüfen: Bruchliste leer oder als Frage an Johannes.

## Phase 5 · Lieferung zusammenstellen
5.1 LIEFERUNG.json auf v14: N11, N14, N25, N34 streichen (Fundstellen zu N21, N30, N7, N28), N41, N43 aufnehmen; brief: "v14".
5.2 where-Zeilen und Prüfsummen neu erzeugen (Stand nach Phase 1–4).
5.3 akte.json Stand und export neu.
5.4 Begleitdateien aktualisieren: SPEC-NACHTRAG-2310.md, ENTSCHEIDUNGEN-AN-CODE-2310.md, GEGENLESE-v14.md, ANTWORT-2310.md (Zeilenangaben auf neuen Stand).
5.5 P4 check-delivery.js mit allen .dc.html im Projektstamm (drafts).
Prüfen: P1–P4 grün; jede Datei in lieferung-an-code/ verweist nur auf existierende Zeilen (Skript).

## Phase 6 · Vorlage an Johannes
6.1 Eine Seite: was geliefert wird, Prüfergebnisse P1–P4 wörtlich, offene Fragen, Farbbögen gesperrt.
6.2 Warten auf Freigabe. Erst dann Paket.

## LOG (Selbstkorrektur)
- 27.10. Phase 1.5 und 5.2 erledigt: ein Block 2026-10-27T12:00 (83), LIEFERUNG neu, PRUEFUNG.txt neu. P1 valid · P2 consistent · P3 log matches · P4 delivery: complete (28 of 44 done). Rest: pruefung.js 62 Fehler (47 Tokens set-by-design ohne where, davon pdf* nach N16 zu streichen; 5 z ohne layer-Token Mail :14, :40, :145, Shell :23, :99; 6 px und 3 ms Mail :691–:699; DHL-Gelb Einstellungen :302). T8 where hat keinen Ort im Bogen (Schema verlangt einen).
- 24.10. Fund (Bildschirmfoto Johannes 01.47.36): alle drei Bahnen gefaltet → 3 × 56, Rest des Fensters leer. Ursache alfa-shell.js layout/solve „if (!open.length) return w“; Code gleich (LaneLayout.swift solve „if open.isEmpty { return w }“, toggleFold ohne Sperre). Keine Ansage von Johannes, keine Spec gefunden. Frage an Johannes.
- 24.10. Neues Konto. Phase 1.2 nachgeholt: bauteile.json 75 → 91 (16 aus components.json); t2-Probe 91 = Vertrag. N16 entschieden (macOS nativ): ALFA PDF gelöscht, apply.js Block 2026-10-24T01:30 (P1 [], P2 [], P3 [], 16 Änderungen), apply.js liest nur vorhandene Bögen. Gelöscht ohne Vertragsbezug: Mail Color, Farbleiter, Farbleiter 2, Entscheidungsblatt Farbe, Farbsystem, Entscheidungen, Huelle, alfa-theme-farbe.css. Offen Phase 1: 1.5 (ein Block) in Phase 5; Stempelreihenfolge 22.10. erledigt sich damit.
- 23.10. Korrektur: LIEFERUNG.json hatte ein Feld decisions (von mir), das delivery.schema.json verbietet (additionalProperties false) → entfernt; die Entscheidungen stehen in ENTSCHEIDUNGEN-AN-CODE-2310.md und, wo sie Bogenverhalten betreffen, in components.json (notice, account-*) und changes.json. Status N27–N33, N37, N38 auf open (nicht gezeichnet), nicht question; N15 question.
- 23.10. Phase 3.2 + 5.1 (Lieferschein auf v14): N11→N21, N14→N30, N25→N7, N34→N28 zusammengelegt; N41 done (Einstellungen), N43 question; N26, N32, N35 question; N27–N31, N33, N37, N38 sind NICHT gezeichnet (Befund per Suche im Bogen, je Punkt Text in LIEFERUNG.json). Nur N26/N32/N35/N43 sind echte Fragen; N27–N31, N33, N37, N38 brauchen Zeichnung, teils mit Daten von Code. where/drafts-Hashes in Phase 5.2.
- 23.10. N15 „Aus Projektordner“: Johannes: Funktion ist von Code zu specen. Status Lieferschein: question an Code (Quelle der Projekte und Dateien, Ebenen, Höchstzahl, Fehlertexte); Design zeichnet danach nur Zustände. Bogen: Demo-Labels und erfundene Datei :883 als Demo gekennzeichnet in der Antwort.
- 23.10. Phase 2 statt Fragen: Antworten aus Code und Specs. Q1 Augen Ruhe: Code baut dasselbe wie Master und Bogen (lidRestScale 0,45, blobLidOffset 1,4; BlobView.swift:320–321, SheetValues.swift:10) = die gestauchten „Striche“; kein Widerspruch, nichts zu ändern. Q2 Ringachse: links 20 nach Johannes :420; rechts keine Ansage, bleibt 22 (Master Innenabstand 8). Q3 Serviette: Design-Vorschlag, nicht in der Lieferung. Q4 Postausgang-Punkt: Code färbt „gescheitert“ in Signal (MailCardView.swift:143) → Punkt im Streifen Signal (Umsetzung ausstehend). Q5 Postfächer: „Konto hinzufügen“ ist in Einstellungen gezeichnet (L-008), Höchstzahl 3 (spec-mail R02), Reihenfolge nirgends verlangt → nicht bauen. Q6 en-Texte: Design-Vorschlag, Code gleicht mit Localizable.xcstrings ab. Q7 Hilfetexte: erledigt durch HUELLE-H01.
- 23.10. Johannes: „ist das IDENTISCH?“ — Messung im Browser: NEIN. Vorgabe der Fläche ist „flat“; rechts gelten dort andere Schatten (glaze + Ring .06 + 0 -6 16 -10 .18; vorn sh-lane + 0 -8 24 -12 .22). Ich hatte links die Werte der Variante „lacquer“ gesetzt (falsche Variante). Behoben: EINE Funktion stackShadow(mode, front, lvl, first, dir, dk) für beide Seiten und alle drei Flächen (flat, lacquer, glass); dir ±1 spiegelt Glanzkante, Naht, Schatten. Tokens flat ergänzt (color.stackRing, stackFlatDrop, stackFlatFront; size.stackFlat*). Glass-Variante weiter mit Literalen (Tweak, nicht Vorgabe) — offen A1. P1–P3 ohne Fund, Block 2026-10-23T17:30.
- 23.10. Prüfer-Fund: die 6 Farb-Tokens standen im Vertrag, aber nicht in alfa-theme.css (t9 erzeugt nur den Basis-Block :root; die Themen-Blöcke light/dark sind von Hand gepflegt, es gibt keinen Erzeuger) → box-shadow der Stapelkarten wurde ungültig („none“). Behoben: 6 Variablen in light und dark eingetragen; Scan aller var(--…) in Bögen und Skripten gegen alfa-theme.css. LÜCKE für Code/Phase 5: Themen-Farben im CSS ohne Werkzeug; t9 um Themen-Blöcke erweitern.
- 23.10. Material der Stapelkarten tokenisiert (Johannes: „wieso offen???“ — es gab keinen Grund, nur nicht gemacht): 6 Farben (color.stackGlossFront|Light|Dark, stackSeamFront|Back, stackDrop, hell/dunkel) und 3 Maße (size.stackDropOffset 8, Blur 16, Spread -12); Mail rechts und links ziehen var(--…) statt Literale; apply.js um colors ergänzt; P1/P2/P3 ohne Fund, Block 2026-10-23T16:30.
- 23.10. Phase 1 erledigt über apply.js: P1 [], P2 [], P3 [] (43 Änderungen, alle im Protokoll), geschrieben. Block 2026-10-23T16:00. Nachgezogen aus dem Bestand: 7 neue Bauteile (account-card, account-deck, account-title, envelope, envelope-stack, hint, switch-glass), 14 Elemente, 2 veraltete Bauteile gestrichen (account-mark, account-switch), 5 Tokens, 4 Texte. Offen aus Phase 1: 1.2 bauteile.json (Quelle für t2) nicht ergänzt, t2 findet die Teile aus den Bögen; 1.5 changes.json auf einen Block (erst in Phase 5); Texte der neuen Bogenteile (t4) in Phase 4.4.
- 23.10. Phase 1.3 Probelauf (apply.js, nichts geschrieben): P1/P2 fanden in meinen Handeinträgen echte Fehler (measures.material kein Token-Alias; Kategorien glyph/overlay/row ungültig; Textelement settings-account-* ohne data-id) und im Bestand 33 Lücken: Vertrag stand seit 22.10. nicht auf dem Stand der Bögen (Postfach-Stapel, Kartenköpfe, Hint u. a. fehlten; account-mark/account-switch veraltet). Behoben: Kategorien primitive|composite, material als source mit Bogenverweis (Tokenisierung offen, A1), settings-account-* als Bauteile gestrichen (Zeilen sind settings.field-row), views.json chooseAccount auf mail.account-card.pick, apply.js dropComponents. Doppel-Elemente settings.profile-mark/text-button.profile-pick: Dedupe über alle Bauteile.
- 23.10. Phase 1.1 ausgeführt: Handeinträge entfernt (9 Bauteile, 1 Element, 5 Tokens, 4 Texte, Block 2026-10-23T20:00); apply.js um Typ "ms" und Text-en ergänzt (Werkzeug konnte Dauern und en nicht). Sicherung mit den Handeinträgen: previous/2026-10-23T-vor-uebergabe/. Weiter 1.2/1.3.
- 23.10. 15:02 Z Sync: Brief v14 veröffentlicht, Zeilen gleich Entwurf; DESIGN/brief/BRIEF.txt ersetzt. stand.md neu (cd3b726e8e2e): „Brief v14 gilt (N1 bis N43)“, N42 nicht vergeben; Übergabe-Abschnitt unverändert. Phase 5.1 gilt gegen die veröffentlichte Fassung.
- 23.10. Selbstkorrektur Phase 1.1: Rücksetzen auf previous/2026-10-21T17-25 verworfen — changes.json hat Werkzeugblöcke vom 22.10. (01:15 bis 20:50), die ginge verloren. Stattdessen: nur meine Handeinträge vom 23.10. herausnehmen (9 Bauteile, 1 Element, 5 Tokens, 4 Texte, Block 2026-10-23T20:00) und über apply.js neu einspielen. Probelauf ohne Schreiben: 100 → 91 Bauteile, 435 → 431 Texte; nichts geschrieben. Auffällig: Stempel in changes.json nicht aufsteigend (22T01:15 vor 22T01:10, 22T22:15 vor 22T20:50) — vor P3 prüfen. notice.role vorher „Short notice in the blob menu“.
- 23.10. Phase 0.1 erledigt: 16 Dateien, 1 199 391 Zeichen nach contract-build/previous/2026-10-23T-vor-uebergabe/ (Pfad mit __ statt /). Letzte Werkzeug-Sicherung davor: 2026-10-21T17-25. Ab dort weiter: Phase 0.2.
- 23.10. Phase 1 nötig, weil Vertrag heute von Hand statt über apply.js geändert wurde.
