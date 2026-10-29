# Atelier · Abgleich BR ↔ ED ↔ AR

Maßgeblicher Bogen: `ALFA Atelier.dc.html`. `ALFA Atelier v1.dc.html` nur genannt, nicht gelesen, nicht abgeglichen.

## Offene Punkte

Wörtlich aus BR, Abschnitt „Offen für Johannes“:
- „Ob Atelier gebaut wird. Im Archiv steht dazu die Bemerkung, es sei noch nie real genutzt worden.“ (04-atelier.md:99)
- „Welche Render-Engines angebunden werden.“ (04-atelier.md:100)
- „Ob die Stil-Texte und die Prompt-Vorlage Firmenwerte sind.“ (04-atelier.md:101)

## Neue Symbole

Quelle: 04-atelier.md:96. Abgleich mit `INHALT-etappe1.json` › `symbole.pfade` (Z. 650–708) und `Icon.swift` (Z. 3–10).

| Symbol (BR) | INHALT symbole.pfade | Icon.swift | Hinweis |
|---|---|---|---|
| Polylinie | fehlt | fehlt | ED eigener Pfad `line` (ALFA Atelier.dc.html:213) |
| Rechteck | fehlt | fehlt | ED eigener Pfad `rect` (ALFA Atelier.dc.html:213) |
| Freihand | fehlt | fehlt | INHALT hat `pen` (INHALT-etappe1.json:703); ob als Freihand gemeint: unklar. ED nutzt `pen` für „Stift“ (ALFA Atelier.dc.html:213, 363) |
| Auswahl | fehlt | fehlt | ED eigener Pfad `select` (ALFA Atelier.dc.html:364) |
| Layer-Art Bestand | fehlt | fehlt | ED zeigt Farbpunkt, kein Symbol (ALFA Atelier.dc.html:41, 355) |
| Layer-Art Neu | fehlt | fehlt | wie oben |
| Layer-Art Entfernen | fehlt | fehlt | wie oben |
| Layer-Art Notiz | fehlt | fehlt | wie oben |
| Slot | fehlt | fehlt | ED Kreis-Pfad in der Slotzeile (ALFA Atelier.dc.html:663) |
| Perspektive | fehlt | fehlt | ED eigener Pfad `persp` (ALFA Atelier.dc.html:364) |
| Fluchtpunkt | fehlt | fehlt | ED nur Beschriftung „FP n“ (ALFA Atelier.dc.html:578) |
| Spiegeln | fehlt | fehlt | ED als Textknopf/Schalter (ALFA Atelier.dc.html:604, 655) |
| Ebene vor/zurück | fehlt | fehlt | ED als Textknöpfe „Vor“/„Zurück“ (ALFA Atelier.dc.html:656) |
| Render | fehlt | fehlt | ED eigener Pfad `render` (ALFA Atelier.dc.html:214) |
| Master | fehlt | fehlt | keine Stelle in ED |

## Bausteine

- BR 04-atelier.md nennt keinen Baustein aus `App/Components`. Die allgemeine Liste steht in 00-LIES-MICH.md:45-51.
- ED nutzt `data-part`-Namen. Gleichnamig (kebab → CamelCase) zu einer Datei in `App/Components`: `symbol-button` → `SymbolButton.swift` (ALFA Atelier.dc.html:22), `segmented-control` → `SegmentedControl.swift` (:61), `text-button` → `TextButton.swift` (:73), `mark` → `Mark.swift` (:29), `counter` → `Counter.swift` (:31), `card-stack` → `CardStack.swift` (:127), `card-header` → `CardHeader.swift` (:130), `anchored-menu` → `AnchoredMenu.swift` (:191).
- ED-Teile ohne gleichnamige Datei in `App/Components`: `lane-header` (:19; es gibt `LaneHead.swift`), `list-row` (:28; es gibt `LaneRow.swift`), `list-section-header` (:26), `layers-panel` (:36), `lane-content` (:24), `lane-footer` (:50), `compose-button` (:50), `option` (:61), `choice` (:62), `context-bar` (:68), `swatch` (:72), `tool-palette` (:76), `drag-handle` (:76), `divider` (:76), `tool-flyout` (:78, nie sichtbar, `fly.on: false` :621), `catalog-tile` (:80, :163), `desk` (:83), `world` (:84), `sheet` (:86), `title-block` (:87), `photo` (:94), `plan` (:96), `status` (:115), `command-group` (:123; es gibt `CommandHead.swift`), `card` (:129), `card-content` (:133), `field-row` (:138), `toggle` (:149; es gibt `ToggleSwitch.swift`), `card-footer` (:174), `toast` (:182; es gibt `ToastView.swift`), `menu-row` (:195; es gibt `MenuEntry.swift`).
- Ob die ähnlich benannten Paare dasselbe Bauteil sind: unklar, Inhalt von `App/Components` nicht gelesen.
- Abweichung: Kartenstapel heißt im Bogen `card-stack`, zeigt aber nur eine Karte mit Reitern (ALFA Atelier.dc.html:281-285); laut BRIEFING_Editoren.md:40 „ein Blatt mit Reitern, kein Stapel“.

