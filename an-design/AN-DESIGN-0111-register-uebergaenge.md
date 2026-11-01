# Audit Design-Werte und Übergangsformen · ALFA_OS `main` 9872e652 · 01.11.2026

Nur gelesen, nichts im Repo geändert. Grundlage: `App/**/*.swift` (119 Dateien, ohne den Fremdordner `ALFA_OS/`), `App/Design/SheetValues.swift`, `Resources/tokens.json`, `Sources/Design/Model/*`, `utils/token_register.py`, `utils/check.py`, der gültige Master `DESIGN/ALFA Design Master 2026-10-31.zip` (MASTER-2910, `contract/` und `project/`), DESIGNCHANNEL (`origin/DESIGNCHANNEL`, frisch geholt, Kopf `fc40ea5e` vom 01.11. 01:18).

Kennzeichnung: **belegt** = im Code bzw. im Bericht gesehen (Datei:Zeile). **Vermutung** = aus Suche abgeleitet, nicht Zeile für Zeile bestätigt.

---

## A · Hardcodes in Views

### A1 · Streng nach Regel (Zahlen außer 0, 1, 2 und Farbwerte in `App/`)
| Befund | Stand |
|---|---|
| Zahlen außer 0, 1, 2 in `App/**/*.swift` (ohne `SheetValues.swift`) | **keine** · belegt: eigener Scan über alle 119 Dateien ohne Treffer; `utils/check.py:286-301` meldet jede solche Zahl und jedes `0x…` |
| `Color(red:…)`, Hex-Strings, `.system(size:)` mit Zahl | keine Zahl; Farben entstehen nur in `App/Design/Appearance.swift:23` aus Tokens · belegt |
| Feste Farben | nur `Color.clear` bzw. `.clear` (36 Stellen, z. B. `App/Mail/InboxRow.swift:22`, `App/Components/LaneRow.swift:32`) und `NSColor .clear` in `App/Components/MenuPanel.swift:68`. Durchsichtig, kein Gestaltungswert · belegt |
| Animationen ohne Token (`.default`, `.spring`, `.easeInOut`) | keine; alle Dauern kommen aus `Tokens.Duration` · belegt |

### A2 · Grenzfälle in `App/` (keine Zahl, aber ein Gestaltungswert ohne eigenen Token)
| Datei:Zeile | Was | Wert | Vorschlag | Stand |
|---|---|---|---|---|
| `App/Mail/SourceWindow.swift:34` | „Original anzeigen“: Systemschrift Monospace | `.system(size: TextSize.small, design: .monospaced)` | Token `typography.family.mono` oder Entscheid; der Bogen sagt „Mono entfernt“ (`tokens.json` `$description`) | belegt |
| `App/Mail/SourceWindow.swift:15` | Fenstergröße „Original“ leiht die Vorschau-Maße | `Size.previewMinWidth/Height` | eigener Token oder bestätigen | belegt |
| `App/Mail/Deck.swift:9` | Platz für den Umschalter | `step28 + step20` = 48 | `size.deckToggleRoom` | belegt |
| `App/Mail/Deck.swift:7` | Einzug im Kontostapel | `Radius.card − symbolSize/2` | `size.deckInset` | belegt |
| `App/Shell/AssistantPanel.swift:18` | feste Höhe des Assistenten ohne Verlauf | `step40 + step28 + step44` = 112 | `size.assistantFixedHeight` | belegt |
| `App/Shell/Frame.swift:121` | Abstand über dem Kartenfuß | `footerHeight + step8` | `size.footerClearance` | belegt |
| `App/Settings/SettingsRow.swift:15` | Breite der Zeilen-Pille | `2 × step16 − confirmPillOffset` | `size.rowPillInset` | belegt |
| `App/Settings/SettingsPane.swift:163` | Zeilen im Streifen | `(Höhe − stripReserveTop − stripReserveBottom) / rowHeight` | ok, nur Rechnung | belegt |
| `App/Mail/AppSession+Mail.swift:49` | Wartezeit nach Postfachwechsel | `switchIn + glassDelay` | ok, nur Rechnung | belegt |
| `App/Shell/Blob.swift:49,52`, `App/Shell/Frame.swift:277` | Fokusring | `radius + focusRingOffset + focusRingWidth` | ok, nur Rechnung | belegt |
| `App/Design/View+Shadow.swift:16`, `App/Mail/MailboxGhost.swift:26`, `App/Components/View+Lacquer.swift:25` | CSS-Unschärfe halbiert für SwiftUI | `blur / 2` | ok, Umrechnung CSS → SwiftUI | Vermutung (Umrechnung plausibel, nicht gemessen) |
| `App/Mail/FormatRow.swift:30-41` | Link eingeben als System-Dialog (`NSAlert`), Feld 240 | `SheetValues.linkFieldWidth` | Bogen für den Link-Dialog | belegt (Form), Vermutung (kein Bogen) |
| `App/Design/Typeface.swift:22,30` | Ersatzschrift System; Entwurfstext in Systemschrift | `NSFont.systemFont` | ok laut Commit `309168dc` („as the master sets it“) | belegt |

### A3 · Feste Werte außerhalb `App/`, die die Oberfläche formen
Die Regel gilt für Views; diese Werte wirken trotzdem sichtbar und haben keinen Token.
| Datei:Zeile | Name | Wert | Wirkung | Vorschlag | Stand |
|---|---|---|---|---|---|
| `Sources/Shell/Model/AreaRules.swift:144` | `ShellValues.dockHoverGrow` | 4 | Blob wächst beim Hover im Dock | `size.blobDockHoverGrow` | belegt |
| `…AreaRules.swift:145` | `stripDoubleClickWindow` | 0,6 s | Doppelklick im Streifen | `duration.stripDoubleClick` | belegt |
| `…AreaRules.swift:146-150` | `commandIconCost` 28, `commandSendCost` 92, `commandConfirmCost` 290, `commandSeparatorCost` 9, `commandSlack` 12 | Breitenmodell der Befehlsleiste (wann Knöpfe ins „Mehr“ fallen) | `size.command*`; die 9 steht im Bogen (`ALFA Einstellungen.dc.html:483` `cost: 9`) | belegt (Werte), Vermutung (28/92/290 aus dem Bogen) |
| `…AreaRules.swift:142-143` | `pointerStep` 0,001, `stretchPerSpeed` 0,00012 | Dehnung des Blobs beim Ziehen | `motion.blobStretchPerSpeed` | belegt |
| `Sources/Mail/Logic/AddressListParser.swift:177-187` | `NameLimit` person 40, chip 30, summary 30, sender 40, middleHead 0,55, personAddress 44, firstName 24, suggestionAddress 40, recipientsInline 2 | Kürzung von Namen und Adressen in Zeilen, Chips, Kopf | `count.nameLimit*` | belegt |
| `Sources/Shell/State/LockState.swift:21,25,26` | 60 s, 300 s, 900 s | kürzeste Sperrzeit, Auswahl 5 und 15 min | Auswahlwerte, eher Produkt als Design | Vermutung |
| `Sources/Core/Logic/SignInPageEngine.swift:67,87,96-113,147,160-165` | Skala 2, Lider .45, Start .92, Blinzeln .1, Verzögerungen 200/900/980/1060/1700/1900/2100 ms, Label 200 px, Tab schließen 600 ms, Zweiklang 392/587,33 Hz, Lautstärke .05 | Übergangsseite nach Anmeldung | durch Bogen `ALFA Intro.dc.html` ersetzen | belegt; gemeldet (siehe D) |
| `Sources/Mail/Logic/HTMLEngine.swift:192,194` | 50 % Kachelbreite, 135° Streifen | Platzhalter für blockierte Bilder | `ratio.imageTileColumns`, Winkel als Token | belegt |
| `Sources/Shell/Logic/LaneLayoutEngine.swift:68,73` | ±0,5 | Rundungstoleranz | ok, technisch | belegt |

---

