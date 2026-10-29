# Rückgabe von Johannes an Code · Stand 17.10.2026, 18:47
Export: 18.10.2026

## Akte für Code (17.10.2026, 18:47)
- Bögen: `ALFA Mail` (Logik beider Bereiche, Seite Mail), `ALFA Einstellungen` (Seite, lädt ALFA Mail mit bereich="Einstellungen"), `ALFA Shell` (Hülle, einmal), `ALFA Bestaetigen` (Baustein), `ALFA Huelle` (Register, gemessen 17.10.), `ALFA Tokenbogen`, `ALFA Designsystem` (Sichtbogen von TOKENBOGEN.json, neu 18.10.), `ALFA Dienste`, `ALFA Farbsystem` (Vorschlag), `ALFA Entscheidungen` (alles Offene auf einem Bogen).
- Werte: `TOKENBOGEN.json` (einzige Quelle), `alfa-shell.js` (Rechenregeln der Hülle), `alfa-theme.css` (Farben als CSS).
- Lieferung: `lieferung-an-code/decisions.json`, `settings-sections.json`, `motion-springs.json`.
- Johannes' Worte: `entscheidungen.md`.
- Entfernt am 17.10.: `ALFA Einstellungen Inhalt`, `ALFA Johannes entscheidet`, `ALFA Tooltip`, `PLAN.md`, `HANDOFF-ARBEITSCHAT.md`, `EINSTELLUNGEN-ABGLEICH.md` (Johannes' Worte daraus stehen in `entscheidungen.md`).
- Vorgaben in den Bögen (17.10.): Fläche „flach“ (B19), Schrift Geist, lokal (B18, Dateien seit 17.10. da). Zustandswörter der Dienste überall wie ALFA Mail (Verbunden, Gleicht ab …, Verbindet …, Nicht verbunden, Fehler, Schlüssel gespeichert, Schlüsselbund nicht lesbar, Verwaist). Mail-Konten ist ein Dienst (Integration).
- Gemessen 17.10.: Hülle bei 1512 × 982 = Entwurf; Kontrast hell und dunkel in Mail und Einstellungen ≥ 4,5:1. `color.dark.onSignal` #0d0d0d (Weiß auf Signalrot dunkel hatte 2,61:1).
- **Freigabe Orange** (vorläufig abgenommen, 18.10.): `confirm.*`, `confirmHold` 1000, `confirmRelease` 180, `color.dark.onSignal` #0d0d0d, `size.trailingTextInset` 12 (freies Wort, Wert, Zustand und Eingabe am Zeilenende auf der Linie der Knopfwörter; Textknopf 12 innen, Bestätigen-Pille 4 + 8). Johannes 18.10.: „2 ist erstmal als FREIGABE ORANGE Status abgenommen. kann so in die dokumente gführt werden, bis später andere Optionen ausgearbeitet werden.“ Vorher: Johannes 17.10. zu „2 · Von Design gesetzt“: „Ist soweit OK, fürs erste und bis weitere Farbsysteme und feintuning einziehen so gestattet.“
- Neu 18.10.: `size.hairline` 1 px für alle Trennlinien, Ringe, Rahmen und den Griff in Ruhe.
- Werteabgleich 18.10. (`lieferung-an-code/werte-abgleich.json`): jede px-, ms- und Hex-Angabe in den Bögen gegen `TOKENBOGEN.json`. App-Bögen (Mail, Shell, Bestätigen) und `alfa-theme.css`: jeder Wert hat einen Token gleichen Werts. Dafür 24 neue Tokens mit Status `von-design-gesetzt` (u. a. `size.handleLength` 64, `size.handleLengthActive` 96, `size.recipientListMaxHeight` 308, `size.fieldLabelWidth` 48, `size.settingsTileMinWidth` 132, `motion.duration.spinner` 800; Fundstelle je Token im Feld `where`). Nicht von Johannes entschieden, offen auf `ALFA Entscheidungen` 6. Code übernimmt sie wie alle Werte; Änderungen kommen von Design. Nachtrag 18.10. (Logik): auch Zahlen ohne Einheit sind Tokens – neue Gruppe `count` (z. B. `stackMaxCards` 6), Menübreiten `size.menuWidth*`, Umbruchbreiten `size.breakpoint*`, Blob-Mechanik (`size.blob*`, `motion.deceleration` 0,998 = UIScrollView.DecelerationRate.normal), `motion.duration.toastUndo` 4000 (B26). Stand 329 Tokens, davon 67 „von-design-gesetzt“. Klassen ohne Token (Dummy-Daten, Simulation, Zeichenzahl, Schätzwerte): werte-abgleich.json Teil „logik“ – nicht nachbauen.
- Neu 18.10.: Ebenen `layer.*` (Blob über Menü und Toast, nur Notch darüber); Props der Bögen englisch (bereich→area, oberflaeche→surface, licht→appearance, grund→ground, schrift→typeface, vorne→front, empfaenger→recipients, entwurf→draft, markiere→highlight, daten→dataset, stapel→stack, griff→handle, symbole→symbols, einstellung→settingsGroup, dienste→services, assistentGesicht→assistantFace, fenster→window, breite→windowWidth, hoehe→windowHeight, suchPfad→searchPath, lanesSichtbar→visibleLanes; Bestätigen: frage→question, ja→confirmLabel, verlauf→progress, onJa→onConfirm, onNein→onCancel, laeuft→runningLabel, fertig→doneLabel); Prüfskript `lieferung-an-code/pruefung.js` (Node oder Browser).
- Neu 19.10.: CSS-Vertrag englisch: `[data-appearance="light"|"dark"]`, `[data-ground="lightGray"]` (vorher data-licht/data-grund mit hell/dunkel/hellgrau). Prop-Werte: appearance light/dark, ground white/lightGray, surface lacquer/glass/flat, handle hairline/fine/gray.
- Struktur (19.10.): `ALFA Mail` und `ALFA Einstellungen` haben je eigene Logik; gemeinsame Teile genau einmal in `alfa-bausteine.js` (neben `alfa-shell.js`). Code baut zwei Ansichten. Siehe `TRENNUNG-BERICHT.md`.
- Offen (alles auf `ALFA Entscheidungen`): Kacheln nur in „Verbindungen“ (Integrationen mit Logo oder Initial und Zustand; übrige Gruppen als Liste; Johannes 17.10.: „die "Kacheln" wären bei den "integrationen" eventuell gut, dann mit Icon der jeweiligen Anbindung/App/integration. Bei den anderen Einstellungen aber nicht unbedingt nötig“); Mehrfachauswahl ist in ALFA Mail gebaut, nicht abgenommen; Farbsystem.

Quelle: gespeicherte Antworten im Bogen „ALFA Johannes entscheidet“ (Browser-Speicher, gelesen am 16.10.). Arbeitsstand, kein Paket. Gilt erst nach „so“ von Johannes.

Hinweis: Der Bogen wurde von 34 auf 14 Fragen umgebaut, die Nummern 1 bis 14 haben dabei die Bedeutung gewechselt. Die Antworten 1 bis 14 gelten für die 14-Fragen-Fassung. Die Antworten 15 bis 34 stammen aus der ersten Fassung mit Codes 34 Punkten (Nummern wie in `an-design-liste.md`).

## A · Antworten zur 14-Fragen-Fassung
1. **Liste der Einstellungen (Punkte 1, 2, 3, 34):** Fünf Gruppen aus Inhalt, Dienste dazu, Kacheln als Start, Dummy-Abschnitte nicht bauen. **Stand 17.10., 21:00:** Gebaut in `ALFA Einstellungen.dc.html`: links Ich, Firma, Verbindungen, Schutz und System; Mitte die Abschnitte; rechts die Karte im Stapel. Zuordnung und Nicht-Gebautes in `lieferung-an-code/settings-sections.json`. Kacheln nur in „Verbindungen“, gebaut 17.10.
2. **Mittelspalte und Griff (Punkte 5, 7, 11):** 280, rechte Bahn wächst, Akkordeon aus `alfa-shell.js`, Griff Haarlinie (12 Trefferfläche). Johannes: „Die mitte kann auch wachsen, alles ist je ansicht „locked“ oder nicht. ENTSCHEIDE ICH SPÄTER, bauen.“ Sperre je Ansicht als Schalter vorsehen, Standard später.
3. **Blob-Auge (Punkt 10):** 4 × 8, Abstand 4.
4. **Löschen und Rückgängig (Punkte 26, 30):** Pille für Trennen und Konto löschen. Mails löschen ohne Frage, mit Rückgängig (Toast 4 s). Dazu der Kommentar: „bis zu drei wählbar. auch dann inkl. „kalender, Einladungen etc“ in Mailansicht switchbar.“ Der Kommentar gehört zu „Mehrere Mail-Konten“ (erste Fassung, Punkt 4). Johannes bestätigt am 16.10.: „ja“. Also: bis zu drei Konten wählbar, Kalender und Einladungen in der Mailansicht umschaltbar.
5. **Kleinstes Fenster (Punkt 12):** **Geändert 16.10.:** Johannes: Mindestfenster ist nicht seine Priorität, er nutzt Fullscreen. „Best Practice, hauptsache es funktioniert.“ Die 960 gilt nicht. Code entscheidet nach Apple-Praxis.

**Assistent (neu, 16.10.):** Später ein voller Ansichtsbereich. Menüeintrag als Navigations-Item folgt später. Heute gibt es den Mini-Chat per Doppelklick auf den Blob.
6. **Ein Tokenstand (Punkte 13 bis 17):** Bestätigt.
7. **Bewegung (Punkte 20, 21):** Bestätigt.
8. **Zustände und Texte (Punkte 22, 23, 24):** Bestätigt (16.10.): Wörter englisch, Fehlendes markiert Code „roh“, bis Design liefert.
9. **Mehrfachauswahl (Punkt 27):** In ALFA Mail gebaut (Marke anklicken; Kopf: n gewählt, Alle wählen, Gelesen/ungelesen, Archivieren, Papierkorb, Aufheben, Rückgängig). Nicht abgenommen.
10. **Signatur (Punkt 28):** Bestätigt.
11. **Glas für macOS 26 (Punkt 19):** Später.
12. **Geist-Dateien (Punkt 18):** Johannes liefert die Dateien.
13. **„Verschieben nach …“ (Punkt 29):** Später. „code bestimmt nomenklatur. du übersetzt.“
14. **Dienste, Mitteilungen, Team, Impressum (Punkte 25, 31, 32, 33):** Später. „alle tokens kommen immer von design. und nur aus den hier gezeigten entwürfen nach qualitäts und contract assessment“.

## B · Antworten aus der ersten Fassung (Codes 34 Punkte)
- **15 Ein Tokenstand:** `TOKENBOGEN.json` gilt, `design-system/` wird aufgelöst.
- **16 `--m-coral`, `--m-apricot`, `--m-rose`:** **Behalten**, im Tokenbogen unter `color.mood` (17.10.), am 16.10. im Chat bestätigt („b16 behalten“). Das ersetzt „Entfernen“ vom 13.10. (`entscheidungen.md:136`).
- **17 Mono:** Streichen (Kommentar vom 15.10.).
- **18 Geist-Dateien:** Geliefert von Johannes 17.10. (SIL OFL 1.1): `lieferung-an-code/fonts/` – `Geist-VariableFont_wght.ttf` (wght 100–900), statisch `Geist-Light.ttf` (300), `Geist-Regular.ttf` (400), `Geist-Medium.ttf` (500), `OFL.txt`. Der Entwurf nutzt 300, 400, 500. Vorgabe in allen Bögen jetzt Geist, lokal über `lieferung-an-code/fonts/geist.css` (kein Google-Fonts-Link mehr).
- **19 Fläche:** Flach jetzt, Glas und Lack später.
- **20 Bewegung:** „best swift code practice nutzen.“
- **21 „Weniger Bewegung“ und Falt-Umblendung:** Die Umblendung (160 ms) bleibt.
- **22 Zustandswörter:** Entwurfswörter (`stored`, `unreadable`) gelten.
- **23 Fehlende Mail-Zustände:** Code wählt ein Wort und markiert es „roh“.
- **24 Vertragstexte:** „dann müssen 50 einträge im Vertrag – wenn nich noch mehr, hart geprüft werden und aus unserem Tokenbogen ersetzt oder aber wenn NOVUM im Design Session als Bedarf gemeldet werden.“
- **25 Impressum:** Johannes liefert die Daten.
- **26 Rückgängig:** 4 s, Ziel alter Ordner, bestätigt.
- **27 Mehrfachauswahl:** **Jetzt** (16.10., im Chat bestätigt). Design entwirft sie als Nächstes. Ersetzt „Nicht im ersten Wurf“.
- **28 Signatur:** „IN den EINSTELLUNGEN „mailkonten“ signaturen anlegen, in Mails client nur „wählen““.
- **29 „Verschieben nach …“:** Liste mit Ordnern und Labels.
- **30 Bestätigen-Pille:** „Ich nenne die Liste“. Eigene Wahl: „NEUE Animation entwickeln...“ → 17.10. gebaut in `ALFA Bestaetigen.dc.html`: Halten 1 s, der Knopf radiert sich von links weg und zittert zum Ende („in 1sek … zittern“, „wegradiert“). Ja-Knopf sitzt dort, wo der Klick war, und behält seine Größe. Tooltip = System-`title` „Halten zum …“ („Komplett wie bei MacOS machen“). Klick-Modus („dumbest user“) gestrichen. Tokens: `motion.duration.confirmHold` 1000, `confirmRelease` 180, `confirm.*`.
- **31 Daten je Dienst:** Code startet mit den 10 Diensten.
- **32 Mitteilungsoptionen:** „CODE liest aus Integrations Documentationen und Anbindungen was überhaupt mitgeteilt werden kann pro dienst.“
- **33 Team „Für dich / Für alle“:** Nein, nur Anzeige Persönlich und Firma.
- **34 Dummy-Abschnitte:** Als „nicht bauen“ markieren.

## Von Johannes zu klären (vor „so“)
Nichts mehr offen. Johannes gibt „so“, dann geht die Rückgabe an Code. (B27 und A9 stimmen überein: Mehrfachauswahl jetzt, Design entwirft sie.)

## Hinweise an Code
- Tokens kommen nur von Design. Einzige Quelle: `TOKENBOGEN.json` (Stand 17.10.). `alfa-shell.js` und `alfa-theme.css` stimmen mit ihm überein (geprüft 17.10.: 13 Shell-Konstanten, alle Farben hell und dunkel).
- 12 Trefferfläche: von Johannes abgehakt (A2). 4 Sekunden Rückgängig: von Johannes bestätigt (A4, B26).

## Antwort auf Lieferung 15, Teil A (17.10.2026)
Neu im Tokenbogen (Quelle je Token im Feld source): headPadRight 8, headPadLeftList 16, headPadLeftStack 8, headGapList 8, headGapStack 4, menuEdge 8, menuRowHeight 28, menuRowPadding 12, menuRowGap 8, menuSeparatorInset 12, menuSeparatorSpace 4, assistantFieldHeight 40, blobStretchMax 0,16, blobWakeDistance 212.
- A2: Assistent-Breite = blobPopupFallbackWidth 280 (TOKENBOGEN.json), die 360 ist überholt.
- A3: Wurf 0,12 steht im Entwurf nicht. Es gibt Dehnung 0,16 und Weckdistanz 212 (ALFA Shell.dc.html:152, :157). entfällt.
- A4: Schatten kommen fertig (shadow.light/dark), Faktor 0,5 entfällt.
- A5: Kopf rechts 8, nicht 10.
- A6: Menü 12 und 8 laut Tokens oben, 10 und 18 entfallen.
- A1: laneMinimumLeft = 280. Beleg: Johannes 15.10. „Bitte vereinheitlichen auf 280“ (links = rechts in Ruhe und Minimum); Rückgabe 16.10. Punkt 2 „280 · abgehakt“. Nicht 224, nicht 112 (Johannes 17.10.).
- blobAwakeWidth (17.10.): 124. Passt der Bereichsname nicht, Schritt auf 280 (laneRestWidth), keine Zwischenbreiten. Johannes: „Wach - immer mindestens 124 breit, wenn Text nicht passt maximal und als Step 280 breit“.

## Maße: Code übernimmt den Entwurf (Johannes 17.10.)
„CODE HAT NICHTS ZU SAGEN WAS MAßE ANGEHT!!!!! ER MUSS UNSERE ÜBERNEHMEN!!!!“ · vorher: „Der Entwurf ist die Wahrheit, der Code zieht nach.“ (entscheidungen.md:125) · „DU gibst die MAßE vor, du und ich sind die REFERENZ!“ (:82)
Keine Abweichung ist verhandelbar. Code ersetzt seinen Wert durch den Entwurfswert:

| Punkt | Entwurf (gilt) | Code heute (entfällt) | Token im Code |
|---|---|---|---|
| Leiste über den Bahnen | Blob 40, dann 12, Bahnen ab 52 unter dem Rand | Leiste 60, dann 12 | component-blob-bar-height, layout-region-gap |
| Falten unter | 112 | 120 | component-lane-collapse-threshold |
| Kleinste Seitenbahn | links 280, rechts 280 („Bitte vereinheitlichen auf 280“, 15.10.) | 240 | lane-min (shell.json) |
| Größte Seitenbahn | nicht begrenzt | 380 | component-lane-leading-max-width |
| Akkordeon | alfa-shell.js, abgehakt (Rückgabe 16.10. Punkt 2); Minima links = rechts = Mitte 280 | rechte Bahn schmaler bis 240, dann linke, dann rechts falten, dann links; die Mitte gibt nie nach | LaneLayout.widths |
| Strich | Haarlinie 1 × 64, aktiv 2 × 96, Radius 2, #6b6b6b | 4 × 64, aktiv 96, Radius 2, #a3a3a3 | component-lane-handle-thickness, -length, color-control-handle |
| Symbolknopf | 28, rund | 26 (shell.json), eckig mit Radius 12 | lane-header-button, component-lane-header-button-radius |
| Innenrand rechts im Kopf | 8 | 10 | lane-header-padding-end |
| Blob in Ruhe | 56 × 40, Radius 20 | 56 × 36 | component-blob-height |
| Gesicht, Augen | 4 × 8, Abstand 4 (Rückgabe Johannes 16.10.: abgehakt) | 3 × 7, Abstand 5 (nicht neu gemessen) | face-eye-width, -height, -gap (shell.json) |
| Zeile, Karte im Stapel | Zeile 12; Karte wie der Kopf: 20 oben, 0 unten, bündig (Johannes 15.10.: „ALLE wie der Kopf“) | Zeile 10, Karte 14 | radius-row, radius-card |
| Stapel | 520 ms | 320 ms | motion-duration-stack |