## Daten ohne Kennung (Abschnitt „Daten“ in BR)

- Skizze „Erstellt und geändert am“ (04-atelier.md:13): fehlt in ED. AR SkizzenModell.swift:166-167.
- Foto „Pixelmaß, EXIF“ (04-atelier.md:17): ED nur fester Text „Foto-Platzhalter · 4032 × 3024 px“ (ALFA Atelier.dc.html:584), EXIF fehlt. AR SkizzenModell.swift:22-36.
- Filter „abgedunkelt (Stärke)“ (04-atelier.md:18): ED Filter ohne Stärke, fest brightness(.62) (ALFA Atelier.dc.html:617, 643). AR abgedunkelt(Double) SkizzenModell.swift:47.
- Foto-Quelle „lokal, Drive oder eingebettet“ (04-atelier.md:16): ED „Hub · Mediathek“, „Projektordner (Drive)“, „Datei wählen …“, „iPhone-Kamera“ (ALFA Atelier.dc.html:631). AR SkizzenModell.swift:3-6.
- Entwürfe „je Projekt die letzten 10“ (04-atelier.md:48): ED ohne Grenze. AR SkizzeEntwurfStore.swift:33-56.

## Zählung

- gezeichnet: 2 (S5, S7)
- teilweise: 5 (S1, S2, S3, S4, S8)
- fehlt: 1 (S6)
- erfunden: 15 Einträge (S1: 9, S2: 3, S8: 3); davon in HANDOFF §2 Nr. 1: 0 (dort nur Draws, HANDOFF_Weiterarbeit_2110.md:39)

## Fünf wichtigste Abweichungen

1. **Maßanker fehlt ganz.** BR: „Strecke ziehen, mm-Wert und Bezeichnung eingeben“ (04-atelier.md:75). ED: kein Werkzeug, Prompt-Geometrie ohne Maß (ALFA Atelier.dc.html:548). AR schreibt Maße in den Prompt (PromptKompilierer.swift:41-43).
2. **Prompt nicht überschreibbar, Wortlaut ersetzt.** BR: jeder Block „von Hand überschreibbar“ (04-atelier.md:84). ED: Blöcke nur als Notizzeilen (ALFA Atelier.dc.html:669); Verbote „Wortlaut im Altcode: unbekannt“ (ALFA Atelier.dc.html:548), obwohl AR ihn hat (PromptVorlagen.swift:10-13).
3. **Perspektivraster starr.** BR: Horizont ziehen, Fluchtpunkte ziehen, Strahlenzahl, Einrasten an/aus (04-atelier.md:63). ED: Horizont fest (ALFA Atelier.dc.html:579), Punkte fest (:434), Strahlen fest (:578), kein Fangschalter (:441).
4. **Einrasten und Verlauf anders.** BR: Winkel auf 7°, Magnet, Winkelanzeige, 500 Schritte (04-atelier.md:56, 46). ED: waagerecht/senkrecht unter 3° (ALFA Atelier.dc.html:440), kein Magnet, keine Gradzahl (:586), Verlauf 100 (:403).
5. **Version unvollständig.** BR: Notiz, Ergebnisbild, „Als Master“, Version aus Version ableiten (04-atelier.md:90, 92). ED: Version ohne Notiz (ALFA Atelier.dc.html:377), Bild nur Toast (:670), Master nur im Status-Menü (:673); Stilname „Innenraum weiches Licht“ statt „Innenarchitektur weiches Licht“ (:360 ↔ 04-atelier.md:85).

## Leseprotokoll

- `br/brief-werkstatt/04-atelier.md`: ganz, 101 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Atelier.dc.html`: ganz, 693 Z.
- `ed/ALFA Atelier v1.dc.html`: nicht gelesen (nur genannt).
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/BRIEFING_Editoren.md`: ganz, 302 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: Z. 645–712 von 1294 (Schlüssel `symbole.pfade` ganz, 57 Einträge per Skript gezählt).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/App/Components/*.swift`: nur Dateinamen und Zeilenzahlen, kein Inhalt gelesen.
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen (für diese Aufgabe nicht gebraucht).
- AR `AlfaKit/Domain/Skizze/`: `SkizzenModell.swift` ganz 213 Z., `SkizzenLayer.swift` ganz 63 Z., `MaterialSlot.swift` ganz 80 Z., `PlatziertesBild.swift` ganz 98 Z., `SkizzenMasse.swift` ganz 38 Z., `PerspektivRaster.swift` ganz 160 Z., `SkizzenGeometrie.swift` ganz 105 Z., `Verlaufsstapel.swift` ganz 54 Z., `PromptKompilierer.swift` ganz 73 Z., `PromptVorlagen.swift` ganz 31 Z., `RenderCheckout.swift` ganz 158 Z.
- AR `AlfaServices/Database/SkizzeEntwurfStore.swift`: ganz, 72 Z.
- AR `AlfaKit/Domain/Konfigurator/KonfigMaterial.swift`: Z. 155–180 von 200; dazu grep nach Beispielnamen.
- Alle in BR 04-atelier.md:6-7 genannten Archivdateien gefunden; keine fehlt.