## B · SheetValues: Token oder Code-Zahl?
79 Werte in `App/Design/SheetValues.swift`. Nur 3 hängen an Tokens. Die übrigen 76 sind Code-Zahlen; 22 davon stehen als Zahl in einem Master-Bogen, haben dort aber keinen Token.

### B1 · Aus Token abgeleitet (3) · belegt
`envelopeTimes`, `envelopeOpenDelays`, `envelopeShutDelays` (`Tokens.Duration.envelope*`; die Nullen darin sind Literale).

### B2 · Mathematik und Technik (6) · belegt · kein Token nötig
`weightAxis` 0x77676874 (Schriftachse „wght“), `fullTurn` 360, `halfTurn` 180, `quarterTurn` 90, `keyframeMiddle` 0,5, `syncArcStart` −90 (Start oben).

### B3 · Zahl steht im Master-Bogen, aber ohne Token (22) · Kandidaten zum Eintragen in den Vertrag
| Name | Wert | Fundstelle im Master | Vorschlag | Stand |
|---|---|---|---|---|
| `blinkScale` | 0,1 | `ALFA Shell.dc.html` `scaleY(.1)` | `scale.blobBlink` | belegt |
| `winkScale`, `winkCloseAt`, `winkOpenAt` | 0,08 / 0,44 / 0,68 | `ALFA Shell.dc.html` `scaleY(.08)`, `offset: .44/.68` | `scale.blobWink`, `ratio.winkClose/Open` | belegt |
| `cssEase` | (0,25 0,1 0,25 1) | `ALFA Mail.dc.html` `… ease …` (CSS-Schlüsselwort) | `motion.easing.ease` | belegt |
| `compactValueSize` | 12 | Commit `d4dd96cd` „the 12 px of the master“ | `typography.size.compact` (oder `small`?) | belegt (Commit) |
| `lidRestScale` | 0,45 | `ALFA Shell.dc.html` (1 Treffer „.45“) | `scale.blobLidRest` | Vermutung |
| `pulseScale` | 2 | `ALFA Shell.dc.html` `scale(2)` | `scale.blobPulse` | Vermutung |
| `orbSpot`, `orbGlossX`, `orbGlossY` | 0,58 / 0,35 / 0,28 | `ALFA Shell.dc.html` 58 %, 35 %, 28 % | `ratio.orb*` | Vermutung |
| `iconSize`, `iconBox` | 14 / 16 | SVG `width="14"`, `viewBox="0 0 16 16"` in Mail, Einstellungen, Shell | `size.glyph`, `size.glyphBox` | Vermutung |
| `iconStroke`, `smallIconStroke`, `tinyIconStroke` | 1,3 / 1,5 / 1,8 | SVG `stroke-width` in Mail, Einstellungen, Shell | `size.glyphStroke*` | Vermutung |
| `smallIcon`, `tinyIcon` | 12 / 10 | SVG `width="12"`, `width="10"` | `size.glyphSmall/Tiny` | Vermutung |
| `mutedOpacity`, `iconOpacity`, `closeOpacity`, `placeholderOpacity` | 0,6 / 0,8 / 0,7 / 0,45 | `opacity` in Shell, Mail, Einstellungen, `alfa-theme.css` | `opacity.muted/icon/close/placeholder` | Vermutung |

### B4 · Reine Code-Zahl, im Master nicht gefunden (48) · Kandidaten für Design
| Gruppe | Namen = Wert (Lesestelle) | Art |
|---|---|---|
| Blob, Hülle | `releaseSamples` = 6, `releaseSpan` = 0,016 (`View+BlobPress.swift`), `labelMaxWidth` = 200 (`Blob.swift:110`), `laneShiftStep` = 8 (`Frame.swift:321`), `tapeFadeAt` = 0,4 (`View+SearchFade.swift:13`), `hintTick` = 0,1 (`View+DwellHint.swift`) | Maß, Zeit, Verhalten |
| Abgleich-Ring, Spinner | `syncSweep` = 720, `syncErrorArc` = 0,25 (`Frame.swift:409,438`), `spinnerArc` = 0,22, `confirmSpinnerArc` = 0,25, `statusArcBox` = 12, `statusArc` = 0,3 | Form |
| Assistent-Orb | `orbOrbit` = 0,24, `orbGlossStop` = 0,45, `orbCount` = 3 (`AssistantPanel.swift:392-421`) | Form |
| Übersicht | `overviewStaggerCap` = 8, `overviewTileStagger` = 0,024 s, `overviewTileTextLine` = 1,5, `overviewTitleLines` = 2 (`OverviewTile.swift`) | Zeit, Zeilen |
| Mail-Liste | `rowTextLine` = 20, `previewLines` = 2, `attachmentChipNameLimit` = 26, `attachmentNameLimit` = 34, `cardTitleLimit` = 34, `cardAddressLimit` = 36, `conversationLine` = 16, `tilesBreakpoint` = 320 | Maß, Kürzung |
| Mail-Liste, Verhalten | `listWindow` = 60, `listWindowStep` = 120, `listLoadAhead` = 1200 | Verhalten (kein Design-Token nötig?) |
| Felder | `fieldTrailingMaxShare` = 0,5 (`InputField.swift:60`), `linkFieldWidth` = 240, `dashedLine` = [2, 2] (`DraftEditor.swift:57`, `RecipientEditor.swift:153`) | Maß, Form |
| Kontostapel, Lack | `deckLift` = 0,32 (`AccountCard.swift:46`), `stackGlossLightFrom` = 0,7529 (`View+Lacquer.swift:36`), `ghostStart` = 0,02, `ghostLife` = 1,2 (`AccountDeck.swift:76,80`) | Form, Zeit |
| Briefumschlag | `envelopeBox` 20, `envelopeWidth` 14, `envelopeHeight` 10, `envelopeRadius` 2, `envelopeOpenX` [3,3,3], `envelopeOpenY` [4,6.2,8.4], `envelopeShutX` [2,3.6,5.2], `envelopeShutY` [7,5.2,3.4], `envelopeFlapInset` 1, `envelopeFlapTop` 1,4, `envelopeFlapDepth` 4,2 (`EnvelopeStack.swift`) | Zeichnung des Glyphs |

Hinweis: Die Einteilung B3/B4 beruht auf Textsuche im entpackten Master; eine Zahl in B4 kann im Bogen anders geschrieben stehen (Vermutung).

---

## C · Token-Register
**Zahlen** (belegt, `python3 -I utils/token_register.py`): 483 Werte, 428 gelesen, 55 ungelesen. Davon 353 `Tokens.*`, 51 `Colors.*`, 79 `SheetValues.*`.

**Herkunft** (belegt, Vergleich `Resources/tokens.json` ↔ `contract/{base,theme-light,theme-dark,ground-lightGray}.tokens.json`):
- Jeder der 480 Werte in `tokens.json` steht im Vertrag des Masters 2910; kein Token ist im Code erfunden. Werte gleich; 5 Unterschiede nur in der Schreibweise (Stimmungsfarben als Hex statt Komponenten; `shadow.lane` verweist auf `color.light.line` statt `color.line`). Die Stapelstufen `stack.depth0-4` stehen im Code als Liste, Werte gleich.
- **Aus Code, nicht im Vertrag:** die Gruppe `constants` in `tokens.json` (Tintenrollen `lane`/`inverse` → `InkSet`, `motion.defaultEasing = standard`) und die 79 `SheetValues`. Dazu die Werte aus A3 (`ShellValues`, `NameLimit`).
- Status der 404 Tokens und Farben: 329 set-by-design, 20 approved, 7 approved-provisional, 48 ohne Status (34 Size, 9 Duration, 2 Radius, je 1 Spacing, Family, Layer).
- `utils/generate_tokens.py --check`: die erzeugten Dateien sind aktuell (Exit 0).
- **Vom Register-Skript nicht erfasst:** `Moods` (3, gelesen in `AssistantPanel.swift:391`), `Shadows` (`floating` 4×, `lane` 1×, `overviewHoverLight` 2×; `knob`, `segment` ohne Treffer · Vermutung ungelesen), `Surface` (11 Werte, kein Leser · belegt per Suche), `stackLight/Dark`, `InkSet`. Das Skript kennt nur `Tokens`, `Colors`, `SheetValues`.

