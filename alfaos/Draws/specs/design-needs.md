# Spec · Design-Verdrahtung Draws gegen ALFA

Stand 23.10.2026 · Draws-Zweig `alfa-draws` gegen `origin/main` (6b9b7f2). Befund, keine Änderung am Code.
Master laut `DESIGN/MANIFEST.json`: latest = `ALFA OS Interface CHEF 1610-handoff 1810.zip` (2026-10-18), previous = `ALFA OS Interface CHEF 1610.zip` (2026-10-17). Tokenquelle des Generators: `TOKENBOGEN.json` im Master (Stand 18.10.2026 21:18), erzeugt `alfaos/Kit/Sources/ShellCore/DesignTokens.swift`; Stempel `DesignStamp` ebd.
Kit-Lag: Kit auf `alfa-draws` steht auf Merge-Base b1fbf02 (2026-10-21), main ist 94 Commits weiter; Unterschied im Kit: 33 Dateien (Hub, Mail, ShellCore/Initials.swift, ShellCore/SettingsSections.swift, Tests). `DesignTokens.swift` und `SheetValues.swift` sind auf beiden Ständen byte-gleich. Draws importiert nur `ShellCore` (Package.swift:35, :40).
Kürzel: `A/` = `alfaos/Draws/Sources/DrawingDudeApp/`. `main:` = `origin/main:`. Grenze: Komponenten in `main:alfaos/App/Components/` und `main:alfaos/App/Theme/` liegen im App-Ziel; Draws kann sie nicht importieren. Nur `ShellCore` (Kit) ist von Draws aus erreichbar.

## Umverdrahten jetzt (Draws → ALFA-Token oder -Komponente, die auf main schon existiert)
- Schriftachse `0x7767_6874` und Fallback-Gewichtung doppelt zu `Typeface` (main:Theme/Theme.swift, dort `private`) → Kit-Verschiebung nötig, dann ein Ort: A/Style.swift:34-44
- Zeilenabstand `Design.LineHeight.small - Design.TextSize.small` von Hand → `lineHeight(Design.LineHeight.small, size:)` (main:ComponentStyle.swift, App-Ziel, nach Kit-Verschiebung): A/Parts.swift:121

