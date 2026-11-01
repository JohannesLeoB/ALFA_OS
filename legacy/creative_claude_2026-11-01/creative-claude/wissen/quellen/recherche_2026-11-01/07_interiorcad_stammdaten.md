# interiorcad-Stammdaten: Wissen für Beschlag, Material, Kante und Schubkasten

Quelle: CSV-Export der Beschlag- und Materialbibliothek (interiorcad für Vectorworks), Stand 22.07.2026, Bibliotheksversion 2026.3.0, Trennzeichen `;`, Preise entfernt. Pfad: `/mnt/user-data/uploads/creative claude/quellen_interiorcad_2026-07-22/`.

Kennzeichnung: **[aus Stammdaten]** = nur aus den Daten abgeleitet, nicht gegen Herstellerunterlagen geprüft (kein [belegt]). **[Deutung]** = Auslegung eines Feldnamens oder einer Konstanten. Keine Preise, keine Personennamen. Firmen (Händler, Hersteller) sind genannt. Das studio-interne Namenskürzel in Symbolnamen ist als `_<Kürzel>_` geschrieben und wird nicht gedeutet.

Maschinenlesbar: `/tmp/claude-0/-home-claude/052db9ab-e29a-5383-aaf9-1ab3ac8c8f37/scratchpad/recherche/07_schubkasten_regeln.json` (38 Auszugsregeln Holzschubkasten, 27 Regeln Metallzargen, 24 Schienen-Einbauwerte).

---

## 1. Überblick

### Quellenwerte im Feld `source`

| Wert | Bedeutung | Behandlung |
|---|---|---|
| `xg` | vom Hersteller bzw. Lieferanten mitgelieferter Bestand | Basisbestand |
| `custom xg` | herstellerseitig parametrische Einträge (Holzschubkasten, Systemschubkasten) | als Basisbestand gewertet |
| `custom` | Vorlagen des Programms ("Vorlage Holzschubkasten", "Beispiel Symbol", "Beispiel Lieferant") | keine Studio-Entscheidung |
| `user` | vom Studio angelegt | Studio-Wissen |

**Vervielfachung:** Das Studio führt jede eigene Bibliothek viermal (Dateien `… - Eigene`, `… - Original`, `… - Original - Original`, `… - Original - 1`). Die Zeilenzahl der Studio-Einträge ist deshalb ein Vielfaches der eindeutigen Artikel (Beispiel Unterflurauszüge: 96 Zeilen = 4 × 24). In diesem Bericht zählen eindeutige Artikel, wo nicht anders angegeben. Beispielzeilen ("Beispiel Symbol", "Beispiel Lieferant", "Example …") sind Vorlagen und keine Entscheidungen.

### Dateien, Zeilen, Anteil Studio gegen Basis (Zeilen der Datei)

| Gruppe | Datei | Zeilen | xg / Basis | Studio (`user`) |
|---|---|---:|---:|---:|
| Schubkasten | `lib_woodendrawerunderfloorsliders` | 629 | 533 | 96 (= 23 Artikel + 1 Beispiel, 4 Kopien) |
| | `lib_woodendrawerbox` | 157 | 75 (`custom xg`) + 3 (`custom`) | 79 |
| | `lib_drawerprofiles` | 3468 | 3467 | 1 ("Vorlage Zarge") |
| | `lib_systemdrawerbox` | 499 | 499 (`custom xg`) | 0 |
| | `lib_drawersliders` | 448 | 444 | 4 (Beispiel) |
| | `lib_drawerfrontfixings` / `backfixings` | 303 / 250 | 295 / 250 | 8 (Beispiel) / 0 |
| | `lib_drawerlongsiderails` | 1359 | 1359 | 0 |
| Raster | `lib_drillingsgrid` | 64 | 19 | 45 |
| | `lib_sidegrid` | 24 | 3 | 21 |
| | `lib_connectorgrid` | 149 | 65 | 84 |
| | `lib_woodenpingrid` | 113 | 71 | 42 |
| | `lib_screwgrid` | 105 | 67 | 38 |
| | `lib_doorgrid` / `specialconnectorgrid` | 18 / 62 | 6 / 34 | 12 / 28 |
| Verbinder, Füße | `lib_connectorhousings` | 462 | 426 | 36 |
| | `lib_connectorbolts` | 226 | 194 | 32 |
| | `lib_woodenpins` / `screws` | 30 / 84 | 21 / 68 | 9 / 16 |
| | `lib_specialconnectors` | 371 | 363 | 8 (nur Beispiel/Zapfen) |
| | `lib_legfeet` / `legglides` | 319 / 27 | 315 / 23 | 4 / 4 (nur Beispiel) |
| | `lib_legmountingplates` / `legaccessories` | 82 / 64 | 66 / 40 | 16 / 24 |
| Scharniere | `lib_connectorhinges` | 466 | 448 | 18 |
| | `lib_connectordualhinges` | 347 | 337 | 10 |
| | `lib_connectorinsethinges` | 284 | 277 | 7 |
| | `lib_connectormountingplates` / `dual…` / `inset…` | 584 / 569 / 559 | – | 12 / – / – |
| | `lib_rightangledhinge` / `rightangledmountingplates` | 935 / 590 | 900 / 579 | 35 / 11 |
| Material | `mat_boards` | 1618 | 979 | 639 nur im Studio-Bestand (+11 geänderte) |
| | `mat_coverings` | 665 | 533 | 132 |
| | `mat_edgebandings` | 1046 | 860 | 186 |
| | `mat_finishings` | 66 | 43 | 23 |

Weitere Dateien: `lib_version` (2026.3.0), `lib_timestamps` (Vectorworks-2026-Bibliotheksordner, 26.05.2026 und 30.01.2026).

**Gesamteindruck [aus Stammdaten]:** Der Beschlagbestand ist fast vollständig Herstellerbestand. Das Studio-Eigene konzentriert sich auf (a) Holzschubkästen mit Unterflurauszügen, (b) Lochreihen und Verbinderraster, (c) wenige Verbinder, Dübel und Füße, (d) Material, vor allem Plattenwerkstoffe und Kanten.

`lib_rightangledhinge` und `lib_rightangledmountingplates` sind Vereinigungs-/Verkaufssichten über die drei Scharniertypen: alle `techid` stehen auch in den Einzeldateien (`sourcetablename` = connector(dual/inset)hingessales).

---

