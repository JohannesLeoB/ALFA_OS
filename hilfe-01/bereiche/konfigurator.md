# Konfigurator · Abgleich Brief, Bogen, Archiv

Einträge je Kennung: `out/konfigurator.json`.

## Offene Punkte

Wörtlich aus BR:
- `05-konfigurator.md:117` „**OFFEN:** Ob Annahmen als solche erkennbar sein sollen. Im Archiv gibt es die Liste „offene Annahmen“.“
- `05-konfigurator.md:130` „**KUNDENSET:** genannt, Inhalt im Archiv nicht ausgeführt.“
- `05-konfigurator.md:141` „**OFFEN:** Aufbau des Blatts ist im Archiv nicht gezeichnet.“
- `05-konfigurator.md:148` „Die Texte der Anfragen sind im Archiv fest formuliert (Anrede, Grußformel). Sie sollten Vorlagen der Firma werden.“
- `05-konfigurator.md:149` „Was ins Kundenset gehört.“
- `05-konfigurator.md:150` „Ob die Kalkulation im Konfigurator rechnet. Die Kalkulation in ALFA ist heute nur über den Assistenten erreichbar.“

Was ED dazu zeigt:
- Zu `:117`: ED zeigt in jeder Regelzeile „belegt“ oder „Annahme“ und eine dritte Art „Entwurfsidee“ (`ALFA Konfigurator.dc.html:513`, `:742`).
- Zu `:150`: Im Bogen steht kein Preis. Quellenstand „Artikelpreise · unbekannt · Katalog fehlt, daher kein Preis“ (`ALFA Konfigurator.dc.html:746`).

## Neue Symbole

BR `05-konfigurator.md:145`: „Zone-Typen, Segment, Fach, 10 Gerätekategorien, Spüle, Müll, Regel-Hinweis und -Warnung, Variante, Anfrage, Stempel.“

Geprüft gegen `INHALT-etappe1.json:650–707` (`symbole.pfade`, 57 Namen) und `Sources/Shell/Model/Icon.swift:4–9` (52 Fälle).

| Symbol | INHALT `symbole.pfade` | Icon.swift | Hinweis |
|---|---|---|---|
| Zone-Typen | fehlt | fehlt | ED färbt Zonen nur mit Punkt (`ALFA Konfigurator.dc.html:41`, `:344`) |
| Segment | fehlt | fehlt | – |
| Fach | fehlt | fehlt | ED-lokale Pfade je Fachtyp (`ALFA Konfigurator.dc.html:341`) |
| 10 Gerätekategorien | fehlt | fehlt | ED ein Pfad `geraet` für alle (`ALFA Konfigurator.dc.html:341`) |
| Spüle | fehlt | fehlt | ED-lokal `spuele` (`ALFA Konfigurator.dc.html:341`) |
| Müll | fehlt | fehlt | ED-lokal `muell` (`ALFA Konfigurator.dc.html:341`) |
| Regel-Hinweis | fehlt | fehlt | ED-lokaler Pfad (`ALFA Konfigurator.dc.html:741`) |
| Regel-Warnung | fehlt | fehlt | `alert` ist vorhanden (`INHALT-etappe1.json:692`, `Icon.swift:56`); ED nutzt eigenen Pfad `warnD` (`ALFA Konfigurator.dc.html:741`). Ob `alert` gemeint ist: unklar, BR nennt keinen Namen |
| Variante | fehlt | fehlt | ED-lokal `cfg` (`ALFA Konfigurator.dc.html:349`) |
| Anfrage | fehlt | fehlt | ED nutzt `export` (`ALFA Konfigurator.dc.html:752`); `export` steht in `Icon.swift:6`, nicht in `INHALT-etappe1.json` `symbole.pfade` |
| Stempel | fehlt | fehlt | ED nutzt `play` (`ALFA Konfigurator.dc.html:757`) |

## Bausteine

- BR `05-konfigurator.md` nennt keinen Baustein aus `App/Components` (Suche nach „Baustein“, „Components“, Bausteinnamen: kein Treffer). Die allgemeine Liste steht in `00-LIES-MICH.md:45–51`.
- ED nutzt diese `data-part` (erste Stelle):
  - Name gleich einer Datei in `App/Components`: `symbol-button` (`:22`, SymbolButton.swift), `segmented-control` (`:61`, SegmentedControl.swift), `text-button` (`:73`, TextButton.swift), `counter` (`:31`, Counter.swift), `mark` (`:29`, Mark.swift), `toast` (`:173`, ToastView.swift), `anchored-menu` (`:182`, AnchoredMenu.swift), `card-stack` (`:118`, CardStack.swift), `card-header` (`:121`, CardHeader.swift).
  - Name ähnlich, Zuordnung unklar: `lane-header` (`:19`) zu LaneHead.swift; `list-row` (`:28`) zu LaneRow.swift; `toggle` (`:140`) zu ToggleSwitch.swift; `command-group` (`:114`) zu CommandHead.swift; `menu-row` (`:186`) zu MenuEntry.swift.
  - Ohne Datei in `App/Components`: `context-bar` (`:68`), `tool-palette` (`:76`), `drag-handle` (`:76`), `tool-flyout` (`:78`), `catalog-tile` (`:80`), `swatch` (`:72`), `choice` (`:62`), `option` (`:61`), `compose-button` (`:50`), `layers-panel` (`:36`), `field-row` (`:129`), `card-content` (`:124`), `card-footer` (`:165`), `list-section-header` (`:26`), `divider` (`:76`), `desk` (`:83`), `world` (`:84`), `sheet` (`:86`), `title-block` (`:87`), `photo` (`:94`), `plan` (`:96`), `status` (`:106`).