## Design-Bedarf Draws (fehlt in ALFA: Zweck, Fundstelle, heutiger Wert als Hinweis)
Visuell (braucht Master):
- Abdunkeln beim Rechnen, Zweck Foto/Claude läuft: `Proto.busy` 0.6; A/Proto.swift:36, A/Lanes.swift:708, A/ClaudePanel.swift:65. Zahl gleich `SheetValues.mutedOpacity`, Zweck anders, nicht über Zahl wiederverwenden
- Abdunkeln ausgeblendeter Zeile (Teil versteckt): `Proto.hidden` 0.45; A/Proto.swift:35, A/Parts.swift:168. Zahl gleich `SheetValues.placeholderOpacity`, Zweck anders
- Breite schwebende Leerkarte auf dem Blatt: `Proto.emptyWidth` 300; A/Proto.swift:31, A/Lanes.swift:446
- Breite schwebendes Assistentenfeld: `Proto.assistantWidth` 340; A/Proto.swift:32, A/ClaudePanel.swift:73. Kein Token der Menübreiten (`menuWidth*`) hat diesen Zweck
- Quellen-Kachel im Assistentenfeld (Foto/PDF/Text): Höhe `Proto.tileHeight` 56; A/Proto.swift:33, A/ClaudePanel.swift:146; Glyphgröße `Spacing.step16` A/ClaudePanel.swift:141; Zustände an/aus nur mit `well` und `ink`
- Sichtbare Zeilen der Zugliste im Assistentenfeld: `Proto.moveRows` 4; A/Proto.swift:56, A/ClaudePanel.swift:119 (multipliziert mit `Size.rowHeight`)
- Zeilenzahl Stimme: `Proto.voiceLines` 4; A/Proto.swift:57, A/ClaudePanel.swift:121
- Mindestgröße Fenster: aus `laneMinimumLeft*3` und `blobMenuMinHeight*3` abgeleitet (840 x 480), Tokens dafür nicht gemeint: A/DrawsApp.swift:16; ALFA liest sie aus shell.json (main:ALFA_OSApp.swift:36)
- Voreingestellte Fenstergröße 1512 x 982: A/DrawsApp.swift:19; ALFA hat `SheetValues.previewScreen` (1512 x 982) nur als Vorschau
- Griffe an Zellecken (Größe ändern): Kantenlänge aus `Spacing.statusDot` 8 geliehen, Zweck Statuspunkt: A/Lanes.swift:359
- Strichelung von Führungslinien und Überlauf: Länge `Spacing.step4` als Zahl; `SheetValues.dashedLine` [2, 2] hat anderen Zweck und Wert: A/Lanes.swift:310,332,352
- Regler (Slider) Spur: Dicke aus `Radius.stroke` (2) geliehen, Knopf `Spacing.step16`, Trefferhöhe `Spacing.step20`, Schatten `knob`: A/Parts.swift:357-372. Kein Regler im Master
- Abschnittskopf (SectionHead) Höhe aus `Spacing.step32` geliehen, Schrift small tertiär: A/Parts.swift:94-111. Nächstes ALFA: Listenkopf in `main:MailFolderLane.swift:59` (minHeight step32), kein Bauteil
- Zeile mit Beschriftung links, Wert/Bedienelement rechts (`Labeled`): Höhe `Size.rowHeight`, Schrift body secondary: A/Parts.swift:211-231. ALFA `SettingsRow` hat anderes Maß (min 44, Linie, Sub-Text)
- Feld mit Beschriftung und Rand beim Überfahren (`FieldRow`): Labelbreite `Size.fieldLabelWidth` 48 (Token gehört `mail.compose`), Höhe `rowHeight`, Rand `lineStrong` bei Hover, Fehlerton `signal`: A/Parts.swift:176-209. ALFA `InputField` ist Unterstrich-Feld, keine Zeile
- Farbfelder-Reihe (Swatches): Größe `Spacing.step20`, Auswahlring `Size.selectionRingWidth`: A/Parts.swift:382-407
- Textfeld-Editor im Assistentenfeld: Höhe `Size.composeTextMinHeight` 120 (gehört Mail-Komposition): A/ClaudePanel.swift:170
- Fußzeile des Assistentenfelds: `Size.footerHeight`: A/ClaudePanel.swift:70
- Blattfarbleiter für Flächentöne: `sheet`, `sheetWell`, `sheetLine`, `sheetLineStrong`, `handle` nach Wert gereiht, Zweck der Tokens ist anders (Linien, Mulden): A/DrawsModel.swift:62-66
- Flächenfarben der drei Würfelseiten Standard (oben, Seite, vorn): `sheetWell`, `sheetLineStrong`, `sheetLine`: A/DrawsModel.swift:67-70
- Akzentfarben für hervorgehobenes Teil: `signal`, Mood `apricot`, Mood `coral`, `sheetInk` (Moods im Master als Farbstimmung, nicht als Akzentpalette): A/DrawsModel.swift:72-76
- Icons: Draws nutzt ausschließlich SF Symbols (`Image(systemName:)`), ALFA hat eigenen Strich-Satz `Icon` mit `Glyph`. Fehlend im Satz: plus, minus.magnifyingglass, plus.magnifyingglass, eye, eye.slash, chevron.left, chevron.right, tray, tray.full, door.left.hand.closed, chevron.up.square, square, shippingbox, cube, stairs, rectangle.split.2x1, trapezoid.and.line.vertical, camera, photo, text.alignleft, ruler, internaldrive, ellipsis (ALFA hat `more`). Vorhanden und zuordenbar: xmark=`close`, grid=`grid`, exclamationmark.triangle=`alert`, doc=`doc`, doc.text=`docText`, link=`link`, checkmark=`check`, chevron.down=`chevron`, arrow.up=`send`, arrow.up.left.and.arrow.down.right=`expand`, arrow.down.right.and.arrow.up.left=`shrink`, square.and.arrow.down=`save`. Fundstellen: A/Parts.swift:51 (Glyph), A/Layouts.swift:33-37, A/Lanes.swift:31,33,71,92,138,150,154-156,246,251,461,477,485,512,617-619,682,719-721, A/ClaudePanel.swift:93-95,141,183-185
- Zoomwerte Anzeige: Format `draws.zoom.value` 'n %' – kein Token; Zoomgrenzen `Proto.zoomMin` 0.25, `zoomMax` 4.0, `zoomStep` 1.25: A/Proto.swift:21-23 (Fachwert, Anzeige im Kopf A/Lanes.swift:141)
- Schreibtischrand um das Blatt: `Proto.deskPadding` 48 (kein `Spacing.step48`): A/Proto.swift:20, A/Lanes.swift:259
- Blattfläche Hintergrund (well) und Schatten `floating`: Tokens vorhanden, Zweck (Zeichentisch) nicht im Master: A/Lanes.swift:161,294-295
- Statusstreifen und Pager auf dem Blatt (Kapsel auf `lane` mit Schatten `lane`, Höhe `Spacing.step24`): kein Master; A/Lanes.swift:238-241,253-255
Fachwerte (kein Design, aber in `Proto`; bleiben, mit Fundstelle):
- Raster `Proto.grid` 10, `gridMajor` 50 (mm): A/Proto.swift:18-19; Fang `snap` 6 (pt): :25; `minCell` 40 (mm): :26; Anteile `customerShare` 0.64, `stepsRatio` 1.6: :27-28
- Perspektive `perspectiveDistance` 4.5: A/Proto.swift:24; Unterlage `underlay` 0.35, `underlaySide` 2400: :37-38; Gleitschritte `glideSteps` 8: :46 (benutzt A/DrawsModel.swift:283)
- Regler-Bereiche (`Dial`) azimuth, elevation, edge, outline, shadow, pose, tile, roughness: A/Proto.swift:40-45,51-52
- Foto `photoWidth` 1600, `photoHeight` 1000, `photoBackdrop` true, `photoMargin` 0.1; Vorschau `previewDPI` 80: A/Proto.swift:47-50,53
- Lauf `liveRounds` 40, `liveTokens` 150000: A/Proto.swift:54-55
Zahlen und Formate in der Oberfläche ohne Katalogschlüssel (ALFA-Regel: Texte nur aus der Tabelle):
- Maßstab `"1:\(Int(...))"`: A/Lanes.swift:504,513,602,603; Pager `"\(page+1)/\(count)"`: :247; Seitenzahl `"\(count)"` als Meta: :69,107,501,509,680; Teilemaße `"w × d × h"`: :92; Trennpunkt `" · "`: :15,109; Schrittzahlen `"\($0 + 1)"`: :612; Texturkachel `"\(Int(tile))"`: :687; Zahlenformat `"%.2f"` mit Komma-Ersetzung: :659; Listen-Locale `"de"` fest: :226
- Pill `say(key)` für Beschriftung, aber `Text(verbatim:)` für Werte (A/Parts.swift:149,154): in Ordnung, nur Kennzeichnung

