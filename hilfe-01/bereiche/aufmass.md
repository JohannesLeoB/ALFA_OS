# Aufmaß · Abgleich Brief, Bogen, Archiv

Maßgeblicher Bogen: `ALFA Aufmass.dc.html`. Nur genannt, nicht abgeglichen: `ALFA Aufmass v1.dc.html`.
Hinweis: `BRIEFING_Editoren.md:106` beschreibt einen Aufmaß-Bogen als „Raummodell aus Wänden, kein Foto-Aufmaß“. Der heutige `ALFA Aufmass.dc.html` ist ein Foto-Aufmaß (`ALFA Aufmass.dc.html:383-394`). Welche Fassung `BRIEFING_Editoren.md:106` meint: unklar (Zeilenangaben dort, z. B. `BRIEFING_Editoren.md:40` „Z. 244–248“, passen nicht zum heutigen Bogen; `stackCards` steht hier in `ALFA Aufmass.dc.html:289-313`).
Kennungen A3.auto und A3.laser sind Teilpunkte von A3 (`03-aufmass.md:62`, `03-aufmass.md:67`). Eintrag „Daten“ deckt `03-aufmass.md:10-46` ab, Eintrag „ohne“ sammelt Bogen-Elemente ohne Funktion im Brief.

## Offene Punkte
- `03-aufmass.md:105`: „Entschieden: Das Aufmaß ist ein Editor im Editoren-Modul … Offen ist, ob es zusätzlich als Widget auf „Heute“ erscheint, wie im Archiv.“ Archivstelle: `archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/GefuehrterAblauf.swift:143-146`.
- `03-aufmass.md:106`: „Inhalt und Aufbau des A3-Blatts. Im Archiv nur genannt.“ Archivstelle: `archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/GefuehrterAblauf.swift:143`. Der Bogen zeichnet ein Schriftfeld (`ALFA Aufmass.dc.html:86-91`).
- `03-aufmass.md:107`: „Abgleich mit dem Mockup aus Johannes' Design-Sitzung.“

## Neue Symbole
Liste `03-aufmass.md:102`: „Lineal/Maß, Kalibrieren, Auto-Maß, Laser, Bluetooth-Status, 11 Installationstypen, Pin, Layer, Fluchtpunkt, Einpassen.“

| Symbol | INHALT-etappe1.json › symbole.pfade | Icon.swift (NEU) | Bogen zeichnet |
|---|---|---|---|
| Lineal/Maß | fehlt | fehlt | `dim` `ALFA Aufmass.dc.html:373`; `ruler` `ALFA Aufmass.dc.html:217` |
| Kalibrieren | fehlt | fehlt | nutzt `ruler` (`ALFA Aufmass.dc.html:371`) |
| Auto-Maß | fehlt | fehlt | `auto` `ALFA Aufmass.dc.html:374` |
| Laser | fehlt | fehlt | `laser` `ALFA Aufmass.dc.html:375` |
| Bluetooth-Status | fehlt | fehlt | fehlt |
| 11 Installationstypen | fehlt (alle 11) | fehlt (alle 11) | `ALFA Aufmass.dc.html:377-379` |
| Pin | vorhanden `INHALT-etappe1.json:694` | vorhanden `Sources/Shell/Model/Icon.swift:29` | eigener Pfad (Ortsmarke) `ALFA Aufmass.dc.html:374`, weicht vom Pin-Pfad in Icon.swift ab |
| Layer | fehlt | fehlt | `layers` `ALFA Aufmass.dc.html:223`, im Bogen nicht verwendet |
| Fluchtpunkt | fehlt | fehlt | `persp` `ALFA Aufmass.dc.html:374` |
| Einpassen | fehlt (nur `expand` `INHALT-etappe1.json:682`) | fehlt (nur `expand` `Sources/Shell/Model/Icon.swift:47`) | kein eigenes Symbol |

Dazu: `plug` ist vorhanden (`INHALT-etappe1.json:687`, `Sources/Shell/Model/Icon.swift:59`); der Bogen zeichnet „plug“ und „anschluss“ mit einem anderen Pfad (`ALFA Aufmass.dc.html:374`, `ALFA Aufmass.dc.html:379`).