## 2. Schubkasten-Regeln je Hersteller und Serie

Alle Maße in mm. Gleiche Werte sind zu einer Regel zusammengefasst, die Zeilenzahl nennt den Umfang, Ausnahmen stehen daneben. Vollständig und je Variante in der JSON-Datei.

### 2.1 Holzschubkasten auf Unterflurauszug (`lib_woodendrawerunderfloorsliders`)

Spalten in dieser Reihenfolge: Seitendicke max (`drawersidemaxthickness`), Breitenabzug (`drawerinnerwidthreduction`), Längenabzug (`drawerlengthreduction`), Bodenversatz Seite (`baseboardoffset`), Bodenversatz Boden (`bottomboardoffset`), Nutabstand von Unterkante min–max (`dadodistancefrombottommin/max`), Längenzuschlag (`drawersliderlengthaddition`), Mindestluft oben (`mintopoffset`).

| Hersteller / Serie | Seite max | Breite − | Länge − | Boden Seite / Boden | Nutabstand | Zuschlag | Luft oben | Tragkraft kg | Nennlängen | Zeilen |
|---|---:|---:|---:|---|---|---:|---:|---|---|---:|
| Blum Movento 760H/766H (Blumotion S und Tip-On), Häfele-Handelsform identisch | 16 | 42 | 10 | 28,5 / 38 | 12–15 | 3 | 7 | 40 (760H), 60 (766H), Häfele auch 70 | 250–750, 18 Stufen | 23 je Datei |
| Blum Tandem 550H (Teilauszug) | 16 | 42 | 10 | 24,5 / 34 | 3–13 | 3 | 7 | 30 | 270–650, 9 Stufen | 9 |
| Blum Tandem 550F | 19 | 49 | 10 | 24,5 / 34 | 3–13 | 3 | 7 | 30 | 270–650 | 9 |
| Blum Tandem 560H (Vollauszug) | 16 | 42 | 10 | 27,5 / 37 | 12–15 | 3 | 7 | 30 | 250–600, 14 Stufen | 14 |
| Blum Tandem 560F | 19 | 49 | 10 | 27,5 / 37 | 11–13 | 3 | 7 | 30 | 250–600, 9 Stufen | 9 |
| Grass Dynapro (Soft-close, Tipmatic) | 16 | 42 | 10 | 28 / 38 | 10–13 | 3 | 7 | 40; 50 ab NL 700; 70 (Soft-close) bzw. 60 (Tipmatic) NL 450–650 | 250–750 | 22–23 |
| Grass Dynamoov | 16 | 42 | 10 | 27 (Self-close/Tipmatic: 27/37; Soft-close 28/38) | 10–13 | 3 | 7 | 30 | Soft-close 250–600 (14), Self-close/Tipmatic 270–550 (7) | 7–14 |
| Grass Dynaneo EB 21 (auch "single" = Teilauszug) | 16 | 42 | 10 | 27,5 / 37 | 10–13 | 5 | 7 | 30 | 250–600 (14), single 270–600 (8) | 8–14 |
| Grass Dynaneo EB 24 | 19 | 48 | 10 | 27,5 / 37 | 10–13 | 5 | 7 | 30 | 250–600, 9 Stufen | 9 |
| Hettich Actro 5D | 16 | 42 | 10 | 28,5 / 38 | 12–15 | 3 | 3 | XS 10 (NL 250–350), L 40, XL 70 (NL 450–750) | 250–750 | 23–28 |
| Hettich Quadro 25 (Teilauszug) | 16 | 40 | 0 | 24,5 / 34 | 10–10 (18 Zeilen), 12–13 (9 Zeilen) | 13 | 5 | 25 | 250–550 | 27 |
| Hettich Quadro V6 | 16 | 40 | 0 | 27,5 / 37 | 12–13 | 13 | 5 | 30 | 250–600 | 12–15 |
| Hettich Quadro V6+ | 16 | 40 | 0 | 32,5 / 42 | 12–13 | 13 | 5 | 50 | 350–600 | 11 |
| Häfele TAF 25 (Teilauszug) | 16 | 40 | 0 | 22,5 / 32 | 9–9 | 2 | 5 | 25 | 250–550 | 14 |
| Häfele VAP 30 (Vollauszug) | 16 | 40 | 0 | 28 / 37,5 | 10–10 | 10 | 5 | 30 | 250–700 | 16 |
| Häfele Matrix Runner UM A (Synchro; Lock, Pin, je mit Push-to-open) | 16 | 42 | 0 | 38 / 47,5 | 9–11 | 18 | 6 | 30; 50 bei NL 450–550 | 270–550 | 31 |

**Regeln [aus Stammdaten]:**

1. **Breite und Seitendicke:** Breitenabzug 42 gilt für 16 mm Seiten, 48 (Grass) bzw. 49 (Blum) für 19 mm Seiten; 40 bei Quadro, TAF, VAP. Näherung 42 + 2 × (Seitendicke − 16): Grass trifft 48 genau, Blum Tandem F weicht um 1 ab (49). **[Deutung]:** Der Wert ist der Abzug von der lichten Korpusbreite bis zur Außenbreite des Kastens; das Feld heißt "inner width reduction", die Daten allein klären nicht, ob außen oder innen gemeint ist (Innenbreite des Kastens = Abzug-Ergebnis − 2 × Seitendicke, falls "Außen").
2. **Länge:** Kastenlänge = Nennlänge − 10 bei den Blum-artigen Vollauszügen (Movento, Tandem, Actro, Dynapro, Dynamoov, Dynaneo); Kastenlänge = Nennlänge (Abzug 0) bei Quadro, TAF, VAP, Matrix Runner. **[Deutung]:** Die Reihe mit Abzug 0 hat die Hersteller-Länge als Kastenlänge.
3. **Korpustiefe:** Nennlänge + Zuschlag (3 bei Blum/Grass-Dynapro/Actro, 5 bei Dynaneo, 13 bei Quadro, 18 bei Matrix Runner, 10 bei VAP, 2 bei TAF). **[Deutung]:** Mindesttiefe des Korpusinnenraums über die Nennlänge hinaus.
4. **Bodenlage:** `bottomboardoffset` = `baseboardoffset` + 9,5 bei allen Serien außer Grass Dynapro/Dynamoov (+10). **[Deutung]:** Lage der Bodenoberkante bzw. Bodenunterkante an Seite und Boden gegenüber der Seitenunterkante.
5. **Nutabstand ist Passfenster, nicht Wunschwert:** ein Kasten passt auf eine Serie, wenn sein Abstand Seitenunterkante bis Nut im Bereich min–max liegt. Daraus [aus Stammdaten, Deutung der Felder]:
   - 13 mm passt auf Movento (12–15), Actro, Tandem 560, Dynapro/Dynamoov/Dynaneo (10–13), Quadro V6/V6+ (12–13); nicht auf TAF (9), VAP (10), Quadro 25 in der 10-10-Fassung.
   - 11 mm passt auf Dynapro/Dynaneo/Dynamoov (10–13), Matrix Runner (9–11), Tandem 560F (11–13); nicht auf Movento (min 12), VAP (10–10).
   - 14,5 bis 15 mm (Studio-Eigenbau, siehe Abschnitt 3) passt nur auf die Serien mit Obergrenze 15: Movento, Actro, Tandem 560H; **nicht** auf Grass (max 13) und Quadro (max 13).