**Ungelesene Tokens (55)** · belegt
| Gruppe | Namen |
|---|---|
| Component (33 Aliase, der Code liest die Ziel-Tokens direkt) | `laneRadius`, `laneEdge`, `laneGap`, `laneHeaderHeight`, `laneFoldedWidth`, `laneFoldThreshold`, `laneMiddleMinimumWidth`, `rowHeight`, `rowRadius`, `symbolSize`, `blobHeight`, `blobWidth`, `blobAwakeWidth`, `blobDockDistance`, `blobRadius`, `menuRadius`, `cardRadius`, `cardInset`, `noticeRadius`, `fieldRadius`, `capsuleRadius`, `laneRestWidth`, `laneMinimumRightWidth`, `blobPopupFallbackWidth`, `cardFooterHeight`, `cardRadiusBottom`, `blobEyeWidth`, `blobEyeHeight`, `blobEyeGap`, `suggestionRowHeight`, `chipHeight`, `overviewTileHeightMedium`, `overviewTileMinWidthMedium` |
| Size (11) | `assistantFieldHeight`, `composeColumnMinWidth`, `breakpointStack`, `stackFanStep`, `safeAreaTop`, `tileLogoSize`, `reelTopOffset`, `accountFanWidth`, `accountClosedWidth`, `lockFieldWidth`, `profileFactMinWidth` |
| Duration (2) | `overviewStagger`, `tileActions` |
| Opacity, Confirm (2) | `hoverDim`, `originDefault` |
| Layer (5) | `menu`, `safeArea`, `inLaneToast`, `switchGlass`, `hint` |
| Colors (2) | `mark`, `handle` |

Auffällig: `Duration.overviewStagger` ist ungelesen, während der Code `SheetValues.overviewTileStagger` = 0,024 nutzt (Vermutung: derselbe Zweck, Wert vergleichen). `Opacity.hoverDim` ungelesen, Code nutzt eigene Opazitäten (B3).

Das volle Register (Name, Wert, Quelle, Status, Lesestellen) steht im Anhang.

---

## D · Übergangsformen ohne Bogen

### D1 · Schon an Design gemeldet
| Form | Code | Gemeldet in | Stand |
|---|---|---|---|
| „Nutzerkonto stilllegen“ unter Ich | `App/Settings/SettingsDetail.swift:452-460` | `AN-DESIGN-3110-stand-3.md` Teil F | belegt |
| Übergangsseite nach Anmeldung (Blob, Sequenz, Zweiklang, Klick holt App) | `App/Shell/SignInStyle.swift`, `Sources/Core/Logic/SignInPageEngine.swift` | `AN-DESIGN-3110-intro.md` (Nachträge 1, 2), `AN-DESIGN-3110-stand-3.md` E; die erfundenen Werte stimmen mit dem heutigen Code überein | belegt |
| Startfehler-Bildschirm „Fehler · Domäne Code“ + „Schließen“ | `App/Shell/AlfaApp.swift:51-62` | `AN-DESIGN-0111-ist-1021.md` Nachtrag | belegt |
| Fortschritt „Mail n von m“ | Einstellungen › Mail-Konten | `stand-3` C5 | belegt |
| „Freigaben für den Assistenten“ | `SettingsDetail.swift:230` | `0111` Frage 10 | belegt |
| „Prüfen“ an der Postfachzeile, „Lokale Ablage“ bei Google | Einstellungen | `0111` Fragen 9, 11 | belegt |
| Kürzung in der Mitte mit Hilfetext | `a3906be0`, `64460f25` | `0111` Teil 2 | belegt |
| Später senden, Mailingliste, Widerruf, Serversuche | Mail, Einstellungen | `stand-2`, `stand-3` C | belegt |
| Karten im Assistenten (Schätzung, Entwurf …) | `AssistantPanel.swift:289-293` | `AN-DESIGN-3110-assistent-mail.md` A4 als Auftrag | belegt |

### D2 · Nur als Frage gemeldet, die gebaute Antwort fehlt auf DESIGNCHANNEL
Alle drei sind nach dem Bericht `0111` (00:02) gebaut worden; danach kam nur noch der Startfehler-Nachtrag.
| Form | Code | Gefragt in | Was fehlt | Stand |
|---|---|---|---|---|
| Knopf „Verbinden“ in nicht verbundenen Dienstkarten (Zeile mit leerem Titel) und im Schlüssel-Inventar | `App/Settings/IntegrationCard.swift:39-43`, `SettingsDetail.swift:166-170` (`54897518`) | `0111` Frage 1 | Meldung „gebaut als Zeile mit Akzent-Knopf, ohne Bogen“; der Master zeichnet „Verbinden“ nur im Kartenkopf (`ALFA Einstellungen.dc.html:488`) | belegt |
| Assistent-Hinweis mit „Einstellungen öffnen“ bei Claude-Fehler bzw. ohne Schlüssel (Form der Aus-Karte, öffnet die Claude-Karte) | `App/Shell/AssistantPanel.swift:31,63-74` (`dcfc2d3d`) | `0111` Frage 4, `stand-2` Frage 6 | Meldung der gebauten Form | belegt |
| Rechte Einstellungs-Karte folgt dem letzten Klick; Kategorieklick zeigt deren erste Karte und entfaltet die gefaltete rechte Bahn (Abweichung vom Bogen, Johannes 01.11.) | `App/Settings/SettingsPane.swift` (`5d2155a5`, `ddff70cc`) | `0111` Frage 2 | Meldung der Entscheidung und Abweichung | belegt |

### D3 · Nicht gemeldet
| Form | Code | Warum Übergang | Stand |
|---|---|---|---|
| „Entfernen“ im Schlüssel-Inventar als Halte-Pille, Frage „X trennen?“, Hinweis „Halten zum Entfernen“ | `SettingsDetail.swift:171-192` (`54897518`); derselbe Hinweis bei „Konto entfernen“ `AccountFlow.swift:518` | Text `settings.hold.remove` fehlt im Master; Wortlaut der Frage offen (CLAUDE.md Aufgabe 4) | belegt (Code, Suche in allen `an-design/*.md` ohne Treffer) |
| Fehler beim Neustart nach Abmelden als Hinweis | `SettingsDetail.swift` (`54897518`, `AppRelaunch.run`) | kein Bogen für den Fehlerfall | Vermutung |
| Abmelde-/Stilllegen-Fehler nennt Konten und Fehlercode | `AccountFlow.swift` (`9bd86912`, `12dd2310`) | Notice-Inhalt ohne Bogen | Vermutung |
| Toasts bei fehlgeschlagenem Sichern in Einstellungen („Export fehlgeschlagen.“, „Ablage konnte nicht verschoben werden.“) | `SettingsDetail.swift:253`, `MailStoreBlock.swift:85` (`ddff70cc`) | Texte nicht im Master | belegt (Texte), Vermutung (Bogen fehlt) |
| Karte Kontakte: Quellen-Schalter, „Eigene Kontakte“, Bearbeiten-Zeilen, „Neuer Kontakt“, „Vorgeschlagen · aus Absendern“ | `SettingsDetail.swift:350-395` | Master nennt nur die Kategorie „Kontakte“ ohne Inhalt (`ALFA Einstellungen.dc.html:234`); `ANTWORT-CODE-3110.md` N33 beschreibt nur Daten | Vermutung |
| Fenster „Original anzeigen“ (Monospace-Systemschrift, Vorschau-Maße) | `App/Mail/SourceWindow.swift` | Master hat nur den Menüeintrag | Vermutung |
| Link-Eingabe der Formatleiste als System-Dialog | `App/Mail/FormatRow.swift:30-41` | kein Link-Dialog im Mail-Bogen gefunden | Vermutung |
| „Signatur zeigen / ausblenden“ im Verlauf | `App/Mail/ThreadItemRow.swift:49` | Texte nicht im Master | Vermutung |
| Projektordner-Menü: „Lädt“, „Leer“, „Fehlgeschlagen“, „N weitere“ als nicht wählbare Köpfe; „mehr laden“ wartet auf Bogen | `App/Mail/ProjectFolderList.swift` (`a8682635`) | `ANTWORT` F2 fragt nach dem Weg über 8 Einträge; die neue Kopf-Form ist nicht gemeldet | belegt (Commit), Vermutung (Meldung fehlt) |
| Empfängerfeld: unbrauchbarer Text wird `signal` | `App/Mail/RecipientEditor.swift` (`9b3e02c8`) | Zustand im Bogen nicht gefunden | Vermutung |
| Texte ohne Master-Wortlaut in Karten: „Verbindung steht. Letzter Abgleich …“, „Zwischenspeicher · geleert“, „Tokens in diesem Monat“, „Keine Ordner gefunden“, „Die Anmeldung ist nicht eingerichtet.“ | `IntegrationCard.swift:261,277,380,422`, `AccountFlow.swift:152` | Wortlaut nicht im Master | belegt (Texte), Vermutung (Form) |
| Menüleiste „Alle Postfächer abfragen“ | `App/Shell/MailCommands.swift:40` | System-Menü, Text nicht im Master | belegt |