## Komponenten (Draws-Teil → ALFA-Teil; Hinweis)
- `Pill` (Button) → `TextButton` (`main:Components/TextButton.swift`, Arten accent/neutral/signal/plain/destructive/quiet/sheet, Größen regular/compact, PressScale): A/Parts.swift:263-285. Name kollidiert mit ALFA `Pill` (Form, ComponentStyle.swift). Draws hat keinen Druck-Effekt und kein Reduced-Motion
- `Segments` → `SegmentedControl` (`SegmentOption`, Optionen als `Text`): A/Parts.swift:233-261. Gleiche Maße (`step28 - chipHeight`); Draws mit `fill` (volle Breite) und `literal`, die ALFA nicht kennt; Draws ohne Button/Accessibility
- `Switch` → `ToggleSwitch`: A/Parts.swift:315-336. Abweichung im Aussehen: Draws Spur `lineStrong` gefüllt bei aus und Schatten `knob`, Knopf immer `lane`; ALFA Spur leer mit Ring bei aus und Knopf `inkTertiary`
- `SymbolButton` → `SymbolButton` (gleicher Name, `Icon` statt SF Symbol, `selected/hover/plate/ringTone`, PressScale): A/Parts.swift:55-77. Draws hat Hilfetext `.help`, kein Accessibility-Label, Fläche über `onTapGesture`
- `Mark` → `Mark` (gleicher Name; ALFA Größe regular/small, Füllung rest/filled/signal, Zeichen als Inhalt): A/Parts.swift:79-92
- `Glyph` → `Glyph` (gleicher Name; ALFA zeichnet `Icon`-Pfade im 16er Kasten, Strichstärke `iconStroke`): A/Parts.swift:46-53
- `ListRow` → `LaneRow` (Zeichen, Beschriftung, Zähler `Counter`): A/Parts.swift:130-174. Draws ergänzt `meta`, `bold`, `dim`, `end`-Knopf, Töne; Zeilenabstand `Spacing.step12`, ALFA `SheetValues.rowSpacing` 20
- `Compose` → `ComposeButton` (fester Mail-Text): A/Parts.swift:409-439. Draws allgemein (Schlüssel, Zeichen, Zusatz); ALFA fügt Druckeffekt `pressScaleCompose` 0.98 und Tastenkürzel hinzu
- `Head` → `LaneHead` (Hintergrund `laneFill`, Linie erst beim Scrollen): A/Parts.swift:4-16. Draws zeichnet die Linie immer
- `HeadTitle` → `HeaderTitle`: A/Parts.swift:26-44. Draws mit Zusatztext (`detail`), ALFA ohne
- `Line` → `Hairline`: A/Parts.swift:18-24
- `Divide` (senkrechter Trenner im Kopf): A/Lanes.swift:421-429; kein ALFA-Gegenstück, `CommandHead` gruppiert ohne Trenner
- `Note` → `Notice` (Arten failure/success/info/warning, Marke, `onSheet`): A/Parts.swift:113-128. Draws ist reiner Text mit Ton
- `Choice` (Menü-Knopf mit Kapsel) → `Disclosure` (Kapsel mit Chevron) und `AnchoredMenu`/`MenuItem`/`MenuEntry`: A/Parts.swift:287-313. Draws nutzt SwiftUI `Menu`, nicht das ALFA-Menü
- `FieldRow` → kein gleiches ALFA-Teil (`InputField` Unterstrich; `FieldRow` nur lokal in `main:Mail/MailComposeView.swift:50`): A/Parts.swift:176-209
- `Labeled` → `SettingsRow` (nur teilweise gleich): A/Parts.swift:211-231
- `SectionHead` → kein ALFA-Teil (Listenkopf nur lokal in MailFolderLane): A/Parts.swift:94-111
- `LaneBox` → `LaneView` (Falt-Streifen, Marken, Schatten `lane`, Barrierefreiheit, Umgebung `laneFill`/`hairline`): A/Shell.swift:94-113
- `Handle` → `HandleView`: A/Shell.swift. Fehlt: Barrierefreiheit, `ShellModel`-Anbindung
- `Blob` → `BlobView` und `BlobMenu` (Augen folgen, Wecken, Flug, Suche, Rolle): A/Shell.swift:158-215. Draws: starre Zeilen, kein Suchfeld, keine Bewegung. Augen/Gesicht mit denselben Tokens
- `ShellScreen` → `ShellView`: A/Shell.swift:7-92
- `ClaudePanel` → kein ALFA-Teil; ALFA kennt `assistant.*`-Schlüssel (Assistent), Fläche `Radius.contextMenu`, `menu`, Schatten `floating` wie `AnchoredMenu`: A/ClaudePanel.swift:6-77
- `EmptyCard` → kein ALFA-Teil (`ContentState` für leere Zustände): A/Lanes.swift:431-450
- `Style` → `DesignStyle` + `Theme`; `Face` → `Typeface`; `Shadowed` → `ThemeShadow`/`floatingShadow`; `StyleKey` → `\.design`; `Catalog/say/word` → `Theme.text/string` und `word(_:) -> Text`: A/Style.swift:7-103. Hier dreifach Doppelung. Verschiebung der Basis (Schrift, Schatten, Pill-Form, Ring, PressScale, Motion) von App nach Kit oder in ein gemeinsames Paket ist Voraussetzung für Wiederverwendung — Entscheid der Lead
- `Slider` (`SliderRow`), `Swatches`: kein ALFA-Teil
- `Dial` (Regler-Bereich): fachlich, kein ALFA-Teil: A/Proto.swift:3-15

