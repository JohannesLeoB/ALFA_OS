# Plan und Planvergleich · Abgleich Brief, Bögen, Archiv

Einträge je Kennung: `out/plan.json`.

Zuordnung der Bögen: Planvergleich zu L3, L4, L5. Draws zu L2 und L4. BR `06-plan.md` nennt Draws nicht. Die Verbindung Draws ↔ `PlanProjektion` stammt aus `HANDOFF_Weiterarbeit_2110.md:40` („wahrscheinliche Funktionsgrundlage für Draws“), nicht aus BR. `ALFA Draws v2.dc.html` (418 Z.) ist nur genannt, nicht abgeglichen.

Regel „erfunden“ für Draws: Element steht weder in BR noch in AR noch im Draws-Brief m0067 (`uebergabe-draws-IN-PROGRESS/README.md:17–25`). Jedes Draws-Element aus der Liste „Erfunden“ (`README.md:27–39`) ist aufgenommen. Im Feld `was` steht, ob es in README „Erfunden“ steht.

## Offene Punkte

Wörtlich aus BR:
- `06-plan.md:49` „Welche Formate verglichen werden (PDF, CAD-Export).“
- `06-plan.md:50` „Wie Änderungen gezeigt werden (Überlagerung, nebeneinander, Liste).“
- `06-plan.md:51` „Wohin das Ergebnis geht.“
- `06-plan.md:58` „Plan und Aufmaß sind beide Editoren im Editoren-Modul. Sie teilen Layer-Vorgabe und Farben. Offen ist, ob sie ein Editor mit zwei Modi werden.“
- `06-plan.md:59` „Formate und Ziel des Planvergleichs.“

Was ED dazu zeigt:
- Zu `:50`: Schieber, Überlagern, Änderungen und Fundliste (`ALFA Planvergleich.dc.html:255–258`, `:275–281`).
- Zu `:51`: „Als Excel“, „Als PDF“, nur Toast (`ALFA Planvergleich.dc.html:291–292`).
- Zu `:49`: Kacheln tragen nur „Plan“ (`ALFA Planvergleich.dc.html:269`); Dateiwahl nur Toast (`:271`).

Offene Fragen zu Draws (nicht BR): `uebergabe-draws-IN-PROGRESS/README.md:60–67`.

## Neue Symbole

BR `06-plan.md:55`: „Linie, Polylinie, Rechteck, Text, Bemaßung, Elevation, Isometrie, Achsenfang, Vergleich.“

Geprüft gegen `INHALT-etappe1.json:650–707` (`symbole.pfade`) und `Sources/Shell/Model/Icon.swift:4–9`.

