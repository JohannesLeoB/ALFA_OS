# Moodboard · Abgleich BR ↔ ED ↔ AR

Maßgeblicher Bogen: `ALFA Moodboard.dc.html`. `ALFA Moodboard v1.dc.html` nur genannt, nicht gelesen, nicht abgeglichen.

## Offene Punkte

Wörtlich aus BR, Abschnitt „Offen für Johannes“:
- „**Alles zur Form:** Formate, Vorlagen, Text, Raster, mehrere Tafeln. Es gibt nur einen Satz in der Spec.“ (07-moodboard.md:51)
- „**Medienkatalog:** Er ist selbst noch nicht gezeichnet; laut Archiv-Spec ist sein Ort offen.“ (07-moodboard.md:52)
- „**Mockup:** Das Moodboard-Mockup aus Johannes' Design-Sitzung ist die Vorlage. Die offenen Punkte oben werden dagegen abgeglichen.“ (07-moodboard.md:53)

Dazu OFFEN in den Funktionen: Formate und Vorlagen (07-moodboard.md:32); Raster, Text, Farbflächen, Beschriftung der Muster (07-moodboard.md:37); Firmenkopf (07-moodboard.md:41); mehrere Tafeln (07-moodboard.md:44).

## Neue Symbole

Quelle: 07-moodboard.md:48. Abgleich mit `INHALT-etappe1.json` › `symbole.pfade` (Z. 650–708) und `Icon.swift` (Z. 3–10).

| Symbol (BR) | INHALT symbole.pfade | Icon.swift | Hinweis |
|---|---|---|---|
| Tafel | fehlt | fehlt | ED eigener Pfad `page` (ALFA Moodboard.dc.html:321), `board` (:206) |
| Bild | fehlt | fehlt | ED eigener Pfad `image` (ALFA Moodboard.dc.html:321) |
| Vorlage | fehlt | fehlt | ED eigener Pfad `tpl` (ALFA Moodboard.dc.html:323) |
| Raster | fehlt | fehlt | Icon hat `grid` (Icon.swift:4, 31); ob als Raster gemeint: unklar. ED eigener Pfad `raster` (ALFA Moodboard.dc.html:200) |
| PDF | fehlt | fehlt | `doc` steht in beiden (INHALT-etappe1.json:691, Icon.swift:55); ob als PDF gemeint: unklar. ED nutzt `export` für „Als PDF sichern“ (ALFA Moodboard.dc.html:736) |

## Bausteine

- BR 07-moodboard.md nennt keinen Baustein aus `App/Components`. Die allgemeine Liste steht in 00-LIES-MICH.md:45-51.
- ED-Teile gleichnamig (kebab → CamelCase) zu einer Datei in `App/Components`: `input-field` → `InputField.swift` (ALFA Moodboard.dc.html:18), `symbol-button` → `SymbolButton.swift` (:69), `segmented-control` → `SegmentedControl.swift` (:66), `text-button` → `TextButton.swift` (:53), `mark` → `Mark.swift` (:46), `counter` → `Counter.swift` (:63), `card-stack` → `CardStack.swift` (:121), `card-header` → `CardHeader.swift` (:124), `anchored-menu` → `AnchoredMenu.swift` (:182).
- ED-Teile ohne gleichnamige Datei: `lane-header` (:17; es gibt `LaneHead.swift`), `list-row` (:45; es gibt `LaneRow.swift`), `list-section-header` (:24), `catalog-tile` (:28), `content-state` (:53; es gibt `ContentPlaceholder.swift`), `lane-content` (:22), `lane-footer` (:55), `compose-button` (:55), `option` (:66), `context-bar` (:72), `choice` (:76), `swatch` (:77), `tool-palette` (:79), `drag-handle` (:79), `divider` (:79), `desk` (:80), `board` (:83), `board-item` (:89), `board-overlay` (:99), `selection` (:103), `command-group` (:117; es gibt `CommandHead.swift`), `card` (:123), `card-content` (:127), `field-row` (:132), `toggle` (:143; es gibt `ToggleSwitch.swift`), `page-thumb` (:156), `card-footer` (:165), `toast` (:173; es gibt `ToastView.swift`), `menu-row` (:186; es gibt `MenuEntry.swift`), `filter-capsule` (:680).
- Ob die ähnlich benannten Paare dasselbe Bauteil sind: unklar, Inhalt von `App/Components` nicht gelesen.
- `card-stack` zeigt nur eine Karte mit Reitern (ALFA Moodboard.dc.html:272-276); BRIEFING_Editoren.md:40 nennt das.