## Namen
Stringschlüssel:
- ALFA-Schema: `<bereich>.<gruppe>.<name>`, camelCase im letzten Teil, Bereiche mail, settings, assistant, lane, menu, card, hint, field, overview, sync, app, text, group, confirm, error, offer, stack (main:Localizable.xcstrings, 488 Schlüssel). Draws: 234 Schlüssel `draws.*` plus 21 `dock.*` (Localizable.xcstrings, 255)
- `draws.*` folgt `draws.<gruppe>.<name>` (gleiches Schema); Ausnahme zweiteilig ohne Gruppe: `draws.raster` (Draws Localizable.xcstrings, benutzt A/Lanes.swift:154) → `draws.sheet.raster`
- Bereichsname `draws` statt Lane-/Modulname: ALFA benennt nach Bereich (`mail`, `settings`); `draws` ist der Bereichsname von Draws, bleibt. `dock.*` ist ein zweiter Bereichsname in Draws (Ports, Gründe, Zustände): A/ClaudeEntry.swift:13 (`dock.state.connected`), A/DrawsModel.swift:378,652,885-886
- Gleichlautende Texte unter anderem Schlüssel: `draws.claude.key` ↔ `settings.access.key`; `dock.state.connected` ↔ `settings.link.connected`; `draws.brief.remove`/`draws.tool.remove_part` ↔ `mail.compose.remove`; `draws.export.print` ↔ `mail.action.print`; `draws.export.savePDF` ↔ `mail.action.pdf`; `draws.cell.stepsOff` ↔ `settings.cadence.off`; `draws.claude.model` ↔ `settings.service.claude.field.model`. Nur bei gleichem Zweck zusammenlegen
- Mischformen: `draws.tool.render_preview`, `draws.tool.remove_part` mit Unterstrich (Werkzeugnamen der KI) gegen camelCase überall sonst: Draws Localizable.xcstrings, A/ClaudePanel.swift:111
- `word(_:)` liefert in Draws `String`, in ALFA `Text` (main:Host/AppHost.swift:182); `words(_:_:)` liefert `String` (main:Mail/MailKit.swift:55); `say(_:)` liefert `Text`. Gleicher Name, anderer Typ: A/Style.swift:75-81
Typ- und Viewnamen (Draws ↔ ALFA, gleicher Begriff):
- Lane: Draws-Spuren `ProjectLane`, `SheetLane`, `InspectorLane` A/Lanes.swift:7,118,452 ↔ ALFA `MailListLane`, `MailFolderLane`, `MailStackLane`, `SettingsLaneView`
- Fläche: `LaneBox` ↔ `LaneView`; `ShellScreen` ↔ `ShellView`; `Blob` ↔ `BlobView`/`BlobMenu`; `Handle` ↔ `HandleView`
- Kopf: `Head` ↔ `LaneHead`; `HeadTitle` ↔ `HeaderTitle`; `Line` ↔ `Hairline`
- Zeile: `ListRow` ↔ `LaneRow`; `Labeled` ↔ `SettingsRow`; `FieldRow` ↔ `InputField` (anderer Aufbau)
- Knöpfe: `Pill` ↔ `TextButton` (ALFA `Pill` ist die Form); `Compose` ↔ `ComposeButton`; `Segments` ↔ `SegmentedControl`; `Switch` ↔ `ToggleSwitch`; `Choice` ↔ `AnchoredMenu`
- Meldung: `Note` ↔ `Notice`; `EmptyCard` ↔ `ContentState`
- Karte: Draws kennt `EmptyCard`, ALFA `Card…` (`CardHeader`, `CardPile`, `MailCardView`) für gestapelte Mail-Karten; Draws-„Karte“ ist ein schwebendes Feld, ALFA-„Panel“/Menü `AnchoredMenu`. Begriffe „Blatt“ (Sheet) in Draws: `SheetLane`, `Sheet`, `draws.lane.sheet`; ALFA `sheet` ist Farbname/Art `TextButtonKind.sheet`/`onSheet` für Papierflächen. Kein Namenskonflikt, aber Doppelbedeutung
- Stil: `Style` ↔ `DesignStyle`/`Theme`; `Face` ↔ `Typeface`; `Shadowed`/`shadowed` ↔ `ThemeShadow`/`themeShadow`; `StyleKey`/`\.style` ↔ `\.design`
- Tabs: Draws `Tab` (view, style, render, export) A/DrawsModel.swift:21 ↔ ALFA kennt `Tab` nicht; „Bereich“ in ALFA = `AppEntry`/`AppLanes`; Draws-Bereichsliste `Blob.rows` `draws.area.*` A/Shell.swift:164
- Farbtöne: Draws `Tone` (Hex-Leiter) A/DrawsModel.swift:51 ↔ ALFA `InkSet`, `DesignColors`, `DesignMoods`

