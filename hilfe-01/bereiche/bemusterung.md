# Bemusterung: Abgleich BR ↔ ED ↔ AR

Es gibt keinen Bemusterungs-Bogen in ED. Die Gruppe „Kreativ“ nennt Moodboard, Aufmaß, Atelier, Planvergleich, Konfigurator (ALFA Planvergleich.dc.html:148; gleich ALFA Atelier.dc.html:217). Die sechs maßgeblichen Bögen wurden per Suche auf Muster-, Swatch-, Material-, Status-, Katalog- und Warenkorb-Bezüge geprüft (Leseprotokoll).

## Offene Punkte
- „Ob „Bestellt“ hier gesetzt wird oder aus der Bestellung kommt.“ (02-bemusterung.md:61)
- „Wo die Bemusterung liegt: in der Akte, als eigener Bereich oder beides.“ (02-bemusterung.md:62)
- B4: „OFFEN: Die Wege sind im Archiv nur genannt, nicht gebaut.“ (02-bemusterung.md:54)
- B3: „Der Warenkorb ist selbst noch nicht gezeichnet.“ (02-bemusterung.md:50)
- Bezug: Johannes' Entscheidung 2 zählt die Editoren auf: „Aufmaß, Atelier, Konfigurator, Plan und Planvergleich sowie Moodboard“ (00-LIES-MICH.md:115). Bemusterung steht dort nicht. 00-LIES-MICH.md:74 nennt Bemusterung unter „hängen an einem Projekt“.

## Neue Symbole
BR: „Muster (Swatch), Status-Marken für die 5 Stufen.“ (02-bemusterung.md:58)

| Symbol | INHALT-etappe1.json › symbole.pfade (Z. 650–718) | Icon.swift (NEU) |
|---|---|---|
| Muster (Swatch) | fehlt | fehlt (Fälle `Sources/Shell/Model/Icon.swift:3-9`) |
| Status-Marken (5 Stufen) | fehlt. Vorhanden nur `check` (INHALT-etappe1.json:695), keine Marken je Stufe | fehlt. Vorhanden nur `check` und `tick` (`Sources/Shell/Model/Icon.swift:7`, `:8`), keine Marken je Stufe |

AR nutzt das SF-Symbol „swatchpalette“ (archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/GefuehrterAblauf.swift:78, archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/CheckoutZiel.swift:50).

## Bausteine
- BR 02 nennt keinen Baustein aus `App/Components` namentlich. Es nennt nur „Suchfeld, Trefferliste mit Bild, Mehrfachauswahl, „Zuordnen“; daneben „Manuell anlegen““ (02-bemusterung.md:45) und „Muster entfernen (mit Rückgängig)“ (02-bemusterung.md:34).
- 00-LIES-MICH.md:45-51 listet die Bausteine (u. a. `ToastView` mit Rückgängig, 00-LIES-MICH.md:50). BR 02 verweist nicht darauf.
- ED: kein Bogen, also keine Bausteinwahl für Bemusterung. Alle sechs Bögen haben einen Farbknopf `data-part="swatch"` (z. B. ALFA Atelier.dc.html:72, ALFA Moodboard.dc.html:77, ALFA Konfigurator.dc.html:72, ALFA Planvergleich.dc.html:59, ALFA Draws.dc.html:82, ALFA Aufmass.dc.html:154). Das ist eine Farbwahl, kein Muster der Bemusterung. In `App/Components` gibt es keinen Swatch-Baustein (Suche swatch|palette: kein Treffer).

## Zählung
- gezeichnet: 0
- teilweise: 0
- fehlt: 4 (B1, B2, B3, B4)
- erfunden: 4 Einträge (alle unter B4; 1 davon auch in HANDOFF 2110 und README „Erfunden“)