6. **Tragkraft:** Standard 30 bis 40 kg, schwere Varianten 50 bis 70 kg bei Nennlängen ab 450. Teilauszug 25 kg (Quadro 25, TAF 25). Die Tragkraft steht nur in der Beschreibung, kein eigenes Feld.
7. **Nennlängen:** Raster 250, 270, 300, 320, 350, 380, 400, 420, 450, 480, 500, 520, 550, 600 (14 Stufen Blum/Grass); lange Varianten 650/700/750. Häfele-Handelsformen enthalten dieselben Parameter wie die Hersteller-Dateien (nur andere Artikelnummern: 433.33.xxx Movento Blumotion S, 433.24.xxx Tip-On).

Artikelmuster: Blum `760H{NL×10}S` (Blumotion S) bzw. `…T` (Tip-On), `766H…`; Häfele laufende Nummern; Grass `F1371411xx`.

### 2.2 Metall-Schubkastensysteme (`lib_drawerprofiles`, 3468 Zeilen, 145 Serien-Dateien)

Spalten: Rückwandbreite-Abzug (`backwidthreduction`), Bodenbreite-Abzug (`drawerprofilebottomboardwidthoffset`), Mindestabstand Boden (`minimumbottomoffset`), durchgehender Boden (`drawerprofilecontinuousbase`), Längendifferenz Profil minus Boden (`drawerprofilelength − drawerprofilebottomboardlength`). Rückwand- und Bodendicke Standard überall 16 mm (Ausnahme: 24 Zeilen AvanTech YOU mit Boden 8 mm).

| Hersteller / Serie | Rückwand − | Boden Breite − | Boden Länge − | min. Bodenabstand | durchg. Boden | Zeilen | Profilhöhen (Auswahl) |
|---|---:|---:|---:|---:|:-:|---:|---|
| Blum Legrabox (auch Häfele-Handel pure/free) | 38 | 35 | 10 | 24,4 (Häfele pure 23,4) | 1 | 164 + 398 + 28 | 42, 68, 106, 155, 219 |
| Blum / Häfele Merivobox | 51 | 51 | 26 | 20 | 0 | 105 + 189 | 31,5; 54; 92; 155 (Rückwand − Profil = 29) |
| Blum / Häfele Tandembox | 87 | 75 | 24 | 9 oder 12 | 0 | 116 + 132 | 49,5; 65,5; 97,5 … 191; NL 270–650 (9 Stufen) |
| Grass Nova Pro Scala / One, Häfele, Würth | 58 | 58 | 19 | 9,5 | 0 | 232 + 39 + 222 + 276 | 23 bis 218 |
| Grass / Würth Vionaro V8 | 42 | 21 | 11 | 28,5 | 1 | 93 + 174 | 47 bis 233 |
| Grass / Würth Vionaro V13 | 32 | 22 | 27 | 29,5 | 0 | 137 + 130 | 56 bis 234 |
| Hettich ArciTech | 88 | 76,5 | 24,5 | 8 | 0 | 243 | 27,5 bis 231,5 |
| Hettich AvanTech (System) | 20,5 | 24 | 26 | 28,5 | 0 | 36 | 47,5 bis 198 |
| Hettich AvanTech YOU | 24 | 24 | 21 (Boden 16) / 26 (Boden 8) | 28,5 | 1 / 0 | 240 + 24 | 64 bis 214 |
| Hettich InnoTech Atira | 82 | 70,5 | −10 (Boden länger als Profil) | 8,5 / 11,5 / 16,5 | 1 | 24 | 45, 61 |
| Häfele Matrix Box P Plus | 62 | 62 | 3 | 10 | 1 | 312 | 32 bis 160 |
| Häfele Matrix Box Slim A | 42 | 21 | 10 | 38 | 1 | 153 | 75,5 bis 160,5 |
| Hettich "Vorlage Zarge" (Studio, `user`) | 88 | 76,5 | 24,5 | 8 | 0 | 1 | 41,5 |

**Regeln [aus Stammdaten]:** Boden-Länge = Nennlänge − Längendifferenz, Boden-Breite = lichte Breite − Bodenbreite-Abzug, Rückwandbreite = lichte Breite − Rückwand-Abzug. Die Werte Legrabox 38/35/NL−10, Merivobox 51/51/NL−26, Tandembox 87/75/NL−24 stimmen mit den bekannten Maßen dieser Systeme überein (Wiedererkennung, [Deutung]); alles Weitere ist Auslesung. Die Studio-Zeile "Vorlage Zarge" trägt dieselben Zahlen wie ArciTech: kein eigenes System.

**Schienen-Einbauhöhe (`lib_drawersliders`):** Höhe der Seitenschiene über der Zargenunterkante (`drawersliderbottomsoffset`) und Längenzuschlag (`drawersliderlengthaddition`): Legrabox 38–39 / 3; Merivobox 54 / 3; Tandembox 33 (BM) bzw. 36 (TO/TOB) / 3; Nova Pro Scala und One 52 / 3; Vionaro 37 / 3; ArciTech 52,5 / 3 (8 Zeilen 26); AvanTech 54,5 / 3; AvanTech YOU 38 / 3; InnoTech Atira Quadro 25: 34, V6: 37, V6+: 42, jeweils / 15; Matrix Box P Plus 53 / 3; Slim A 47,5 / 20. Die Zuordnung 34/37/42 zu Quadro 25/V6/V6+ ist aus Nennlängen und Pfaden gelesen [Deutung].