## Risiko Masterwechsel
Alle von Draws genutzten ALFA-Namen; Stand main = Stand alfa-draws = DesignTokens.swift ohne Unterschied, alle Namen bestehen heute unverändert auf `origin/main`. Brechen, wenn der Generator (`scripts/tokens_generate.py` aus `TOKENBOGEN.json`) Namen ändert, entfernt oder Werte umdeutet.
Farben (`DesignColors`, Zugriff per KeyPath): ground (A/Shell.swift:26), lane (A/Shell.swift:109, A/Parts.swift:67,87,151,157,325,359, A/Lanes.swift:240,254), line (A/Parts.swift:22, A/Lanes.swift:425), lineStrong (A/Parts.swift:70,89,205,259,280,305,323,361,397, A/ClaudePanel.swift:148), ink (A/Parts.swift:33,69,301, u. a.), inkSecondary (A/Parts.swift:67,248), inkTertiary (A/Shell.swift:126, A/Parts.swift:34,82,98,116,139), well (A/Lanes.swift:161,705, A/ClaudePanel.swift:133,147,171), hover (A/Parts.swift:69,279), inverse (A/Shell.swift:198, A/Parts.swift:252,278), onInverse (A/Shell.swift:139,183,208, A/Parts.swift:248,276), inverseHot (A/Shell.swift:188), inverseLine (A/Shell.swift:177), onInverseLine (A/Parts.swift:89,423), menu (A/Lanes.swift:447, A/ClaudePanel.swift:74), signal (A/Parts.swift:189, A/Lanes.swift:69-84,219,352, A/DrawsModel.swift:74), sheet (A/Lanes.swift:294,363), sheetInk (A/Lanes.swift:349,364, A/DrawsModel.swift:74), sheetInkTertiary (A/Lanes.swift:332), sheetLine (A/Lanes.swift:285, A/DrawsModel.swift:64,70), sheetLineStrong (A/Lanes.swift:286, A/DrawsModel.swift:64,68,70), sheetWell (A/DrawsModel.swift:64,68), handle (A/DrawsModel.swift:64), `DesignColors.light`/`.dark` (A/Style.swift:11, A/Lanes.swift:284, A/DrawsModel.swift:63,68,73). Nicht benutzt in Draws: mark, selection, focus, safeArea, glaze, onSignal, onInverseSecondary/Tertiary, orb*, inverseField
Stimmungen: `DesignMoods.light` coral, apricot (A/DrawsModel.swift:73-74); Master nennt sie „color mood“, Zweck dort offen
Schatten: `DesignShadows.light/.dark` mit lane (A/Shell.swift:111, A/Lanes.swift:241,255), knob (A/Parts.swift:327,362), floating (A/Shell.swift:199, A/Lanes.swift:295,448, A/ClaudePanel.swift:75); `ShadowLayer` mit `inset`, `isContour`, `spread`, `blur`, `x`, `y`, `color` (A/Style.swift:15-19,83-97). Nicht benutzt: segment, overviewHoverLight, `DesignSurface`
Größen (`Design.Size`): edge, gutter, safeAreaTop, blobHeight, blobWidth, foldedWidth, foldThreshold, middleMinimumWidth, laneRestWidth, laneMinimumLeft, blobMenuMinHeight (A/DrawsApp.swift:16 als Vielfache), headerHeight, headGapList/Stack, headPadLeftList/Stack, headPadRight, rowHeight, symbolSize, chipHeight, hairline, handleLength, handleLengthActive, handleThicknessActive, menuRowPadding, menuRowHeight, menuEdge, menuSeparatorInset, blobEyeWidth, blobEyeHeight, blobEyeGap, fieldLabelWidth, footerHeight, toggleKnobOffsetOn/Off, selectionRingWidth, composeTextMinHeight. Stellen: A/Shell.swift:10-214, A/Parts.swift:9-436, A/ClaudePanel.swift:21,70,170, A/DrawsApp.swift:16
Abstände (`Design.Spacing`): step4, step8, step12, step16, step20, step24, step28, step32, statusDot, blobInset (A/Shell.swift:172). Zweckfremd benutzt (Risiko bei Werteänderung): step32 Abschnittshöhe A/Parts.swift:109, step24 Statuskapsel A/Lanes.swift:239, step20 Trenner/Regler A/Lanes.swift:426, A/Parts.swift:365,372, step16 Knopf A/Parts.swift:321,354, statusDot als Griff A/Lanes.swift:359, step4 als Strichlänge A/Lanes.swift:310
Radien (`Design.Radius`): lane (A/Shell.swift:101), blob (A/Shell.swift:167), contextMenu (A/Lanes.swift:436, A/ClaudePanel.swift:11), row (A/Parts.swift:146,205,419, A/Lanes.swift:696, A/ClaudePanel.swift:133,139,171), stroke (A/Shell.swift:125,207, A/Parts.swift:357-358; als Reglerdicke zweckfremd)
Bewegung: `Design.Duration` lane (A/Shell.swift:38, A/DrawsModel.swift:283; zweckfremd als Gleitdauer), hover (A/Shell.swift:107, A/Parts.swift:172,255), short (A/Shell.swift:129), toggle (A/Parts.swift:332), blobWidth (A/Shell.swift:200); `Design.Easing.standard` (A/Style.swift:27, Vorgabe von `Style.ease`). `CubicBezier` aus ShellCore
Schrift: `Design.TextSize` small, body (A/Style.swift:23 und überall), `Design.Weight` regular, medium, `Design.LineHeight.small` (A/Parts.swift:121), `Design.Family.text` (A/Style.swift:38 und Sources/DrawsFonts/Fallback.swift:15,19 (Geist eingebettet, Package.swift:35-36)). Blattschrift: ALFA hat `Typeface.sheet` (Systemschrift, App-Ziel); Draws rendert das Blatt über `DrawingKit.SheetFonts` (Sources/DrawsFonts/Fallback.swift:12-23), nicht über den Master
Nicht im Master und nicht generiert (laut `DesignStamp.state`): confirm.tooltip, surface.lightFillRule, surface.flat, Oberflächennotizen. Draws benutzt keine davon
Wechselrisiken in Reihenfolge der Schwere:
- Tokenname entfällt oder wird umbenannt: Build bricht in Draws (alle Zugriffe per KeyPath/`Design.*`). Kit-Mitführen nötig (Draws steht 94 Commits hinter main)
- Tokenwert ändert sich: Draws folgt automatisch, wo er per Name hängt; zweckfremd geliehene Stellen (siehe Abstände, Radien, Dauer) laufen mit und können falsch aussehen
- Fest verdrahtet, folgt dem Master nicht: alle `Proto`-Visuellwerte (Opacity 0.4, 0.45, 0.6, 0.88; Breiten 300, 340; Höhe 56; Zeilen 4), SF Symbols, `NSColor.white` (A/DocFiles.swift:112), `DesignColors.light` fest (A/Lanes.swift:284, A/DrawsModel.swift:63,68,73), Schriftachse `0x7767_6874` (A/Style.swift:34), Tonleiter `Tone.*` nach Wert (A/DrawsModel.swift:62-76), Fenstergröße 1512 x 982 (A/DrawsApp.swift:19)
- Dark/Light: Blattfarben (`sheet*`, `glaze`) sind in Light und Dark gleich im Stand 1810; Draws zeichnet das Blatt über `DesignColors.light`; bei künftig modusabhängigen Blattwerten bleibt Draws im Light stehen