- `card-stack` zeigt nur die vordere Karte mit Reitern (`ALFA Konfigurator.dc.html:272–276`).
- `Resources/apps.json` hat keinen Eintrag Konfigurator (`apps.json:1–31`); laut `00-LIES-MICH.md:35` gibt es einen Bereich erst mit diesem Eintrag.

## Zählung

| gezeichnet | teilweise | fehlt | erfunden |
|---|---|---|---|
| 2 (K4, K5) | 5 (K1, K2, K3, K6, K7) | 0 | 19 Einträge |

Kein Eintrag „erfunden“ steht in `HANDOFF_Weiterarbeit_2110.md` Abschnitt 2 Nr. 1 (`:39`); dort ist nur Draws genannt.

## Fünf wichtigste Abweichungen

1. **Kürzel anders.** ED `r b m ws ko l g` (`ALFA Konfigurator.dc.html:342`, Hilfe `:689`) gegen BR `or fa mu wm kf le` (`05-konfigurator.md:89–93`). ED ohne `kg`, `ka`, `3sh`. ED-Breite ohne Angabe für Spüle 800, Müll 450 (`:342`) gegen „Ohne Breite gelten 600 mm“ (`05-konfigurator.md:94`).
2. **Zone ohne Maße und Lage.** ED-Zone hat keine Tiefe, Korpushöhe, Sockel, Höhenbänder, Lage, Drehung, Überstand (`ALFA Konfigurator.dc.html:361`, feste Höhen `:338`) gegen `05-konfigurator.md:34–36` und `:81`.
3. **Anfragen ohne Mailform.** ED baut Stichzeilen ohne Betreff, Anrede, Lieferort, Zeitfenster (`ALFA Konfigurator.dc.html:492–497`); Steinmetz mit erfundener „Stärke 40 mm (Annahme)“ (`:496`). BR: Mailtext „Anfrage Kommission …“ mit diesen Teilen (`05-konfigurator.md:123–128`), Mail-Entwurf öffnen (`:135`).
4. **Material ohne freien Text, Bild und Beschaffungshinweis.** ED: eine feste Liste für alle sechs Zeilen (`ALFA Konfigurator.dc.html:345`, `:739`). BR: freier Text, Palette, Bild, Beschaffungshinweis (`05-konfigurator.md:22`, `:30`, `:99`).
5. **Regeln erweitert und Durchgang als Eingabe.** ED fügt Regeln „Entwurfsidee“ hinzu (`ALFA Konfigurator.dc.html:521–522`, `:529–530`) und rechnet den Inseldurchgang aus einer Zahl (`:526`, `:742`). BR-Tabelle mit 8 Zeilen (`05-konfigurator.md:105–114`); AR rechnet aus Zonenlage (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/Konfigurator/KonfigRegeln.swift:157–166`).

## Leseprotokoll

Gelesen:
- `AUFTRAG-TEIL.md`: ganz, 49 Z.
- `br/brief-werkstatt/05-konfigurator.md`: ganz, 150 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Konfigurator.dc.html`: ganz, 767 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: 129–200 von 302 (dazu Suchtreffer).
- `ed/INHALT-etappe1.json`: 645–712 von 1294 (dazu Suchtreffer für `alert`, `list`, `pen`).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/Resources/apps.json`: ganz, 31 Z.
- `neu/App/Components/`: nur Dateinamen (33 Dateien), kein Inhalt.
- `ar/fundus/alpha/Sources/AlfaKit/Domain/Konfigurator/KonfigModell.swift`: ganz, 455 Z.
- `…/Konfigurator/KonfigRegeln.swift`: ganz, 239 Z.
- `…/Konfigurator/KonfigKuerzel.swift`: ganz, 77 Z.
- `…/Konfigurator/KonfigMaterial.swift`: ganz, 200 Z.
- `…/Konfigurator/KonfigArchetypen.swift`: ganz, 175 Z.
- `…/Konfigurator/KonfigAnfrageText.swift`: ganz, 133 Z.
- `…/Konfigurator/KonfigRenderPrompt.swift`: ganz, 91 Z.

Nicht gelesen oder nicht gefunden:
- `neu/Resources/tokens.json`: nicht gelesen.
- Typen `StilPreset`, `KompilierterPrompt`, `MaterialRef` (genutzt in `KonfigRenderPrompt.swift:4`, `KonfigMaterial.swift:165`): Datei nicht gesucht, nicht gelesen. „fünf Blöcke wie im Atelier“ (`05-konfigurator.md:131`) daher nur gegen `KonfigRenderPrompt.swift:10–16` geprüft.
- `S/zip-ed/`: vorhanden, nicht gelesen (keine Quelle laut Auftrag).