## Zählung

- gezeichnet: 0
- teilweise: 4 (M1, M2, M3, M4)
- fehlt: 0
- erfunden: 17 Einträge (M2: 13, M3: 3, M4: 1); davon in HANDOFF §2 Nr. 1: 0 (dort nur Draws, HANDOFF_Weiterarbeit_2110.md:39)
- AR: M1 und M4 `fehlt` (BR: kein Code, 07-moodboard.md:5); M2 und M3 `ja`.

## Fünf wichtigste Abweichungen

1. **Firmenname fest im Bogen.** BR: „Firmenname und Logo kommen aus der Firmenkonfiguration, nie fest.“ (07-moodboard.md:41). ED: „Studio Brenner“ in Musterseite, Seitenkopf, Formatname und Beispiel-Logos (ALFA Moodboard.dc.html:360, 364, 325, 344).
2. **Quellen fehlen.** BR: Medienkatalog, Bemusterung, Projektordner oder eigene Datei (07-moodboard.md:35). ED: eigene „Bibliothek“ mit Beispielbildern (ALFA Moodboard.dc.html:339-347), nur Datei-Import (:431-437, :55). Katalogfelder (07-moodboard.md:16-18), Ladezustände (07-moodboard.md:20) und Bild-Abgleich (07-moodboard.md:22-26) fehlen.
3. **Ausgabe nur Toast, kein PNG, keine Ablage.** BR: PDF, PNG, Ablage unter Moodboards (07-moodboard.md:40). ED: „Als PDF sichern“ und „Seite als PDF“ nur Toast (ALFA Moodboard.dc.html:736, 741); PNG und Projektordner fehlen.
4. **BR-offene Punkte im Bogen festgelegt.** BR: Formate, Vorlagen, Raster, Text, mehrere Tafeln offen (07-moodboard.md:32, 37, 44, 51). ED: drei Formate (ALFA Moodboard.dc.html:325), vier Vorlagen (:331), 6/12 Spalten (:731), Textrahmen mit Typo (:631-641), mehrere Seiten mit Musterseite (:726-728).
5. **Sperre fehlt.** BR: platziertes Bild mit Sperre (07-moodboard.md:36). ED: Objekt hat kein Sperrfeld (ALFA Moodboard.dc.html:337); das Schloss-Symbol bedeutet „Proportional“ (:602).

## Leseprotokoll

- `br/brief-werkstatt/07-moodboard.md`: ganz, 53 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Moodboard.dc.html`: ganz, 752 Z.
- `ed/ALFA Moodboard v1.dc.html`: nicht gelesen (nur genannt).
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/BRIEFING_Editoren.md`: ganz, 302 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: Z. 645–712 von 1294 (Schlüssel `symbole.pfade` ganz).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/App/Components/*.swift`: nur Dateinamen und Zeilenzahlen, kein Inhalt gelesen.
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen.
- AR `AlfaServices/Airtable/PapersKatalogStore.swift`: ganz, 211 Z.
- AR `AlfaKit/Domain/PapersAssetAbgleich.swift`: ganz, 54 Z.
- AR `AlfaKit/Domain/CheckoutZiel.swift`: ganz, 70 Z.
- AR `AlfaKit/Domain/Skizze/PlatziertesBild.swift`: ganz, 98 Z.
- AR `AlfaKit/Domain/FolderSchema.swift`: Z. 40–56 von 114.
- AR `AlfaKit/Domain/GefuehrterAblauf.swift`: Z. 80–98 von 174.
- AR `AlfaKit/Domain/Konfigurator/KonfigModell.swift`: Z. 300–325 von 455 (QuellenStand mit moodboardStand :310).
- AR `AlfaKit/Domain/InhaltsCheckoutZiel.swift`: nicht gelesen (127 Z.).
- AR `AlfaServices/Google/DriveFolderCategory.swift`: nur grep-Treffer Z. 26.
- In BR 07-moodboard.md:14 genannte Archivdateien gefunden; keine fehlt.