**`lib_systemdrawerbox` (499 Zeilen, 55 Bibliotheksdateien, `custom xg`):** Montagesätze, die Zarge, Rück- und Frontbefestigung und Längsschiene zu einem Kasten verbinden. Material: 491 Zeilen Rückwand und Boden beide KF-weiß 16 mm, 4 Zeilen beide 8 mm, 4 Zeilen Rückwand 16 und Boden 8. Kantenaufbau wechselt (1 bzw. 2 mm Kante an der Rückwand oben; Bodenfront-Kante 2 bzw. 10). Serienhöhen aus Beschreibungen: Legrabox N 66,5, M 90,5, K 128,5, C 177, F 241; Merivobox E 192 (91 + Boxcap/Reling).
**`lib_drawerbackfixings`:** tragen Rückwandhöhen (Legrabox 39/63/101/148/212, Merivo 60,5/83/121/184, Tandembox 69/84/116/135/167/199) und die Lage der Längsreling als JSON (x/y/z, bei Legrabox leer).

### 2.3 Holzschubkasten-Vorlagen des Herstellers (`lib_woodendrawerbox`, `custom xg`, 75 Zeilen)

Fünf Bibliotheken × 15 Höhen: Weiß beschichtet 19, Weiß 16, Eiche 13 (Nutabstand 13 und 11), Buche 13. **Einheitlich:** Tiefe 500, Seitenhöhen 75 bis 355 in Schritten von 20, Hinter- und Frontwandhöhe = Seitenhöhe − 23, Nut 5,5 tief / Abstand 13 (11 in einer Bibliothek) / Spiel 1 / Breite 8,5, Boden 8 mm (Weiß ohne Maserung, Eiche/Buche längs), Nut nur in den Seiten (Hinter- und Frontwand ohne Nut), Ecken durchgehend, Frontart "drawerfront".
Vorlagen ("custom"): "Vorlage Holzschubkasten" (Seite 13, Boden 8, Tiefe 500, Höhe 135, Hinterwand 112, Nut 5,5/13/1/8,5, Buche) und "Beispiel Symbol-2" (Seite 13, Boden 5, Nut 6/12/0/5, in allen Wänden genutet, Ahorn).

---

## 3. Konstruktionsentscheidungen des Studios (`source` = user)

### 3.1 Holzschubkästen (79 Zeilen in `lib_woodendrawerbox`)

**A. Zugekaufter Kasten, vierseitig gezinkt (59 Zeilen in zwei Dateien: 31 und 28)**
- Lieferant Häfele (Serie SE53), als Zukaufteil geführt (`isboughtin` = 1), keine Artikelnummern eingetragen, Tiefe 516.
- Seite 13, Boden 8, Nut 6 tief / Abstand 13 / Spiel 0 / Breite 8. Die Nutbreite entspricht der Bodendicke (kein Spiel).
- Hinterwandhöhe = Seitenhöhe − 23. Zwei Bauformen je Höhe: **außen** (Front = Hinterwandhöhe) und **innen/Einlage** (Front = Seitenhöhe, Fronteinlage mit Überlappung 1).
- Höhen 55, 70, 85, 100, 115, 130, 160, 190, 220, 250, 280, 310, 340, 370, 400 (15 Stufen), außen und innen.
- Material: Massivholz Eiche 13 (Studio-Eigenbezeichnung "wild hell"), Boden Spanplatte 8.
- Auffälligkeit: Zeile H55 hat Frontwandhöhe 34, zwei Millimeter Abweichung gegen das Muster; "In_H55" und "In_H55_tablar" sind tatsächlich 70 hoch [Deutung: Datenfehler oder Sonderfall].

**B. Eigenbau Multiplex Eiche (20 Zeilen, Familie "01–05")**
- Seite, Hinter- und Frontwand Multiplex Eiche 15, Boden Spanplatte furniert 9.
- Fünf Höhen: 80, 115, 160, 220, 280; je außen und innen.
- Nut 6 tief; Abstand 14,5 (Familie 01) bzw. 15 (übrige); Spiel 0,5; Breite 9,5 bzw. 9,25.
- Hinterwandhöhe = Seitenhöhe − 26; Tiefe 516.
- Die Innen-Varianten haben Front = Seitenhöhe; teils ohne Textur/Maserung.

**Ableitungen [aus Stammdaten]:**
- Seitendicke 13 (Massiv) und 15 (Multiplex), Boden 8 bis 9, Nuttiefe 6 sind die Studio-Normen. Keine 16- oder 19-mm-Seiten im Eigenbestand (der Hersteller liefert 19 und 16 als Beschichtet-Variante).
- Hinterwandhöhe lässt sich ausdrücken als Seitenhöhe − (Nutabstand + Bodendicke + 2): 13 + 8 + 2 = 23 (A und Hersteller), 15 + 9 + 2 = 26 (B). Für die Hersteller-Familie mit Nutabstand 11 ergäbe die Formel 21, der Bestand führt 23 (Formel gilt nicht überall).
- Nutbreite = Bodendicke + 0 (A) bzw. + 0,25 / + 0,5 (B), Hersteller + 0,5.
- Das Studio nutet nur die Seiten, Hinterwand sitzt über dem Boden (aus Hersteller-Vorlage; Studio A/B kennzeichnen Nut in den Seiten, Hinterwand/Front ohne Nut) [Deutung].
- Passung auf Auszug: Studio A (Nutabstand 13) passt auf Movento, Actro, Tandem, Dynapro, Quadro V6. Studio B (14,5/15) passt nur auf Movento, Actro, Tandem 560H, weil nur dort die Obergrenze 15 erreicht wird. Das ist ein Hinweis auf die Auszugsserie, für die B gedacht ist: Movento passt zur Bestandsführung (alle eigenen Unterflurauszüge sind Movento).

### 3.2 Unterflurauszüge (`lib_woodendrawerunderfloorsliders`, 23 eindeutige Artikel, 4 Kopien)
Ausschließlich Blum Movento über Häfele-Artikelnummern: 433.33.110 bis 124 (40 kg, NL 250–600), 433.33.338 bis 345 (70 kg, NL 450–650), 433.33.326/327 (60 kg, NL 700/750), dazu ein Blum-Eintrag 760H4000B mit der Beschreibung "Mehrere Komponenten". Alle Werte identisch zum Basisbestand (28,5/38/15–12/42/10/16/3/7). Die Symbolnamen unterscheiden sich zwischen den Kopien (`_<Kürzel>_Movento_S_250_40kg` und `…_250`), die Artikelnummern nicht.
**Entscheidung [aus Stammdaten]:** Das Studio verwendet einen einzigen Auszug (Movento) für alle Holzschubkästen.