## Fünf wichtigste Abweichungen
1. Kein Bogen für Bemusterung: ED-Gruppe „Kreativ“ ohne Bemusterung (ALFA Planvergleich.dc.html:148) ↔ BR beschreibt B1–B4 (02-bemusterung.md:29-54). Ort offen (02-bemusterung.md:62).
2. Weitergabe-Ziel: BR „in den Konfigurator (Materialangaben)“ (02-bemusterung.md:53) ↔ AR „Moodboard, Angebot oder Werkplanung“ (archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/GefuehrterAblauf.swift:91-92).
3. Materialquelle im Konfigurator: ED „Die Einträge kommen aus der Moodboard-Palette; Katalogquelle im Altcode: unbekannt.“ (ALFA Konfigurator.dc.html:740) ↔ BR: gewählte Muster gehen in den Konfigurator (02-bemusterung.md:53).
4. „Ohne Kategorie“ zuletzt: BR (02-bemusterung.md:22) ↔ AR sortiert Gruppen alphabetisch, ohne Sonderstellung (archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/Bemusterung.swift:124-127).
5. Rückgängig und Entwurfsname: BR „Muster entfernen (mit Rückgängig)“ (02-bemusterung.md:34) ↔ AR nur `loesche(id:)` (archive/before-rebuild:fundus/alpha/Sources/AlfaServices/Database/BemusterungStore.swift:70-72); BR „einen Entwurfsnamen vergeben“ (02-bemusterung.md:49) ↔ AR nennt keinen Entwurfsnamen (archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/CheckoutZiel.swift:49-51).

## Leseprotokoll
- `br/brief-werkstatt/02-bemusterung.md`: ganz, 62 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/INHALT-etappe1.json`: 640–720 von 1294 (Schlüssel `symbole`, `pfade` Z. 650–718); Schlüsselliste von `symbole.pfade` per Skript ganz (57 Einträge).
- `ed/ALFA Atelier.dc.html` (693 Z.), `ALFA Aufmass.dc.html` (721 Z.), `ALFA Moodboard.dc.html` (752 Z.), `ALFA Konfigurator.dc.html` (767 Z.), `ALFA Planvergleich.dc.html` (398 Z.), `ALFA Draws.dc.html` (561 Z.): nicht ganz gelesen. Alle Zeilen per Skript nach Stichwörtern durchsucht (bemuster, muster, swatch, materia, probe, farbton, sample, vorgeschlagen, gezeigt, gewählt, abgelehnt, bestellt, medienkatalog, papers, EAN, hersteller, warenkorb, checkout, zuordnen, manuell, katalog, mediathek). Einzeln gelesen: Konfigurator Z. 345, 346, 360, 492–500, 565; Atelier Z. 217, 354–361; Planvergleich Z. 148.
- v-Fassungen (`ALFA Atelier v1`, `ALFA Aufmass v1`, `ALFA Moodboard v1`, `ALFA Draws v2`): nur genannt, nicht abgeglichen.
- `ed/BRIEFING_Editoren.md` (302 Z.): nicht gelesen.
- AR ganz gelesen: `AlfaKit/Domain/Bemusterung.swift` (150 Z.), `AlfaServices/Database/BemusterungStore.swift` (95 Z.), `AlfaKit/Domain/CheckoutZiel.swift` (70 Z.), `AlfaKit/Domain/GefuehrterAblauf.swift` (174 Z.).
- AR nur Suchtreffer: `AlfaServices/AssistantLeseWerkzeuge.swift:141-178` (ListBemusterungTool), `AlfaServices/AssistantTool.swift:1652,1680`, `AlfaServices/Database/VolltextSucheStore.swift:28-29`, `AlfaServices/Database/GRDBDatabase.swift:761-762`, `AlfaKit/Domain/VolltextTreffer.swift:12,20,28`, `AlfaKit/Domain/Konfigurator/KonfigMaterial.swift:87-134`.
- AR nicht gelesen: `AlfaKit/Domain/InhaltsCheckoutZiel.swift` (127 Z.; Suche „bemuster“: kein Treffer), `AlfaServices/Airtable/PapersKatalogStore.swift` (211 Z.).
- NEU: `Sources/Shell/Model/Icon.swift`: Z. 3–64 gelesen, 65–95 nur Suchtreffer. `App/Components/*.swift` und `Resources/apps.json`, `Resources/tokens.json`: nur Suche swatch|palette|bemuster|sampling, kein Treffer.
