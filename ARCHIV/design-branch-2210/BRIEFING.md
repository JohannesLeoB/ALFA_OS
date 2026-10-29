# ALFA · Design-Branch · Stand 22.10.2026
Zweck: Explorationen (Icon, Logo, neue Ansichtsbereiche wie Editoren) in einer eigenen Claude-Design-Sitzung, auf dem echten IST-Stand. Nichts davon ist freigegeben oder im Vertrag, bis Johannes es sagt.

## Inhalt
- `ALFA Bereich Vorlage.dc.html`: leerer Ansichtsbereich in der echten Hülle. Drei Bahnen (Bereich, Liste, Offen) nur mit UI-Blöcken: Bahnkopf, Zeilen, Inhaltsblöcke, Kartenstapel mit Kopf und Fuß. Falten, Ziehen, Blob, Abgleich, Personenmarke laufen über ALFA Shell.
- `ALFA Shell.dc.html`, `alfa-shell.js` (Maße und Rechenregeln der Hülle; Eintrag `Vorlage` in AREA nur in diesem Branch), `alfa-theme.css` (alle Farben und Tokens als CSS-Variablen, hell und dunkel), `alfa-bausteine.js` (Symbole, Zeilen, Hinweise, Menüs).
- IST-Bögen zum Nachschlagen, nicht ändern: `ALFA Mail.dc.html`, `ALFA Einstellungen.dc.html`, `ALFA Bestaetigen.dc.html` (Bestätigen-Pille).
- `contract/` (Tokens nach DTCG, components.json, texts.json, views.json), `TOKENBOGEN.json`, `entscheidungen.md` (Johannes' Wortlaut, verbindlich), Schrift Geist (`lieferung-an-code/fonts`), Icons (`material/icons`).
- Nicht enthalten: die Farb-Explorationen vom 22.10. (ALFA Mail Color, ALFA Farbsystematik). Johannes 22.10.: „nicht an Code geben bis ich das deutlich sagen, nicht in TOKENMASTER übernehmen“.

## Regeln (fest)
1. Hülle nur einmal: Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände, Radien kommen aus ALFA Shell und alfa-theme.css. Nicht nachbauen, nicht abwandeln.
2. Werte nur per `var(--…)` aus alfa-theme.css. Eine neue Zahl ist ein neuer Token und steht in der Rückgabe.
3. Belegpflicht: keine Annahme, keine Erfindung ohne Quelle. Quelle ist Johannes' Wortlaut (entscheidungen.md) oder der IST-Stand. Sonst als Frage markieren.
4. Keine Erklär- und Meta-Sätze in der UI (Johannes 21.10.: „Es kommt nichts in die UI was nicht Funktionsbedingt ist“). Fehler und Warnungen sind erlaubt.
5. Keine ZIP und kein Download ohne Johannes' ausdrückliche Freigabe.
6. Jeder neue Bogen trägt den Stempel GESPERRT, bis Johannes ihn gesehen hat (Muster in jedem gesperrten Bogen: Element mit `data-alfa-sperre`).
7. Jede Ansage von Johannes sofort wörtlich mit Datum notieren.

## Neuen Bereich anlegen
1. `ALFA Bereich Vorlage.dc.html` kopieren, Namen geben, Tweak `area` setzen.
2. In `alfa-shell.js` unter AREA einen Eintrag wie `Vorlage` anlegen (Ruhemaß L und R, Minima, Reihenfolge des Nachgebens).
3. Inhalte in `data-slot="0|1|2"`, je Element `data-part` (Bauteilname aus components.json) und `data-id` (`bereich.teil`).
4. Bahnköpfe 44 hoch, Zeilen 36, Symbole 28, Karten oben Radius 20, unten 0.

## Maße (aus alfa-theme.css)
- `--size-edge`: 16px
- `--size-gutter`: 12px
- `--size-headerHeight`: 44px
- `--size-rowHeight`: 36px
- `--size-symbolSize`: 28px
- `--size-blobHeight`: 40px
- `--size-blobWidth`: 56px
- `--size-foldedWidth`: 56px
- `--size-laneRestWidth`: 280px
- `--size-footerHeight`: 44px
- `--radius-lane`: 20px
- `--radius-card`: 20px
- `--radius-row`: 12px
- `--radius-notice`: 8px
- `--radius-field`: 4px
- `--radius-capsule`: 999px
- `--typography-size-small`: 11.5px
- `--typography-size-text`: ?
- `--typography-size-title`: 18px
- `--typography-family-text`: Geist,"SF Pro Text",system-ui
- `--motion-duration-hover`: 160ms
- `--motion-easing-standard`: cubic-bezier(0.2,0.8,0.2,1)

## Farben hell (alfa-theme.css)
`[data-appearance="light"]{color-scheme:light;--c-ground:#ffffff;--c-lane:#ffffff;--c-line:#e8e8e8;--c-line-strong:#d9d9d9;--c-ink:#171717;--c-ink-2:#4d4d4d;--c-ink-3:#6b6b6b;--c-mark:#8a8a8a;--c-well:#f5f5f5;--c-hover:rgba(0,0,0,.05);--c-sel:rgba(0,0,0,.05);--c-focus:#6b6b6b;--c-grip:#a3a3a3;--c-inv:#171717;--c-on-inv:#ffffff;--c-inv-hot:rgba(255,255,255,.12);--c-inv-line:rgba(255,255,255,.2);--c-inv-field:rgba(255,255,255,.08);--c-safe:#000;--c-menu:#ffffff;--c-signal:#b3412e;--c-sheet:#ffffff;--c-sheet-ink:#171717;--c-sheet-ink-2:#4d4d4d;--c-sheet-ink-3:#6b6b6b;--c-sheet-line:#e8e8e8;--c-glaze:rgba(255,255,255,.75);--c-sheet-well:#f5f5f5;--c-sheet-line-strong:#d9d9d9;--c-on-signal:#ffffff;--c-on-inv-2:rgba(255,255,255,.8);--c-on-inv-3:rgba(255,255,255,.6);--c-on-inv-line:rgba(255,255,255,.3);--c-orb:#0d0d0d;--c-orb-rim:rgba(255,255,255,.12);--c-orb-gloss:rgba(255,255,255,.28);--m-coral…`

## Farben dunkel
`[data-appearance="dark"]{color-scheme:dark;--c-ground:#0d0d0d;--c-lane:#141414;--c-line:#2a2a2a;--c-line-strong:#3a3a3a;--c-ink:#fafafa;--c-ink-2:#d9d9d9;--c-ink-3:#a3a3a3;--c-mark:#8a8a8a;--c-well:#1f1f1f;--c-hover:rgba(255,255,255,.08);--c-sel:rgba(255,255,255,.08);--c-focus:#a3a3a3;--c-grip:#6b6b6b;--c-inv:#2e2e2e;--c-on-inv:#fafafa;--c-inv-hot:rgba(255,255,255,.12);--c-inv-line:rgba(255,255,255,.2);--c-inv-field:rgba(255,255,255,.08);--c-safe:#000;--c-menu:#1f1f1f;--c-signal:#e08a74;--c-sheet:#ffffff;--c-sheet-ink:#171717;--c-sheet-ink-2:#4d4d4d;--c-sheet-ink-3:#6b6b6b;--c-sheet-line:#e8e8e8;--c-glaze:rgba(255,255,255,.07);--c-sheet-well:#f5f5f5;--c-sheet-line-strong:#d9d9d9;--c-on-signa…`

## Bauteile im Vertrag (91)
account-alert (AccountAlert), account-mark (AccountMark), account-switch (AccountSwitch), address-button (AddressButton), anchored-menu (AnchoredMenu), area-page (AreaPage), assistant (Assistant), assistant-input (AssistantInput), attachment-chip (AttachmentChip), blob (Blob), blob-face (BlobFace), card (Card), card-content (CardContent), card-footer (CardFooter), card-header (CardHeader), card-notice (CardNotice), card-overview (CardOverview), card-stack (CardStack), chip (Chip), chip-remove (ChipRemove), choice (Choice), command-group (CommandGroup), compose-button (ComposeButton), confirm (Confirm), confirm-no (ConfirmNo), confirm-open (ConfirmOpen), confirm-pill (ConfirmPill), confirm-undo (ConfirmUndo), confirm-yes (ConfirmYes), connection-status (ConnectionStatus), content-state (ContentState), counter (Counter), divider (Divider), field-row (FieldRow), filter-capsule (FilterCapsule), formatting-bar (FormattingBar), handle (Handle), inline-confirm (InlineConfirm), input-field (InputField), lane (Lane), lane-content (LaneContent), lane-footer (LaneFooter), lane-header (LaneHeader), lane-strip (LaneStrip), list-row (ListRow), list-section-header (ListSectionHeader), mail-signature (MailSignature), mark (Mark), menu (Menu), menu-row (MenuRow), message-body (MessageBody), message-header (MessageHeader), message-row (MessageRow), notice (Notice), option (Option), overview-tile (OverviewTile), quote-toggle (QuoteToggle), recipient-field (RecipientField), recipient-input-row (RecipientInputRow), recipient-list (RecipientList), recipient-row (RecipientRow), recipients-disclosure (RecipientsDisclosure), row-actions (RowActions), safe-area (SafeArea), scroll-line (ScrollLine), search-field (SearchField), search-tape (SearchTape), segmented-control (SegmentedControl), service-hero (ServiceHero), settings-tile (SettingsTile), settings-tiles (SettingsTiles), signature-editor (SignatureEditor), suggestion-list (SuggestionList), symbol-button (SymbolButton), sync-button (SyncButton), text-button (TextButton), thinking-orb (ThinkingOrb), tile-grid (TileGrid), tile-group (TileGroup), toast (Toast), toggle (Toggle), lock-screen (LockScreen), lock-error (LockError), image-tile (ImageTile), pdf-page (PdfPage), pdf-header (PdfHeader), pdf-body (PdfBody), pdf-attachments (PdfAttachments), pdf-footer (PdfFooter), drop-overlay (DropOverlay), profile-tile (ProfileTile)

## Rückgabe an die Haupt-Sitzung
- Die .dc.html-Bögen der Exploration.
- Liste: neue Tokens (Name, Wert, Grund), neue Bauteile (`data-part`, Zustände), neue Texte.
- Johannes' Wortlaut zu jeder Entscheidung mit Datum.
- Nichts in contract/ oder TOKENBOGEN.json schreiben.