| Symbol | INHALT `symbole.pfade` | Icon.swift | Hinweis |
|---|---|---|---|
| Linie | fehlt | fehlt | ED-lokal `line` (`ALFA Planvergleich.dc.html:142`, `ALFA Konfigurator.dc.html:204`), im Bogen nicht benutzt |
| Polylinie | fehlt | fehlt | – |
| Rechteck | fehlt | fehlt | ED-lokal `rect` (`ALFA Planvergleich.dc.html:142`), im Bogen nicht benutzt |
| Text | fehlt | fehlt | Draws-lokal `text` für Claude-Quelle (`ALFA Draws.dc.html:119`) |
| Bemaßung | fehlt | fehlt | – |
| Elevation | fehlt | fehlt | AR nennt Systemsymbol „square“ (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/PlanProjektion.swift:52`); Draws-lokal `view` (`ALFA Draws.dc.html:120`) |
| Isometrie | fehlt | fehlt | AR „cube“ (`…/PlanProjektion.swift:53`); ED-lokal `cube` (`ALFA Planvergleich.dc.html:144`), Draws `iso` (`ALFA Draws.dc.html:120`) |
| Achsenfang | fehlt | fehlt | – |
| Vergleich | fehlt | fehlt | Planvergleich nutzt `layers` für Fassungen und `board` für Gewerke (`ALFA Planvergleich.dc.html:268`) |

## Bausteine

- BR `06-plan.md` nennt keinen Baustein aus `App/Components` (Suche: kein Treffer). Allgemeine Liste: `00-LIES-MICH.md:45–51`.
- Draws-Brief m0067: „Keine neuen Bausteine, wo es Bahnkopf, Zeile, Segment, Pill oder Schalter schon gibt.“ (`HANDOFF_Weiterarbeit_2110.md:30`).
- Planvergleich, `data-part` (erste Stelle):
  - Name gleich einer Datei: `symbol-button` (`:22`), `segmented-control` (`:48`), `text-button` (`:57`), `counter` (`:32`), `mark` (`:30`), `toast` (`:111`), `anchored-menu` (`:120`).
  - Ähnlich, unklar: `lane-header` (`:19`) zu LaneHead.swift, `list-row` (`:29`) zu LaneRow.swift, `command-group` (`:84`) zu CommandHead.swift, `menu-row` (`:124`) zu MenuEntry.swift.
  - Ohne Datei: `context-bar` (`:54`), `tool-palette` (`:61`), `drag-handle` (`:61`), `catalog-tile` (`:27`), `swatch` (`:59`), `choice` (`:58`), `option` (`:48`), `compose-button` (`:37`), `field-row` (`:92`), `find-marker` (`:73`), `slider-hit` (`:70`), `slider-handle` (`:71`), `desk` (`:62`), `plan` (`:63`), `divider` (`:61`), `lane-footer` (`:37`), `list-section-header` (`:26`).
  - Rechte Bahn ohne Kartenstapel, Reiter direkt im Bahnkopf (`ALFA Planvergleich.dc.html:83`).
- Draws, `data-part` (erste Stelle):
  - Name gleich einer Datei: `symbol-button` (`:21`), `segmented-control` (`:72`), `text-button` (`:56`), `mark` (`:28`), `toast` (`:64`), `anchored-menu` (`:96`).
  - Ähnlich, unklar: `lane-header` (`:18`), `list-row` (`:28`), `toggle` (`:80`) zu ToggleSwitch.swift, `command-group` (`:42`), `menu-row` (`:100`), `text-field` (`:26`) zu InputField.swift, `content-state` (`:56`) zu ContentPlaceholder.swift.
  - Ohne Datei: `slider` (`:81`), `progress` (`:85`), `swatch` (`:82`), `choice` (`:40`), `option` (`:72`), `catalog-tile` (`:59`), `assistant` (`:57`), `handle` (`:53`), `sheet-view` (`:51`), `sheet` (`:45`), `desk` (`:44`), `status` (`:63`), `field-row` (`:26`), `compose-button` (`:31`), `divider` (`:41`).
- `Resources/apps.json` hat keinen Eintrag Plan, Planvergleich oder Draws (`apps.json:1–31`).

## Zählung

| gezeichnet | teilweise | fehlt | erfunden |
|---|---|---|---|
| 2 (L4, L5) | 2 (L2, L3) | 1 (L1) | 29 Einträge |

Davon Draws 22 (L2: 20, L4: 2), davon 14 mit `auch_in_handoff_2110: true`. Planvergleich 7, alle `false`.

## Fünf wichtigste Abweichungen

1. **Kein Plan-Editor gezeichnet.** BR L1 Werkzeuge Linie, Polylinie, Rechteck, Text, Bemaßung und Achsenfang (`06-plan.md:33–35`). Kein Bogen hat sie; Draws hat nur Fanglinien für Ansichten (`ALFA Draws.dc.html:316–323`).
2. **Iso-Winkel frei statt 30°.** Draws: Azimut 45, Elevation 30, Regler 0–355° und 0–90° (`ALFA Draws.dc.html:126`, `:147`, `:464`), dazu „Perspektive“ (`:452`). BR: „Isometrie: 30°“, Umschalter Elevation/Isometrie (`06-plan.md:13`, `:38`); AR `isoWinkel = .pi / 6` (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/PlanProjektion.swift:59`).
3. **Layer anders.** Planvergleich: „Wände und Öffnungen“, „Elektro (ELT)“, „Küche (KUE_01)“, „Beschriftung“, nur Auge (`ALFA Planvergleich.dc.html:285–286`). BR: Gesamtmaße, Wasser/Installation, Details; Farbe, neu, umbenennen (`06-plan.md:16–17`, `:41`).
4. **Planvergleich legt Offenes fest, mit Beispieldaten.** ED: Schieber/Überlagern/Änderungen, Funde mit Grund und Status, Export Excel/PDF, Projekt „Junge/Schultzendorff · 2026_017“ (`ALFA Planvergleich.dc.html:158–179`, `:270`, `:291–292`). BR: Darstellung, Formate und Ziel offen (`06-plan.md:49–51`); kein Archivcode (`06-plan.md:5`).
5. **Einpassen-Rand.** Planvergleich Rand 88 (`ALFA Planvergleich.dc.html:213`). BR „Einpassen mit Rand 48“ (`06-plan.md:26`), AR `rand: Double = 48` (`…/PlanTransform.swift:23`). Draws hält 48 (`ALFA Draws.dc.html:125`).

## Leseprotokoll

Gelesen:
- `AUFTRAG-TEIL.md`: ganz, 49 Z.
- `br/brief-werkstatt/06-plan.md`: ganz, 59 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Planvergleich.dc.html`: ganz, 398 Z.
- `ed/ALFA Draws.dc.html`: ganz, 561 Z.
- `ed/ALFA Draws v2.dc.html`: nur Zeilenzahl (418 Z.), Inhalt nicht gelesen.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: 129–200 von 302 (dazu Suchtreffer).
- `ed/INHALT-etappe1.json`: 645–712 von 1294 (dazu Suchtreffer).
- `neu/Sources/Shell/Model/Icon.swift`: ganz, 95 Z.
- `neu/Resources/apps.json`: ganz, 31 Z.
- `neu/App/Components/`: nur Dateinamen (33 Dateien).
- `ar/fundus/alpha/Sources/AlfaKit/Domain/PlanDokument.swift`: ganz, 108 Z.
- `ar/…/Domain/PlanProjektion.swift`: ganz, 133 Z.
- `ar/…/Domain/PlanTransform.swift`: ganz, 60 Z.

Nicht gelesen oder nicht gefunden:
- `ar/fundus/alpha/Sources/AlfaServices/Google/PlanCollector.swift`: gefunden, nicht gelesen (BR nennt die Datei nicht).
- Aufmaß-Archiv (für „Vorgabe wie im Aufmaß“, `06-plan.md:17`): nicht gelesen, daher unklar.
- `alfa-draws.css`, `draws.tokens.json`, `ERFUNDEN_DRAWS-ABLAEUFE.md`: nicht unter `S/ed/`; vorhanden unter `S/zip-ed/`, nicht gelesen (keine Quelle laut Auftrag).
- `neu/Resources/tokens.json`: nicht gelesen.