## Bausteine
- BR `03-aufmass.md` nennt keinen Baustein aus `App/Components`. Die Liste steht nur in `00-LIES-MICH.md:45-51`.
- Zuordnung nach Namen (Swift-Dateien nicht gelesen, nur Dateinamen):
  - lane-header `ALFA Aufmass.dc.html:19` → `LaneHead`
  - list-row `ALFA Aufmass.dc.html:28` → `LaneRow`
  - counter `ALFA Aufmass.dc.html:31` → `Counter`
  - symbol-button `ALFA Aufmass.dc.html:22` → `SymbolButton`
  - text-button `ALFA Aufmass.dc.html:72` → `TextButton`
  - segmented-control `ALFA Aufmass.dc.html:61` → `SegmentedControl`
  - toggle `ALFA Aufmass.dc.html:157` → `ToggleSwitch`
  - card, card-header `ALFA Aufmass.dc.html:137-138` → `CardStack`, `CardFace`, `CardHeader`
  - toast mit Rückgängig `ALFA Aufmass.dc.html:190` → `ToastView`
  - anchored-menu, menu-row `ALFA Aufmass.dc.html:199-203` → `AnchoredMenu`, `MenuPanel`, `MenuEntry`
  - mark `ALFA Aufmass.dc.html:29` → `Mark`
  - command-group `ALFA Aufmass.dc.html:131` → `CommandHead` (unklar, Name weicht ab)
- Im Bogen ohne Gegenstück in `App/Components`:
  - tool-palette `ALFA Aufmass.dc.html:75`
  - tool-flyout `ALFA Aufmass.dc.html:77`
  - context-bar `ALFA Aufmass.dc.html:68`
  - desk `ALFA Aufmass.dc.html:82`
  - field-row `ALFA Aufmass.dc.html:146`
  - catalog-tile `ALFA Aufmass.dc.html:79`, `ALFA Aufmass.dc.html:171`
  - swatch `ALFA Aufmass.dc.html:154`
  - choice `ALFA Aufmass.dc.html:62`, `ALFA Aufmass.dc.html:73` (Pille; ob `Chip` gemeint ist: unklar)
  - drag-handle `ALFA Aufmass.dc.html:75`
  - layers-panel `ALFA Aufmass.dc.html:36`
  - compose-button `ALFA Aufmass.dc.html:50`
- Das Eingabefeld ist eine Zeile mit `<input>` (`ALFA Aufmass.dc.html:70`, `ALFA Aufmass.dc.html:152`), nicht als `InputField` ausgewiesen.
- `00-LIES-MICH.md:115` verlangt eine gemeinsame Werkzeugleiste und Layerliste für alle Editoren. Der Bogen hat eine eigene Palette (`ALFA Aufmass.dc.html:371`, `ALFA Aufmass.dc.html:645`) und eine eigene Ebenenliste (`ALFA Aufmass.dc.html:36-49`).

## Zählung
Funktionen A1–A8 mit den Teilpunkten A3.auto und A3.laser, dazu „Daten“ (11 Einträge):
- gezeichnet: 1 (A7)
- teilweise: 10 (Daten, A1, A2, A3, A3.auto, A3.laser, A4, A5, A6, A8)
- fehlt: 0
- erfunden: 34 Elemente. Davon 2 auch in `HANDOFF_Weiterarbeit_2110.md:39`, dort aber für Draws: Duplizieren sowie A4- und A2-Formate.

Der Eintrag „ohne“ in der JSON-Datei ist keine Funktion und nicht mitgezählt. Seine 5 erfundenen Elemente sind in den 34 enthalten.

## Fünf wichtigste Abweichungen
1. Layer löschen: Der Bogen verschiebt den Inhalt auf eine andere Ebene und verbietet das Löschen der letzten Ebene (`ALFA Aufmass.dc.html:534`). Der Brief sagt: „Wird ein Layer gelöscht, bleiben seine Maße ohne Layer erhalten.“ (`03-aufmass.md:34`). Das Archiv stimmt mit dem Brief überein (`AufmassModell.swift:210-224`).
2. Nicht kalibriert: Der Bogen legt Maße mit Handwert an und zeigt sie als Zahl (`ALFA Aufmass.dc.html:506`, `ALFA Aufmass.dc.html:392`). Die Referenz bekommt den Vorgabewert 900 mm (`ALFA Aufmass.dc.html:507`). Der Brief sagt „Vor dem Kalibrieren gibt es keine Zahl“ (`03-aufmass.md:19`) und „Dann zeigen die Maße keine Zahl, nur die Linie“ (`03-aufmass.md:55`).
3. Laser: Im Bogen gibt es nur „verbunden“ und „getrennt“, Startzustand verbunden. Der Messwert ist Zufall und wird per Knopf übernommen (`ALFA Aufmass.dc.html:398`, `ALFA Aufmass.dc.html:521`, `ALFA Aufmass.dc.html:710`). Der Brief verlangt die Zustände „sucht“ und „Fehler“, einen Live-Wert und eine Diagnose-Ansicht (`03-aufmass.md:69-72`).
4. Auto-Maß: Der Bogen bildet je Achse höchstens ein Maß aus dem Umrissrechteck und setzt es sofort (`ALFA Aufmass.dc.html:512-516`). Der Brief verlangt bis zu 8 Kanten je Achse, zusammengefasste Kanten und Übernehmen oder Verwerfen je Vorschlag (`03-aufmass.md:64-66`).
5. Einheiten und Quelle: mm und cm werden mit Tausenderpunkt formatiert (`ALFA Aufmass.dc.html:419`), der Brief sagt „ohne Tausenderpunkt“ (`03-aufmass.md:43`). Dazu kommt die Quelle „Foto“ als vierter Wert (`ALFA Aufmass.dc.html:387`, `ALFA Aufmass.dc.html:681`); der Brief kennt nur Hand, Laser und Auto (`03-aufmass.md:24`).