### 3.3 Weitere eigene Beschläge
- **Füße:** Häfele AXILO 78, sieben Höhen 60 bis 200 (Artikel 637.76.351 bis 357), Montageplatten "Anschrauben" (637.763.33) und "Einpressen" (637.76.334) und eine Würth-Montageplatte. Eigenbestand ist nur AXILO.
- **Verbinder:** Würth SV20 (Verbinder, Varianten bündig, Durchgangsbohrung), Würth FB20 Gehäuse (schwarz, silber), Scheulenburg PV-10 (schwarz, silber) mit PV-24 (Holz, Muffe, Platte-Platte).
- **Dübel:** Buchenholzdübel von Kappes 5×20, 8×20, 8×25, 8×30, 10×40 (Beschreibung sagt 8×40), 12×40; Ixconnect (Hibertz) 8×30.
- **Schrauben:** Würth Korpusschrauben 50 mm und 70 mm, Würth Schubkastenfront-Schraube.
- **Scharniere:** Blum ClipTop 110° (Häfele-Artikel Eckanschlag 342.42.660/666, Mittelanschlag 342.42.661/667, Innenanschlag 342.42.662/668), 155° und 170° Varianten, Grass Tiomos 110°; Montageplatten Blum ClipTop 0/3 mm in Kreuz-, Linear-, Eurobefestigung, auch schwarz. Der Überlappungsbezug Innenanschlag ist bei Studio 0, beim Hersteller −3.
- **Hinweis zur Lesart:** Die Studio-Sammlung ist klein und vollständig eigenständig gewählt: Häfele als Hauptlieferant für Auszug, Fuß und Scharnier, Würth und Scheulenburg für Verbinder.

---

## 4. Lochreihen und Raster

### 4.1 Raster-Kurzschrift (aus Herstellersymbolen belegt [aus Stammdaten])
Beispielnamen: `050 | # 32 | 050 <> 37 | # 700 | 37`, `DYN 37 | MAX150 | 37`.

| Zeichen | Bedeutung |
|---|---|
| `37mm` | Abstand vom Anfangsrand |
| `-37mm` | Abstand vom Endrand |
| `!` | fest (nicht verteilt) |
| `(32mm)` | Rasterabstand (Teilung) |
| `#` | gleichmäßig verteiltes Element |
| `#(>700)` | zusätzliches Element, sobald das Maß größer als 700 ist |
| `#(32mm*3)` | n Elemente im Rasterabstand 32 |

**Schwelle:** `#(>x)` entspricht Anfang + Ende + MAXABSTAND (37 + 37 + 150 = 224, 37 + 37 + 400 = 474); Herstellerraster `DYN 37 | MAX400` hat Schwellen 474, 874, 1274 …. Das Suffix `N` ist nicht geklärt.

### 4.2 Lochreihen (`lib_drillingsgrid`, 19 Basis, 45 Studio)
**Studio:**
- Standard "37_37": X (Höhe) `147(32mm);-128mm`, Y (Tiefe) `37mm;-37mm`. 147 = 128 + 19: erstes Loch 147 über der Seitenunterkante, also 128 Abstand vom Boden zuzüglich 19 mm Bodenstärke; Teilung 32; Ende 128. Mittelseite ("MS") `128(32mm);-128mm!`.
- Y mit mittlerem Loch ab Tiefe 700: `37mm;#(>700);-37mm`. Hinten verschoben um die Rückwanddicke t: `-37mm-(t+2)` (RW 8 → 10, RW 10 → 12, RW 12 → 14, RW 19 → 21), genutete Rückwand: −23, −25, −27.
- 64-mm-Teilung, 3er und 5er Lochreihe `#(32*3)` / `#(32*5)` mit `37mm;#(>580mm);-37mm`; Sonderraster "Oberschrank 15 Nutwange" (−60), "RW 12 Nutwange" (−57), "32_mit_quattro"; ein späterer Satz mit X-Anfang 192 bzw. 224.
**Hersteller:** X-Anfang 50, 80, 100, 150, Teilung 32 oder 50; Y vorn 37, hinten 37, 52, 57, 67, mittleres Loch ab 700.

**Wissensregel [aus Stammdaten]:** Studio arbeitet im 32-mm-System mit Vorderkante 37 und Rückkante 37 (+ Rückwanddicke + 2); bei Tiefe über 700 kommt ein mittleres Loch hinzu.

### 4.3 Seitenraster (`lib_sidegrid`)
Studio X-Anfang 32, 48, 67, 84, Teilung 32. Hersteller "Kreuzplatte 150" (70/32), "Linearplatte 150" (86/−80/32), "Linearplatte 50" (50/50).

### 4.4 Verbinderraster (`lib_connectorgrid`, 65 Basis, 84 Studio)
Studio-Standard: `37mm;#(>475);#(>800);#(>1200);#(>1600);#(>2000);-37mm`, Y `9,5;-9,5` (Mitte einer 19-mm-Platte): zwei Verbinder bis 475, je einer mehr ab 475, 800, 1200, 1600, 2000. Boden-Varianten `27–37mm;-37mm`; Varianten 100_100, _30_30; RW-Varianten 37 … −47/−51/−58. Hersteller: `DYN 37 | MAX400`, FIX n (30/37/50), Clamex (80, ab 500/1000/1500).

### 4.5 Dübelraster (`lib_woodenpingrid`, 71 Basis, 42 Studio)
Studio: `80;-80`, `40;-80`, 4-Dübel `80;#;#;-80`, 5-Dübel `45;#;#;-45`, Schubkasten `20;#(>100mm);-20`, Clamex `45 45+101 …`, Divario; RW-Varianten analog zum Verbinderraster.

### 4.6 Schraubenraster (`lib_screwgrid`, 67 Basis, 38 Studio)
Studio: `45;#(>400);#(>650);#(>900);#(>1200);#(>1600);#(>1900);#(>2100);-45`, Varianten 35/55/80/100/60; Schubkasten `45;#(>600);-45` mit Y `30;-20`; Häfele-Schubkasten `22;#(>600);(>1000);-22`.