Kein Übergang: leere Signatur („Für dieses Postfach gibt es keine Signatur.“ + „Signatur anlegen“) steht im Master (`ALFA Einstellungen.dc.html`, `contract/texts.json`) · belegt.

Methode D3: Textschlüssel, die `App/` direkt nennt (436), gegen den Wortlaut im ganzen Master geprüft; 41 ohne Treffer, hier nach Form zusammengefasst. Schlüssel, die über Variablen laufen, erfasst das nicht.

---

## E · Fragen an Design
1. **SheetValues B3 (22 Werte):** in den Vertrag übernehmen? Vorgeschlagene Namen stehen in B3.
2. **SheetValues B4 (48 Werte):** welche gehören in den Vertrag (Maße, Zeiten, Formen), welche bleiben Code-Verhalten (`listWindow`, `listLoadAhead`, `releaseSamples`)?
3. **Befehlsleiste:** Breitenmodell `ShellValues` 28 / 92 / 290 / 9 / 12 als Tokens liefern?
4. **Namenskürzung `NameLimit`** (40 / 30 / 44 / 24 Zeichen, Kopf 0,55): Werte bestätigen oder liefern.
5. **Überlappungen:** `Duration.overviewStagger` gegen `overviewTileStagger` 0,024; `Opacity.hoverDim` gegen die Code-Opazitäten; `Size.tileLogoSize` (ungelesen, schon in `stand-2` Frage 5).
6. **Ungelesene Tokens:** `Surface` (11), `Shadows.knob`/`segment`, `Colors.mark`/`handle`, 11 `Size`- und 5 `Layer`-Werte: noch gebraucht oder streichen?
7. **Monospace** im Fenster „Original anzeigen“: erlaubt (eigener Token) oder Geist?
8. **Bögen für D2/D3:** Knopf „Verbinden“ in der Karte, Halte-„Entfernen“ im Inventar mit Wortlaut der Frage, Karte Kontakte, Link-Dialog, Fenster „Original“, Signatur zeigen/ausblenden, Fehlerhinweise nach Abmelden/Neustart, Kopf-Zeilen im Projektordner-Menü.
9. **Widerspruch Pille im Dunkelmodus** (#f5f5f5 im Vertrag, #2e2e2e in `alfa-theme.css`): noch offen aus `stand-3` E.

---

## Prüfgrenzen
- Ob eine Zahl aus B4 im Bogen anders geschrieben steht, ist nicht ausgeschlossen (Textsuche).
- D3 stützt sich auf Commits seit 30.10., die Textschlüssel und die Berichte auf DESIGNCHANNEL; Ansichten wurden nicht im laufenden Programm angesehen.

## Anhang · Zentrales Register aller Werte (483 Einträge)

Erzeugt aus `python3 -I utils/token_register.py` (Lesestellen) plus `Sources/Design/Model/Tokens.swift` (Wert), `Resources/tokens.json` (Status) und dem Vergleich mit `contract/*.tokens.json` des Masters 2910. Spalten: Lesestellen gesamt / davon in `App/` / davon in `Sources/` / davon als Alias in `Tokens.swift`. Status: sbd = set-by-design, appr = approved, prov = approved-provisional, leer = ohne Status. Quelle „SheetValues (Code)“ heißt: im Code gesetzt, kein Token.

| Name | Wert | Quelle | Status | ges. | App | Src | Alias |
|---|---|---|---|---|---|---|---|
| `Tokens.Size.edge` | 16.0 | base.tokens.json | sbd | 16 | 11 | 4 | 1 |
| `Tokens.Size.gutter` | 12.0 | base.tokens.json | sbd | 5 | 1 | 3 | 1 |
| `Tokens.Size.blobHeight` | 40.0 | base.tokens.json | sbd | 4 | 1 | 2 | 1 |
| `Tokens.Size.blobWidth` | 56.0 | base.tokens.json | sbd | 3 | 1 | 1 | 1 |
| `Tokens.Size.blobAwakeWidth` | 124.0 | base.tokens.json |  | 3 | 1 | 1 | 1 |
| `Tokens.Size.blobDockDistance` | 36.0 | base.tokens.json | sbd | 2 | 0 | 1 | 1 |
| `Tokens.Size.foldedWidth` | 56.0 | base.tokens.json | sbd | 2 | 0 | 1 | 1 |
| `Tokens.Size.foldThreshold` | 112.0 | base.tokens.json | sbd | 2 | 0 | 1 | 1 |
| `Tokens.Size.middleMinimumWidth` | 280.0 | base.tokens.json |  | 2 | 0 | 1 | 1 |
| `Tokens.Size.headerHeight` | 44.0 | base.tokens.json | sbd | 6 | 4 | 1 | 1 |
| `Tokens.Size.rowHeight` | 36.0 | base.tokens.json | sbd | 5 | 3 | 1 | 1 |
| `Tokens.Size.symbolSize` | 28.0 | base.tokens.json | sbd | 21 | 19 | 1 | 1 |
| `Tokens.Size.cardInset` | 0.0 | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Size.laneRestWidth` | 280.0 | base.tokens.json |  | 2 | 0 | 1 | 1 |
| `Tokens.Size.laneMinimumRight` | 280.0 | base.tokens.json |  | 2 | 0 | 1 | 1 |
| `Tokens.Size.blobPopupFallbackWidth` | 280.0 | base.tokens.json |  | 3 | 0 | 2 | 1 |
| `Tokens.Size.footerHeight` | 44.0 | base.tokens.json |  | 3 | 2 | 0 | 1 |
| `Tokens.Size.blobEyeWidth` | 4.0 | base.tokens.json |  | 3 | 2 | 0 | 1 |
| `Tokens.Size.blobEyeHeight` | 8.0 | base.tokens.json |  | 3 | 2 | 0 | 1 |
| `Tokens.Size.blobEyeGap` | 4.0 | base.tokens.json |  | 3 | 2 | 0 | 1 |
| `Tokens.Size.suggestionRowHeight` | 44.0 | base.tokens.json |  | 2 | 1 | 0 | 1 |
| `Tokens.Size.chipHeight` | 24.0 | base.tokens.json |  | 8 | 7 | 0 | 1 |
| `Tokens.Size.overviewTileHeightSmall` | 144.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.overviewTileHeightMedium` | 176.0 | base.tokens.json |  | 2 | 0 | 1 | 1 |
| `Tokens.Size.overviewTileHeightLarge` | 248.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.overviewTileMinWidthSmall` | 200.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.overviewTileMinWidthMedium` | 232.0 | base.tokens.json |  | 2 | 0 | 1 | 1 |
| `Tokens.Size.overviewTileMinWidthLarge` | 320.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.headPadRight` | 8.0 | base.tokens.json |  | 2 | 1 | 1 | 0 |
| `Tokens.Size.headPadLeftList` | 16.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.headPadLeftStack` | 8.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.headGapList` | 8.0 | base.tokens.json |  | 4 | 3 | 1 | 0 |
| `Tokens.Size.headGapStack` | 4.0 | base.tokens.json |  | 2 | 1 | 1 | 0 |
| `Tokens.Size.menuEdge` | 8.0 | base.tokens.json |  | 3 | 2 | 1 | 0 |
| `Tokens.Size.menuRowHeight` | 28.0 | base.tokens.json |  | 3 | 3 | 0 | 0 |
| `Tokens.Size.menuRowPadding` | 12.0 | base.tokens.json |  | 3 | 3 | 0 | 0 |
| `Tokens.Size.menuRowGap` | 8.0 | base.tokens.json |  | 5 | 4 | 1 | 0 |
| `Tokens.Size.menuSeparatorInset` | 12.0 | base.tokens.json |  | 4 | 4 | 0 | 0 |
| `Tokens.Size.menuSeparatorSpace` | 4.0 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Size.blobStretchMax` | 0.16 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.blobWakeDistance` | 212.0 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Size.laneMinimumLeft` | 280.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.trailingTextInset` | 12.0 | base.tokens.json | prov | 4 | 4 | 0 | 0 |
| `Tokens.Size.hairline` | 1.0 | base.tokens.json |  | 30 | 30 | 0 | 0 |
| `Tokens.Size.handleLength` | 64.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.handleLengthActive` | 96.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.handleThicknessActive` | 2.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.fieldLabelWidth` | 48.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.recipientListMaxHeight` | 308.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.recipientInputMinWidth` | 64.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.composeSheetMinHeight` | 192.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.composeTextMinHeight` | 120.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.settingsTileHeight` | 112.0 | base.tokens.json | appr | 3 | 3 | 0 | 0 |
| `Tokens.Size.settingsTileMinWidth` | 112.0 | base.tokens.json | appr | 2 | 2 | 0 | 0 |
| `Tokens.Size.toggleKnobOffsetOn` | 14.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.toggleKnobOffsetOff` | 2.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.selectionRingWidth` | 2.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.overviewHoverLift` | 3.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.menuReelPerspective` | 600.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.orbGlowBlur` | 2.4 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.blobLidOffset` | 1.4 | base.tokens.json | appr | 2 | 2 | 0 | 0 |
| `Tokens.Size.confirmEnterBlur` | 3.0 | base.tokens.json | appr | 2 | 2 | 0 | 0 |
| `Tokens.Size.blobDragThreshold` | 3.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.blobFlingMinDistance` | 48.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.blobEyeFollowDistance` | 200.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.blobEyeFollowRamp` | 40.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.blobEyeTravelX` | 2.0 | base.tokens.json | appr | 2 | 2 | 0 | 0 |
| `Tokens.Size.blobEyeTravelY` | 1.6 | base.tokens.json | appr | 2 | 2 | 0 | 0 |
| `Tokens.Size.blobHomeRadius` | 200.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.blobLabelPadding` | 22.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.blobMenuMinHeight` | 160.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.laneSnap` | 12.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.laneHysteresis` | 64.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.breakpointFilterLabel` | 340.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.breakpointAttachments` | 560.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.breakpointNarrowCard` | 480.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.breakpointSendLabel` | 300.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.mailRowEstimate` | 88.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.stripReserveTop` | 24.0 | base.tokens.json | sbd | 2 | 1 | 1 | 0 |
| `Tokens.Size.stripReserveBottom` | 96.0 | base.tokens.json | sbd | 2 | 1 | 1 | 0 |
| `Tokens.Size.overviewActionsOffset` | 6.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.focusRingWidth` | 2.0 | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.Size.focusRingOffset` | 1.0 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Size.quoteBarWidth` | 2.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.markSeparatorRing` | 2.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.spinnerStroke` | 1.5 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.tileHoverLift` | 1.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.recipientLabelColumn` | 40.0 | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.Size.recipientMarkColumn` | 24.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.menuWidthStep` | 56.0 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Size.menuMinWidth` | 168.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.menuMaxWidth` | 280.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.cardStateTextMaxWidth` | 320.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.confirmPillWidth` | 96.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.confirmPillOffset` | 3.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Size.fieldLabelMinWidth` | 96.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.signatureEditorMinHeight` | 144.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.lockMarkSize` | 56.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.imageTileStripe` | 8.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.hintRadius` | 7.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackDropOffset` | 8.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackDropBlur` | 16.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackDropSpread` | -12.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatDropOffset` | 6.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatDropBlur` | 16.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatDropSpread` | -10.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatFrontOffset` | 8.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatFrontBlur` | 24.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.stackFlatFrontSpread` | -12.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.overviewTileEnter` | 10.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.mailLaneMaximumLeft` | 280.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.previewWindowWidth` | 1512.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.previewWindowHeight` | 982.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Size.previewMinWidth` | 640.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.previewMinHeight` | 480.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.ghostShadowOffset` | 8.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.ghostShadowBlur` | 24.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.ghostShadowSpread` | -12.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.envelopeStroke` | 1.15 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Size.mailLaneMinimumLeft` | 224.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Size.hintMaxWidth` | 240.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Spacing.step2` | 2.0 | base.tokens.json | sbd | 10 | 10 | 0 | 0 |
| `Tokens.Spacing.step4` | 4.0 | base.tokens.json | sbd | 51 | 50 | 1 | 0 |
| `Tokens.Spacing.step8` | 8.0 | base.tokens.json | sbd | 181 | 179 | 2 | 0 |
| `Tokens.Spacing.step12` | 12.0 | base.tokens.json | sbd | 41 | 41 | 0 | 0 |
| `Tokens.Spacing.step16` | 16.0 | base.tokens.json | sbd | 30 | 30 | 0 | 0 |
| `Tokens.Spacing.step20` | 20.0 | base.tokens.json | sbd | 11 | 11 | 0 | 0 |
| `Tokens.Spacing.step24` | 24.0 | base.tokens.json | sbd | 10 | 10 | 0 | 0 |
| `Tokens.Spacing.step28` | 28.0 | base.tokens.json | sbd | 19 | 19 | 0 | 0 |
| `Tokens.Spacing.step32` | 32.0 | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.Spacing.step36` | 36.0 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Spacing.step40` | 40.0 | base.tokens.json | sbd | 6 | 6 | 0 | 0 |
| `Tokens.Spacing.step44` | 44.0 | base.tokens.json | sbd | 11 | 11 | 0 | 0 |
| `Tokens.Spacing.step56` | 56.0 | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.Spacing.statusDot` | 8.0 | base.tokens.json |  | 3 | 3 | 0 | 0 |
| `Tokens.Spacing.blobInset` | 6.0 | base.tokens.json | appr | 5 | 4 | 1 | 0 |
| `Tokens.Radius.lane` | 20.0 | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Radius.blob` | 20.0 | base.tokens.json | sbd | 4 | 3 | 0 | 1 |
| `Tokens.Radius.contextMenu` | 16.0 | base.tokens.json | sbd | 3 | 2 | 0 | 1 |
| `Tokens.Radius.card` | 20.0 | base.tokens.json |  | 9 | 8 | 0 | 1 |
| `Tokens.Radius.row` | 12.0 | base.tokens.json | sbd | 18 | 17 | 0 | 1 |
| `Tokens.Radius.notice` | 8.0 | base.tokens.json | sbd | 6 | 5 | 0 | 1 |
| `Tokens.Radius.field` | 4.0 | base.tokens.json | sbd | 4 | 3 | 0 | 1 |
| `Tokens.Radius.stroke` | 2.0 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Radius.capsule` | 999.0 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Radius.cardBottom` | 0.0 | base.tokens.json |  | 2 | 1 | 0 | 1 |
| `Tokens.Duration.hover` | 0.16 | base.tokens.json | sbd | 10 | 10 | 0 | 0 |
| `Tokens.Duration.short` | 0.15 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.toggle` | 0.2 | base.tokens.json | sbd | 6 | 6 | 0 | 0 |
| `Tokens.Duration.chevron` | 0.24 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Duration.lane` | 0.26 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.recipientList` | 0.28 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Duration.blobEyes` | 0.32 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.stackBackground` | 0.32 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.rowSequence` | 0.36 | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Duration.blobFlight` | 0.416 | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Duration.stackLift` | 0.42 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.stack` | 0.52 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Duration.searchUnderline` | 0.48 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.fold` | 0.72 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Duration.thinking` | 1.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.pulse` | 1.8 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.blink` | 1.7 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.blobWidth` | 0.24 | base.tokens.json |  | 3 | 3 | 0 | 0 |
| `Tokens.Duration.overviewDelay` | 0.3 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Duration.overviewEnter` | 0.64 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Duration.tileHover` | 0.32 | base.tokens.json |  | 4 | 4 | 0 | 0 |
| `Tokens.Duration.labelDelay` | 0.08 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.reelStagger` | 0.04 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.ebbDelay` | 0.42 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Duration.ebbSlow` | 0.9 | base.tokens.json |  | 1 | 0 | 1 | 0 |
| `Tokens.Duration.confirmHold` | 1.0 | base.tokens.json | prov | 1 | 0 | 1 | 0 |
| `Tokens.Duration.confirmRelease` | 0.18 | base.tokens.json | prov | 1 | 0 | 1 | 0 |
| `Tokens.Duration.menuReelTransform` | 0.6 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.spinner` | 0.8 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.orbOrbitFirst` | 7.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Duration.orbOrbitSecond` | 9.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Duration.orbOrbitThird` | 11.0 | base.tokens.json | appr | 1 | 1 | 0 | 0 |
| `Tokens.Duration.blobBlinkClose` | 0.14 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.blobBlinkInterval` | 3.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.syncSpin` | 2.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.menuReelDelay` | 0.034 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.menuFocusDelay` | 0.08 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.menuHoverDelay` | 0.16 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.clickGuard` | 0.05 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.toast` | 1.8 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.searchFocusDelay` | 0.04 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.confirmDoneDelay` | 0.9 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.toastUndo` | 4.0 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Duration.scrollLineIn` | 0.32 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.scrollLineRest` | 0.42 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.scrollLineOut` | 0.9 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.toastFail` | 6.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.switchIn` | 0.36 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Duration.switchOut` | 0.76 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.hintDwell` | 3.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.deckClose` | 0.38 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Duration.switchLift` | 0.62 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.deckOpen` | 0.56 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Duration.deckOpenStagger` | 0.045 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.deckCloseStagger` | 0.03 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeFirst` | 0.42 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeSecond` | 0.48 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeThird` | 0.54 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeSecondDelayOpen` | 0.04 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeThirdDelayOpen` | 0.08 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.envelopeSecondDelayClose` | 0.02 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.flapOpen` | 0.52 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.flapOpenDelay` | 0.12 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.flapClose` | 0.26 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.switchFade` | 0.42 | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.Duration.switchGhostFade` | 0.32 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.switchContentFade` | 0.52 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Duration.glassDelay` | 0.04 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Easing.standard` | CubicBezier(x1: 0.2, y1: 0.8, x2: 0.2, y2: 1.0) | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Easing.blobFlight` | CubicBezier(x1: 0.2, y1: 1.15, x2: 0.3, y2: 1.0) | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Easing.stack` | CubicBezier(x1: 0.22, y1: 1.08, x2: 0.36, y2: 1.0) | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Easing.fold` | CubicBezier(x1: 0.65, y1: 0.0, x2: 0.25, y2: 1.0) | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Easing.deckOpen` | CubicBezier(x1: 0.3, y1: 1.32, x2: 0.5, y2: 1.0) | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Easing.deckClose` | CubicBezier(x1: 0.4, y1: 0.0, x2: 0.2, y2: 1.0) | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Easing.envelopeSpring` | CubicBezier(x1: 0.34, y1: 1.56, x2: 0.64, y2: 1.0) | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.Easing.glassIn` | CubicBezier(x1: 0.37, y1: 0.0, x2: 0.63, y2: 1.0) | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.Easing.glassOut` | CubicBezier(x1: 0.33, y1: 0.0, x2: 0.15, y2: 1.0) | base.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Tokens.TextSize.small` | 11.5 | base.tokens.json | sbd | 47 | 43 | 0 | 4 |
| `Tokens.TextSize.body` | 13.0 | base.tokens.json | sbd | 58 | 54 | 1 | 3 |
| `Tokens.TextSize.title` | 18.0 | base.tokens.json | sbd | 12 | 11 | 0 | 1 |
| `Tokens.TextSize.blobFace` | 9.0 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Weight.light` | 300 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Weight.regular` | 400 | base.tokens.json | sbd | 9 | 6 | 0 | 3 |
| `Tokens.Weight.medium` | 500 | base.tokens.json | sbd | 22 | 16 | 0 | 6 |
| `Tokens.Weight.semibold` | 600 | base.tokens.json | appr | 4 | 4 | 0 | 0 |
| `Tokens.LineHeight.small` | 16.0 | base.tokens.json | sbd | 3 | 0 | 0 | 3 |
| `Tokens.LineHeight.notice` | 20.0 | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.LineHeight.body` | 1.35 | base.tokens.json | sbd | 5 | 3 | 0 | 2 |
| `Tokens.LineHeight.title` | 1.25 | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.LineHeight.mailBody` | 1.6 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.LineHeight.counter` | 1.0 | base.tokens.json | sbd | 3 | 1 | 0 | 2 |
| `Tokens.LineHeight.control` | 18.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.LineHeight.heading` | 24.0 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Family.text` | ["Geist", "SF Pro Text", "system-ui"] | base.tokens.json |  | 4 | 3 | 1 | 0 |
| `Tokens.Count.stackMaxCards` | 6 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.overviewLinesSmall` | 3 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.overviewLinesMedium` | 4 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.overviewLinesLarge` | 8 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.contactSuggestions` | 5 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.senderSuggestions` | 8 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.attachmentsNarrow` | 2 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Count.attachmentsWide` | 3 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Count.stackHeads` | 3 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.menuStaggerMax` | 14 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Count.projectFilesMax` | 8 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Count.chatDocumentByteLimit` | 20000000 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Count.chatTextCharacterLimit` | 120000 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Opacity.ringOnColor` | 0.3 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Opacity.ringOnMark` | 0.22 | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.Opacity.cardMeta` | 0.72 | base.tokens.json | sbd | 2 | 1 | 1 | 0 |
| `Tokens.Opacity.cardMetaDeep` | 0.95 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Opacity.switchGlass` | 0.72 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Opacity.disabled` | 0.4 | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.Opacity.overviewOther` | 0.55 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Confirm.eraseEdge` | 0.2 | base.tokens.json | prov | 1 | 0 | 1 | 0 |
| `Tokens.Confirm.eraseBlur` | 0.6 | base.tokens.json | prov | 1 | 1 | 0 | 0 |
| `Tokens.Confirm.shakeFrom` | 0.7 | base.tokens.json | prov | 1 | 0 | 1 | 0 |
| `Tokens.Confirm.shakeAmplitude` | 1.5 | base.tokens.json | prov | 1 | 0 | 1 | 0 |
| `Tokens.Confirm.shakeFrequency` | 160.0 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Motion.deceleration` | 0.998 | base.tokens.json | sbd | 1 | 0 | 1 | 0 |
| `Tokens.Motion.menuReelTilt` | 60.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Motion.blobFlingSpeed` | 900.0 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Layer.lane` | 1 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Layer.handle` | 2 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Layer.syncButton` | 3 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Layer.toast` | 4 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Layer.blob` | 6 | base.tokens.json |  | 1 | 1 | 0 | 0 |
| `Tokens.Layer.inLaneOverview` | 2 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Layer.lockScreen` | 40 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Tracking.control` | 0.01 | base.tokens.json | sbd | 1 | 0 | 0 | 1 |
| `Tokens.Tracking.mark` | 0.06 | base.tokens.json | sbd | 5 | 3 | 0 | 2 |
| `Tokens.Tracking.title` | -0.02 | base.tokens.json | sbd | 2 | 1 | 0 | 1 |
| `Tokens.Scale.pressTile` | 0.98 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Scale.pressButton` | 0.96 | base.tokens.json | sbd | 6 | 6 | 0 | 0 |
| `Tokens.Scale.pressRow` | 0.99 | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Scale.pressStrong` | 0.92 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Scale.overviewHot` | 1.012 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Scale.overviewOther` | 0.988 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Ratio.imageTile` | 1.3333 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Ratio.fieldValueMax` | 0.6 | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.TextStyle.body` | TypeStyle(size: TextSize.body, weight: Weight.regular, tracking: 0.… | base.tokens.json | sbd | 9 | 9 | 0 | 0 |
| `Tokens.TextStyle.bodyEmphasis` | TypeStyle(size: TextSize.body, weight: Weight.medium, tracking: 0.0… | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.TextStyle.caption` | TypeStyle(size: TextSize.small, weight: Weight.regular, tracking: 0… | base.tokens.json | sbd | 14 | 14 | 0 | 0 |
| `Tokens.TextStyle.captionEmphasis` | TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: 0.… | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.TextStyle.control` | TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: Tr… | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.TextStyle.mark` | TypeStyle(size: TextSize.small, weight: Weight.medium, tracking: Tr… | base.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Tokens.TextStyle.markSmall` | TypeStyle(size: TextSize.blobFace, weight: Weight.medium, tracking:… | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.TextStyle.title` | TypeStyle(size: TextSize.title, weight: Weight.medium, tracking: Tr… | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.TextStyle.mailBody` | TypeStyle(size: TextSize.body, weight: Weight.regular, tracking: 0.… | base.tokens.json | sbd | 5 | 5 | 0 | 0 |
| `Tokens.Transition.blobFlight` | Timing(duration: Duration.blobFlight, delay: 0.0, easing: Easing.bl… | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Transition.stack` | Timing(duration: Duration.stack, delay: 0.0, easing: Easing.stack) | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Transition.fold` | Timing(duration: Duration.fold, delay: 0.0, easing: Easing.fold) | base.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Tokens.Transition.deckClose` | Timing(duration: Duration.deckClose, delay: 0.0, easing: Easing.dec… | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Tokens.Transition.deckOpen` | Timing(duration: Duration.deckOpen, delay: 0.0, easing: Easing.deck… | base.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.ground` | hell #ffffff / dunkel #0d0d0d | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.line` | hell #e8e8e8 / dunkel #2a2a2a | theme-light + theme-dark.tokens.json | sbd | 10 | 10 | 0 | 0 |
| `Colors.lineStrong` | hell #d9d9d9 / dunkel #3a3a3a | theme-light + theme-dark.tokens.json | sbd | 18 | 18 | 0 | 0 |
| `Colors.ink` | hell #171717 / dunkel #fafafa | theme-light + theme-dark.tokens.json | sbd | 55 | 55 | 0 | 0 |
| `Colors.inkSecondary` | hell #4d4d4d / dunkel #d9d9d9 | theme-light + theme-dark.tokens.json | sbd | 23 | 23 | 0 | 0 |
| `Colors.inkTertiary` | hell #6b6b6b / dunkel #a3a3a3 | theme-light + theme-dark.tokens.json | sbd | 50 | 50 | 0 | 0 |
| `Colors.well` | hell #f5f5f5 / dunkel #1f1f1f | theme-light + theme-dark.tokens.json | sbd | 9 | 9 | 0 | 0 |
| `Colors.hover` | hell rgba(0,0,0,0.05) / dunkel rgba(1,1,1,0.08) | theme-light + theme-dark.tokens.json | sbd | 10 | 10 | 0 | 0 |
| `Colors.selection` | hell rgba(0,0,0,0.05) / dunkel rgba(1,1,1,0.08) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.focus` | hell #6b6b6b / dunkel #a3a3a3 | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.inverse` | hell #171717 / dunkel #f5f5f5 | theme-light + theme-dark.tokens.json | sbd | 19 | 19 | 0 | 0 |
| `Colors.onInverse` | hell #ffffff / dunkel #0d0d0d | theme-light + theme-dark.tokens.json | sbd | 18 | 18 | 0 | 0 |
| `Colors.inverseHot` | hell rgba(1,1,1,0.12) / dunkel rgba(0,0,0,0.08) | theme-light + theme-dark.tokens.json | sbd | 6 | 6 | 0 | 0 |
| `Colors.inverseLine` | hell rgba(1,1,1,0.2) / dunkel rgba(0,0,0,0.14) | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.inverseField` | hell rgba(1,1,1,0.08) / dunkel rgba(0,0,0,0.05) | theme-light + theme-dark.tokens.json | sbd | 6 | 6 | 0 | 0 |
| `Colors.safeArea` | hell #000000 / dunkel #000000 | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.menu` | hell #ffffff / dunkel #1f1f1f | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.signal` | hell #b3412e / dunkel #e08a74 | theme-light + theme-dark.tokens.json | sbd | 24 | 24 | 0 | 0 |
| `Colors.sheet` | hell #ffffff / dunkel #ffffff | theme-light + theme-dark.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Colors.sheetInk` | hell #171717 / dunkel #171717 | theme-light + theme-dark.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Colors.sheetInkSecondary` | hell #4d4d4d / dunkel #4d4d4d | theme-light + theme-dark.tokens.json | sbd | 4 | 4 | 0 | 0 |
| `Colors.sheetInkTertiary` | hell #6b6b6b / dunkel #6b6b6b | theme-light + theme-dark.tokens.json | sbd | 11 | 11 | 0 | 0 |
| `Colors.sheetLine` | hell #e8e8e8 / dunkel #e8e8e8 | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.glaze` | hell rgba(1,1,1,0.75) / dunkel rgba(1,1,1,0.07) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.sheetWell` | hell #f5f5f5 / dunkel #f5f5f5 | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.sheetLineStrong` | hell #d9d9d9 / dunkel #d9d9d9 | theme-light + theme-dark.tokens.json | sbd | 3 | 3 | 0 | 0 |
| `Colors.onSignal` | hell #ffffff / dunkel #0d0d0d | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.onInverseSecondary` | hell rgba(1,1,1,0.8) / dunkel rgba(0,0,0,0.72) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.onInverseTertiary` | hell rgba(1,1,1,0.6) / dunkel rgba(0,0,0,0.55) | theme-light + theme-dark.tokens.json | sbd | 8 | 8 | 0 | 0 |
| `Colors.onInverseLine` | hell rgba(1,1,1,0.3) / dunkel rgba(0,0,0,0.22) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.orb` | hell #0d0d0d / dunkel #0d0d0d | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.orbRim` | hell rgba(1,1,1,0.12) / dunkel rgba(1,1,1,0.12) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.orbGloss` | hell rgba(1,1,1,0.28) / dunkel rgba(1,1,1,0.28) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.lane` | hell #ffffff / dunkel #141414 | theme-light + theme-dark.tokens.json | sbd | 27 | 27 | 0 | 0 |
| `Colors.stackGlossFront` | hell rgba(1,1,1,1) / dunkel rgba(1,1,1,0.14) | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.stackGlossLight` | hell rgba(1,1,1,0.9) / dunkel rgba(1,1,1,0.9) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.stackGlossDark` | hell rgba(1,1,1,0.22) / dunkel rgba(1,1,1,0.22) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.stackSeamFront` | hell rgba(0,0,0,0.14) / dunkel rgba(0,0,0,0.7) | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.stackSeamBack` | hell rgba(0,0,0,0.2) / dunkel rgba(0,0,0,0.7) | theme-light + theme-dark.tokens.json | sbd | 2 | 2 | 0 | 0 |
| `Colors.stackDrop` | hell rgba(0,0,0,0.16) / dunkel rgba(0,0,0,0.55) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.stackRing` | hell rgba(0,0,0,0.06) / dunkel rgba(0,0,0,0.06) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.stackFlatDrop` | hell rgba(0,0,0,0.18) / dunkel rgba(0,0,0,0.18) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.stackFlatFront` | hell rgba(0,0,0,0.22) / dunkel rgba(0,0,0,0.22) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.dhlYellow` | hell #ffcb01 / dunkel #ffcb01 | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.ghostShadow` | hell rgba(0,0,0,0.22) / dunkel rgba(0,0,0,0.22) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.ghostRing` | hell rgba(0,0,0,0.06) / dunkel rgba(0,0,0,0.06) | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.claudeClay` | hell #d77655 / dunkel #d77655 | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.sevdeskRed` | hell #fb523b / dunkel #fb523b | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `Colors.clockodoBlue` | hell #3657f7 / dunkel #3657f7 | theme-light + theme-dark.tokens.json | sbd | 1 | 1 | 0 | 0 |
| `SheetValues.weightAxis` | 0x7767_6874 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.releaseSamples` | 6 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.releaseSpan` | 0.016 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.lidRestScale` | 0.45 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.blinkScale` | 0.1 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.winkScale` | 0.08 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.winkCloseAt` | 0.44 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.winkOpenAt` | 0.68 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.labelMaxWidth` | 200.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.pulseScale` | 2.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.orbSpot` | 0.58 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.orbOrbit` | 0.24 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.orbGlossX` | 0.35 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.orbGlossY` | 0.28 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.orbGlossStop` | 0.45 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.keyframeMiddle` | 0.5 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.laneShiftStep` | 8.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.iconSize` | 14.0 | SheetValues (Code) |  | 3 | 3 | 0 | 0 |
| `SheetValues.iconBox` | 16.0 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.iconStroke` | 1.3 | SheetValues (Code) |  | 3 | 3 | 0 | 0 |
| `SheetValues.iconOpacity` | 0.8 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.placeholderOpacity` | 0.45 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.mutedOpacity` | 0.6 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.tapeFadeAt` | 0.4 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.syncArcStart` | -90.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.syncSweep` | 720.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.syncErrorArc` | 0.25 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.closeOpacity` | 0.7 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.cssEase` | CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1) | SheetValues (Code) |  | 5 | 5 | 0 | 0 |
| `SheetValues.fieldTrailingMaxShare` | 0.5 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.smallIcon` | 12.0 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.smallIconStroke` | 1.5 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.compactValueSize` | 12.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.tinyIcon` | 10.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.tinyIconStroke` | 1.8 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.overviewStaggerCap` | 8 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.overviewTileStagger` | 0.024 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.overviewTileTextLine` | 1.5 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.overviewTitleLines` | 2 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.spinnerArc` | 0.22 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.confirmSpinnerArc` | 0.25 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.statusArcBox` | 12.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.statusArc` | 0.3 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.dashedLine` | [2.0, 2.0] | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.fullTurn` | 360.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.halfTurn` | 180.0 | SheetValues (Code) |  | 3 | 3 | 0 | 0 |
| `SheetValues.quarterTurn` | 90.0 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.orbCount` | 3 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.rowTextLine` | 20.0 | SheetValues (Code) |  | 3 | 3 | 0 | 0 |
| `SheetValues.previewLines` | 2 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.attachmentChipNameLimit` | 26 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.attachmentNameLimit` | 34 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.listWindow` | 60 | SheetValues (Code) |  | 3 | 3 | 0 | 0 |
| `SheetValues.tilesBreakpoint` | 320.0 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.listWindowStep` | 120 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.listLoadAhead` | 1200.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.conversationLine` | 16.0 | SheetValues (Code) |  | 4 | 4 | 0 | 0 |
| `SheetValues.cardTitleLimit` | 34 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.cardAddressLimit` | 36 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.hintTick` | 0.1 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.linkFieldWidth` | 240.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.deckLift` | 0.32 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.stackGlossLightFrom` | 0.7529 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.ghostStart` | 0.02 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.ghostLife` | 1.2 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeBox` | 20.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeWidth` | 14.0 | SheetValues (Code) |  | 2 | 2 | 0 | 0 |
| `SheetValues.envelopeHeight` | 10.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeRadius` | 2.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeOpenX` | [3.0, 3.0, 3.0] | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeOpenY` | [4.0, 6.2, 8.4] | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeShutX` | [2.0, 3.6, 5.2] | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeShutY` | [7.0, 5.2, 3.4] | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeTimes` | [Tokens.Duration.envelopeFirst, Tokens.Duration.envelopeSecond, Tok… | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeOpenDelays` | [0, Tokens.Duration.envelopeSecondDelayOpen, Tokens.Duration.envelo… | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeShutDelays` | [0, Tokens.Duration.envelopeSecondDelayClose, 0] | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeFlapInset` | 1.0 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeFlapTop` | 1.4 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `SheetValues.envelopeFlapDepth` | 4.2 | SheetValues (Code) |  | 1 | 1 | 0 | 0 |
| `Tokens.Size.assistantFieldHeight` | 40.0 | base.tokens.json |  | 0 | 0 | 0 | 0 |
| `Tokens.Size.composeColumnMinWidth` | 96.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.breakpointStack` | 440.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.stackFanStep` | 52.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.safeAreaTop` | 32.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.tileLogoSize` | 18.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.reelTopOffset` | 8.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.accountFanWidth` | 220.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.accountClosedWidth` | 260.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.lockFieldWidth` | 240.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Size.profileFactMinWidth` | 140.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Duration.overviewStagger` | 0.06 | base.tokens.json |  | 0 | 0 | 0 | 0 |
| `Tokens.Duration.tileActions` | 0.24 | base.tokens.json |  | 0 | 0 | 0 | 0 |
| `Tokens.Opacity.hoverDim` | 0.88 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Confirm.originDefault` | 40.0 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Layer.menu` | 5 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Layer.safeArea` | 7 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Layer.inLaneToast` | 3 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Layer.switchGlass` | 30 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Layer.hint` | 40 | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneRadius` | Radius.lane | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneEdge` | Size.edge | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneGap` | Size.gutter | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneHeaderHeight` | Size.headerHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneFoldedWidth` | Size.foldedWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneFoldThreshold` | Size.foldThreshold | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneMiddleMinimumWidth` | Size.middleMinimumWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.rowHeight` | Size.rowHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.rowRadius` | Radius.row | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.symbolSize` | Size.symbolSize | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobHeight` | Size.blobHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobWidth` | Size.blobWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobAwakeWidth` | Size.blobAwakeWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobDockDistance` | Size.blobDockDistance | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobRadius` | Radius.blob | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.menuRadius` | Radius.contextMenu | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.cardRadius` | Radius.card | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.cardInset` | Size.cardInset | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.noticeRadius` | Radius.notice | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.fieldRadius` | Radius.field | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.capsuleRadius` | Radius.capsule | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneRestWidth` | Size.laneRestWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.laneMinimumRightWidth` | Size.laneMinimumRight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobPopupFallbackWidth` | Size.blobPopupFallbackWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.cardFooterHeight` | Size.footerHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.cardRadiusBottom` | Radius.cardBottom | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobEyeWidth` | Size.blobEyeWidth | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobEyeHeight` | Size.blobEyeHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.blobEyeGap` | Size.blobEyeGap | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.suggestionRowHeight` | Size.suggestionRowHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.chipHeight` | Size.chipHeight | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.overviewTileHeightMedium` | Size.overviewTileHeightMedium | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Tokens.Component.overviewTileMinWidthMedium` | Size.overviewTileMinWidthMedium | base.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Colors.mark` | hell #8a8a8a / dunkel #8a8a8a | theme-light + theme-dark.tokens.json | sbd | 0 | 0 | 0 | 0 |
| `Colors.handle` | hell #a3a3a3 / dunkel #6b6b6b | theme-light + theme-dark.tokens.json | sbd | 0 | 0 | 0 | 0 |