Weitere Abweichungen: In A4 fehlen Horizont, Leitstrahl und die Schalter (`ALFA Aufmass.dc.html:631` gegen `03-aufmass.md:77-80`). In A6 fehlen Schriftgröße und Meter-Summe je Layer (`ALFA Aufmass.dc.html:658` gegen `03-aufmass.md:86`). In A8 fehlen „Ins Projekt ablegen“ und „Entwurf öffnen“ (`ALFA Aufmass.dc.html:707` gegen `03-aufmass.md:98`).

## Leseprotokoll
- `br/brief-werkstatt/03-aufmass.md`: ganz, 107 Z.
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `ed/ALFA Aufmass.dc.html`: ganz, 722 Z. (in vier Abschnitten 1–175, 176–375, 376–554, 555–722)
- `ed/ALFA Aufmass v1.dc.html`: nicht gelesen (nur genannt)
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- `ed/BRIEFING_Editoren.md`: nur Trefferzeilen zu „aufma|survey|laser|disto“ (u. a. 20, 34–35, 40, 46, 51–52, 98–99, 104–127, 135, 140, 170, 207–208, 214, 222, 226, 230–232, 240–258, 300–301) von 302
- `ed/INHALT-etappe1.json`: nur `symbole.pfade`, Z. 645–712 von 1294, dazu Trefferzeilen 104, 254, 415, 455, 717
- `neu/Sources/Shell/Model/Icon.swift`: Fallzeilen 4–9, 13–64, 70–94 von 95 (Treffer auf „case|static“)
- `neu/App/Components/*.swift`: nur Dateinamen (33 Dateien), Inhalt nicht gelesen
- `neu/Resources/tokens.json`, `neu/Resources/apps.json`: nicht gelesen
- Archiv `ar/fundus/alpha/Sources/`:
  - `AlfaKit/Domain/AufmassModell.swift`: ganz, 265 Z.
  - `AlfaKit/Domain/AufmassLayer.swift`: ganz, 201 Z.
  - `AlfaKit/Domain/AufmassAutoBemassung.swift`: ganz, 111 Z.
  - `AlfaKit/Domain/AufmassPerspektive.swift`: ganz, 198 Z.
  - `AlfaKit/Domain/AufmassViewport.swift`: ganz, 65 Z.
  - `AlfaKit/Domain/AufmassDokument.swift`: ganz, 55 Z.
  - `AlfaKit/Domain/AufmassDateiname.swift`: ganz, 55 Z.
  - `AlfaKit/Domain/LaserMeasuring.swift`: ganz, 16 Z.
  - `AlfaKit/Domain/LaserDiagnose.swift`: ganz, 69 Z.
  - `AlfaServices/Aufmass/LeicaDistoBluetoothAdapter.swift`: ganz, 150 Z.
  - `AlfaServices/Aufmass/LaserGeraeteProfil.swift`: ganz, 50 Z.
  - `AlfaServices/Aufmass/LaserDiagnoseScanner.swift`: ganz, 162 Z.
  - `AlfaServices/Database/AufmassEntwurfStore.swift`: ganz, 27 Z.
  - `AlfaKit/Domain/FolderSchema.swift`: Z. 25–45 (Länge nicht ermittelt)
  - `AlfaKit/Domain/GefuehrterAblauf.swift`: Z. 130–155 (Länge nicht ermittelt)
- Nicht gefunden: keine Datei. Im Archiv gibt es keine Stelle für „Übernehmen/Verwerfen je Auto-Vorschlag“, „Löschen mit Rückgängig“ und die Fotoquellen „Datei, Projektordner“; gesucht wurde nur in den oben gelesenen Dateien.