### 4.7 Türraster (`lib_doorgrid`) und Sonderverbinder (`lib_specialconnectorgrid`)
Tür Studio: `96mm;#(>900);#(>1500);#(>2200);-96mm`, also 2 Scharniere, ab 900 drei, ab 1500 vier, ab 2200 fünf; "Band_96_VU" `96mm;#(>1500)(32)…`. Blum Hersteller: `80mm;#(>800);#(>1500);#(>2100);#(>2100);#(>2500);-80mm`; dynamisch 50/80/100 mit Schwellen 1200 bis 4500.
Sonderverbinder: Cabineo `50;>400/700/1000`, Invis `20;>400/800/1200`, Arbeitsplattenverbinder 100, P-System/Festool 60.

---

## 5. Korpusverbinder und Füße

### 5.1 Verbinder
- **Gehäuse (`lib_connectorhousings`, 462):** Lamello 177, Häfele 162, Hettich 68, Würth 41, Scheulenburg 8. Serien nach Anzahl: Cabineo 8 / 8 M6 / 12 / X je 42, Rafix 20 (41), Minifix (32), Rastex 15 (30), VB 35/36/135 (26), Häfele Cabineo 8/12 je 21, Studio SV2 (16), SV 20 (12), Ixconnect (~25), ClamexZeta (9), FB20 (8), PV-Verbinder (8), Exzenter 15 (5), Onefix (5).
- **Bolzen (`lib_connectorbolts`, 226):** Minifix 62, Rafix 20 28, weitere.
- **Dübel (`lib_woodenpins`, 30):** Basis 21 (Lieferant "Lager"), Studio 9 (Buche, Kappes; Ixconnect 8×30).
- **Schrauben (`lib_screws`, 84):** Studio Würth Korpusschrauben 50/70 mm, Schubkastenfront-Schraube.
- **Sonderverbinder (`lib_specialconnectors`, 371):** Basis 363, Studio nur Beispiel- und Zapfenzeilen (Bodenträger-Zapfen).

### 5.2 Füße (`lib_legfeet` 319, `lib_legmountingplates` 82, `lib_legaccessories` 64, `lib_legglides` 27)
Verstellbereiche [aus Stammdaten] (Einbauhöhe, min–max):
- Häfele AXILO 78: 60 (53–70), 80 (70–100), 100 (90–120), 125 (115–145), 150 (140–170), 180 (170–200), 200 (190–220); Artikel 637.76.351 bis 357. AXILO 48: 100 (92–120), 120 (105–140), 150 (135–170), 180 (165–200).
- Häfele SW8 Sockelversteller: 60 (50–78), 80 (70–98), 100 (90–118), 125 (110–138), 150 (140–168), 200 (190–218); zum Einschrauben (637.80.31x) und Einpressen (637.80.32x).
- Kunststoffversteller 80/100/120/150 (Verstellung +15); Würth Typ B/C/EV (45–200, Bereich etwa +20 bis +28); Hettich Korrekt 50–205, Euro 95–193; Verstellschrauben M8/M10.
- Rollen (HAEFELE-ROLLS, 99 Einträge, 36–235) und feste Möbelfüße (HAEFELE-FUR-LEGS, 111, 50–720, nicht verstellbar); x/y-Versatz 12,5 bis 100.
- **Regel [Deutung]:** Verstellbereich je Fuß ≈ ±10 bis ±15 um die Einbauhöhe (Mitte = Einbauhöhe + 2 bis 5), Bereich bei AXILO 78 jeweils 17 bis 30 mm breit. `legmountingplates.heightaddition` meist 0; `legaccessories`: `needsplinth` 1, `plinthreduction` 0 bis 8 [Deutung: Sockelblende wird um 0–8 mm reduziert].

---

## 6. Scharniere (kurz)

Überlappungstypen: **Eckanschlag** (Vollüberlage), **Mittelanschlag** (Halbüberlage), **Innenanschlag** (eingeschlagen). Angabe: Topfabstand (Kante bis Bohrungsrand) / Überlappungswert, Topfabstand min–max.

| Hersteller / Serie | Eck | Mittel | Innen | Besonderheiten |
|---|---|---|---|---|
| Blum ClipTop (NI/ONS) | 4/15, 3/16, 3/14, Topf 3–7 (8) | 3–4 / 4,5–5,5 | 4 / −3 | Sonder 26/4 (Topf 23,5–46), 18/14,5 (0–22,5) |
| Grass Tiomos | 7/21, 7/24, 8/22, 8/25 (min 3, max 7/8, Platte −2) | 7 / 14,5 | 7/0 oder 3/−1 | |
| Hettich Intermat | 6/16, 8/16, 11/16 | | | |
| Hettich Sensys | 4,5 / 12–13 | 2–4 | −1 | |
| Häfele Duomatic | 6/18 | 6/9 | 6/−2 | Sonder 15/13, 18/14 |
| Selekta Pro, MB, Aximat | Platzhalterwerte −5 | | | |

Studio-Eigenes: Blum ClipTop 110/155/170° (Häfele-Artikel), Grass Tiomos 110° (Eck 7/17, Mittel 7/12,5, Innen 6/1). Studio führt Innenanschlag mit Überlappung 0, Hersteller −3.

---

## 7. Material und Kanten

### 7.1 Plattenwerkstoffe (`mat_boards`, 1618)
**Händler im Basisbestand (xg, 979):** ZEG Mannheim 456 (Furnier-, Massiv-, Sonder- und MDF-/FPY-Platten), Holz Hahn Krefeld 395 (Egger-Dekorspanplatten), Holz Roeren Krefeld 123 (Thermopal-Dekorspanplatten). **Händler nur im Studio-Bestand (639):** Behrens Rotenburg 440, Andresen & Jochimsen Hamburg 62, HOFA Holzimport Stapelfeld 35, Roggemann Ellerbek 32, Klöpfer Holz HH 9, Ostermann Bocholt 4, KULA Ottersberg 3, Kappes Hamburg 2, Stadler 2, HolzTEC Werl 1, Frerich Glas Lüneburg 1, Ulrich Furniere Hamburg 1; 44 ohne Händler. Zudem 11 Zeilen, in denen das Studio den Basis-Händler (ZEG) durch Behrens ersetzt und Lieferantennummer/Maßtext ergänzt hat (MDF-Platten).
**Typen und Dicken nach Basis [aus Stammdaten]:**

| Typ | n (Basis) | Dicken (häufigste, mm) |
|---|---:|---|
| Melamin (Dekorspanplatte) | 546 | 19 (243), 8 (214), 25 (47), 16 (10), 10/22/28 (je 7) |
| Furnier | 205 | 5 (27), 8 (25), 19 (22), 16 (18), 13/22/25 (je 14), 4/6 (je 12) |
| Sonder (custom) | 99 | 19 (15), 16 (13), 22 (10), 25 (8), 28 (7) |
| Massivholz | 68 | 0 = Volumenware (m³) mit Bohlenstärke in `default_thickness` (z. B. 50 bis 90), daneben 19 und 22 |
| gw (Schichtstoff-/Glatt-Variante, unklar) | 49 | 25, 19, 8, 13, 22 |
| 3-Schicht | 12 | 19 (9), 25 (3) |

**Standarddicken [aus Stammdaten]:** 19 (Korpus), 8 (Rückwand, Schubkastenboden), 25 (Fachboden, Arbeitsplatte), 16, 22, 28, 10; Studio zusätzlich 38 (Arbeitsplatte, 38 Zeilen), 12, 18, 20, 15, 9, 30, 26, 40 sowie Verbundmaße (17,2; 17,6; 18,3; 19,6; 42; 48,8 …).
**Eingerechnete Belagsdicke (Basis):** Melamin 0,1 (546 Zeilen), Furnier 0,5 (178), 0,7 (27) [aus Stammdaten].
**Einheiten:** m², m³, m, Stück. `amount_per_unit` ist kein Preis.
**Studio-Gruppen:** P2 (Spanplatte roh und beschichtet, Egger, Pfleiderer, Cleaf) 204; MDF 82 (+ Perfectmatt 21, CDF/Valchromat schwarz); Fertigfurniert 46; Multiplex 41 (Birke, Wisa, Koskidecor); Tischlerplatte 35 (Stab, TwinCore, CrossCore); Mineralwerkstoff 34 (Fenix Compact, HI-MACS, Corian, Krono Compact); Sperrholz 20; Arbeitsplatte 17 (Egger, 38 mm, 4100 mm); Leimholz 13 (Eiche, Bambus); 3-Schicht 10; Glas 7; OSB/Gips; Massivholz (Eiche, Fichte, Nuss, Teak, WhiteWood, KVH). Projektbezogene Sonderanfertigungen existieren; sie sind hier nicht aufgeführt.
**Hersteller und Dekorsysteme (Firmen):** Egger (ST9/ST12/ST15/ST2-Strukturen, Dekornummern H/U/F/W), Thermopal (F-Dekore, Struktur 49), Pfleiderer, Cleaf, Kaindl, Fenix (Arpa), Forbo, HI-MACS, Corian, Krono, Wisa, Koskidecor.

**Studio gegen Basis [aus Stammdaten]:** Der Basisbestand ist Dekorspanplatte, Furnier und Massivholz aus drei Großhändlern; das Studio ergänzt Zweit-Händler, Multiplex, Mineralwerkstoff, Arbeitsplatten, Glas und Sonderverbunde und führt Platten häufig in Dicken außerhalb des Raster 8/19/25 (38, 12, 18, 20).

### 7.2 Beläge (`mat_coverings`, 665)
- **Basis (533):** HPL 374 (Holz Hahn 276, Roeren 96), Furnier 154 (ZEG), wenige Krono, Gegenzugpapier. Dicken HPL 0,8 (283), 0,6 (125), 1,4 (27), 0,9 (26), 1 (11), 0,7, 0,65, 2,5 (9), 3 (8); Faser fast immer längs (522), 11 ohne Faser.
- **Studio (132):** HPL 68, Fenix 20 (Dicke 0,9 und 1,2), Linoleum (Forbo) 16 (davon Bulletin Board 6 mm), Eichenfurnier (0,6; 1,5), Räucher-Eiche, Aluminiumblech 1,5. Dicken 0,8 (61), 2 (22), 0,9 (18), 1 (10). Faser fast immer "keine" (104).
- Einheit m² (652), m (12), Stück (1). `amount_per_unit` 0 (498) oder 1 (167); **Deutung offen** (siehe Abschnitt 9).

### 7.3 Kanten (`mat_edgebandings`, 1046)
**Dicke × Breite (Basis, Zeilen):** 0,8×23 (169), 2×31 (169), 2×23 (160), 2×24 (28), 0,5×24 (27), 1×24 (23), 2×34 (19), 0,5×34 (17), 3×24 (10), 1×34 (10), 1×42 und 2×42 (je 9), 10/15/20×24 (je 8), 2,5×24 (8), 5×24 (8). Studio: 0,8×23 (45), 1×23 (25), 0,8×43 (13), 2×23 (7), 1×43 (7), 1×24 (7), 2×33 (6), 2×43 (6), 0,8×29 (5), 0,8×33 (5), 1×33 (5), 1×45 (4); 12 Zeilen mit 0×0 (Prozess-/Platzhalterzeilen, z. B. Kante versiegeln).
**Regel Breite zu Plattendicke [Deutung aus den Paarungen]:** Breite = Plattendicke + 4 bis 5 (23 für 19 mm, 24 für 19 mm Furnier und Massiv, 31 bis 34 für 25 bis 28 mm, 42 bis 45 für 38 mm); Überstand ist Bearbeitungszugabe. Dicken 0,5 bis 0,8 für Furnier bzw. dünnes ABS, 1 bis 2 mm ABS, 3 bis 20 mm Massivholzanleimer (Breite 24).
**Kanten-Typen:** Basis fast nur "Ka-…" (ABS-Sicherheitskante Egger, Furnier-, Echtholzkante); Studio "ABS 23×0,8 …" (Egger, Kaindl) und Furnierkante europäische Eiche (24, 43). Einheit m (1033), m² (10), m³ (3). Händler Basis: Holz Hahn 502, ZEG 357 (zwei Schreibweisen); Studio: Behrens 81, Andresen & Jochimsen 69, Ostermann 14, HOFA 9, Roggemann 6, Klöpfer 2.

### 7.4 Oberflächenbehandlung (`mat_finishings`, 66)
- **Basis (43, Arti Wuppertal):** Beizen (BEI), Colorlack (COL), DD-Lack, NC-Lack, PUR-Lack, Wasserlack, Wachs, Öl, Hartöl, Leinölfirnis, Grundierungen, MDF-Füllgrund; Einheit Liter, `amount_per_unit` meist 0,25.
- **Studio (23):** Hesse Fantastic (Color, Natura, Clear), Härter, Isolierfüller, Nano Top, Verdünnung; Rubio Monocoat (Öl-Farbe, Pur, je 0,025 l/m²); Kantenversiegelung (dreimal Klarlack mit Zwischenschliff, Einheit m); Linoleum-Kantenbearbeitung; Flächenöl (m²). Lieferantenfeld "Lackspray" (vermutlich Lackierbetrieb), Andresen & Jochimsen, Ostermann, Behrens.
- **[Deutung]:** `amount_per_unit` = Verbrauch je Einheit (Liter je m² behandelter Fläche; Hesse 0,2 bis 0,23, Rubio 0,025, Arti 0,25). Das Feld ist kein Preis.

---

## 8. Feldbedeutungen

**Alle Dateien:** `techid` (GUID bzw. {GUID}), `symbolname` (Name des Vectorworks-Symbols), `description`, `supplier`, `supplierid` (Bestell-/Artikelnummer), `source` (xg/user/custom/custom xg), `path` (Bibliotheksdatei, im Studio mit Suffix "Eigene/Original"). Doppelt vorkommende Spalten (`techid`, `source`) sind in der Quelle Spalten aus der Verbindung zweier Tabellen.

**`lib_woodendrawerunderfloorsliders`:** `baseboardoffset`, `bottomboardoffset` (Lage der Bodenebenen gegenüber Seitenunterkante, [Deutung]), `dadodistancefrombottommin/max` (Passfenster für den Abstand der Nut von der Seitenunterkante), `drawerinnerwidthreduction` (Breitenabzug), `drawerlengthreduction` (Längenabzug), `drawersidemaxthickness`, `drawersliderlength` (Nennlänge), `drawersliderlengthaddition` (Korpus-Mehrtiefe), `mintopoffset` (Mindestluft oben).
**`lib_woodendrawerbox`:** JSON-Spalten `woodendrawermaterials` und `…boughtinsalesinfo`; Höhen (`sideH`, `backH`, `frontH`), Nut (`dado` Tiefe, Abstand, Spiel, Breite), Flags `dSide`/`dBack`/`dFront` (Nut in Seite, Hinterwand, Front), `isboughtin`, `overlay` (Fronteinlage), Eckenart, `frontKind`.
**`lib_drawerprofiles`:** `backheight`, `backwidthreduction`, `drawerprofilebottomboardlength`, `…widthoffset`, `…continuousbase`, `…defaultbackboardthickness`, `…defaultbaseboardthickness`, `drawerprofileheight`, `drawerprofilelength`, `drawerprofileslidersseries` (Pfad der zugehörigen Schienen-Serie), `minimumbottomoffset`.
**`lib_drawersliders`:** `drawersliderbottomsoffset` (Schienenhöhe über Zargenunterkante), `drawersliderlength`, `drawersliderlengthaddition`.
**`lib_systemdrawerbox`:** Verweise auf Zarge, Rück-/Frontbefestigung, Längsreling; Materialien und Kanten für Rückwand und Boden.
**Raster:** Zeichenketten in der Raster-Kurzschrift (Abschnitt 4.1), getrennt in X (Höhe), Y (Tiefe).
**Füße:** Einbauhöhe, min/max Verstellung, x/y-Versatz, `needsplinth`, `plinthreduction`, `heightaddition`.
**Scharniere:** Topfabstand, Überlappung (`overlay`), min/max Topfabstand, Typ (Eck/Mittel/Innen); `sourcetablename` in den "rightangled"-Sichten.
**Material:** `thickness` (Plattendicke; 0 bei Massivholz m³-Ware), `default_thickness` (60 Zeilen weichen ab, vor allem Massivholz-Bohlenstärken), `texture` (Struktur/Maserung, überwiegend Spanplatte), `grain` (längs/keine), `type` (melamine, veneer, custom, solid, gw, 3l, glass, steel), `groupid`, `unit`, `amount_per_unit`, bei Kanten `width`.

---

## 9. Offene Fragen

1. **Breitenabzug:** Ist `drawerinnerwidthreduction` Außenbreite = lichte Breite − X oder Innenbreite? Nur durch Herstellerunterlagen oder ein gebautes Muster zu klären.
2. **Nutabstand-Fenster:** Ist min/max der Abstand Seitenunterkante bis Nut-Unterkante oder Nut-Mitte? Betrifft die Passung der Studio-Kästen (13, 14,5, 15).
3. **Studio B (Nutabstand 14,5/15):** Für welche Auszugsserie gedacht? Nach den Daten nur Movento, Actro oder Tandem 560H.
4. **Studio-Kasten H55 (Front 34) und "In_H55" (tatsächlich 70):** Datenfehler oder Absicht.
5. **Hinterwandformel Nutabstand + Boden + 2:** Hersteller-Familie mit Nutabstand 11 weicht ab (23 statt 21); welche Regel ist maßgeblich?
6. **Tandem 550:** Nutabstand-Fenster 3 bis 13 (min 3) ungewöhnlich weit; Eingabefehler oder echtes Maß?
7. **`amount_per_unit`** bei Belägen und Kanten (0 oder 1): Lagerware-Flag, Verschnitt, Mengenfaktor? Bei Beschichtungen: Verbrauch pro m² (Deutung).
8. **Typ `gw`** bei Platten (49 Basis, 12 Studio): Bedeutung unklar (Schichtstoff-Glatt, Gewebe?).
9. **Raster-Suffix `N`** und der genaue Schwellenwert von `#(>x)` bei Sonderformen.
10. **Studio-Kantenzeilen mit 0×0 (12):** Prozesszeilen oder Platzhalter.
11. **Dübel 10×40:** Beschreibung nennt 8×40, Maß 10×40.
12. **Vollständigkeit:** Die Händler-Zuordnung (ZEG zwei Schreibweisen, Behrens statt ZEG bei 11 MDF-Zeilen) deutet auf Pflegeaufwand; welche Quelle gilt, wenn Studio und Basis kollidieren?
13. **Frontbefestigungen und Längsschienen (`drawerfrontfixings`, `drawerlongsiderails`):** nur gezählt, nicht ausgewertet; bei Bedarf Folgeauswertung.
