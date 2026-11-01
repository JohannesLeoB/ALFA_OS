# Großserien-Referenz v1 (Küchenkorpus, Vergleich zum Studio)

## Zweck
Beispiele typischer Großserien-Küchen als VERGLEICH zum Studiowissen. Nichts davon ist Studioregel.
Das Studio plant ohne Raster, mm-genau, Restfeld als Funktionsfeld, meist ohne Oberschränke.
Atome: `grossserie_v1.jsonl` (111 Zeilen). Felder: art (mass/regel/muster/stil), kataloge (1/2/beide), konsens, studio_vergleich.
Alle Maße in mm (Ausnahmen: Liter, Grad, Stück). K2-Belege sind PDF-Seiten (gedruckte Nummer = PDF minus 1).

## K1 vs K2 kurz
- K1 = Möbelhaus-Systemküche, Selbstmontage. Maßtafeln vollständig: festes Raster in Breite, Höhe, Tiefe; viel Zubehör; Planungstipps.
- K2 = Markenküche, Premium-Serie. Gelesene Teile sind überwiegend Bildseiten; Maße nur als Höhenlinien (730/800/860), Sockel, Platte, Nische, Höhenmodul, Frontstärken. Breiten und Tiefen fehlen.
- K1 liefert das Raster, K2 die Gestaltungsmuster (Fugenbild, Griffarten, Hochschrankwand, Insel). Daher ist K2 meist `art: muster`.
- Konsens K1: 3/3 bestaetigt, 2/3 wahrscheinlich, 1/3 einzeln. Konsens K2: je Abschnitt 2/2 bestaetigt, 1/2 einzeln. Bei "beide" gilt die niedrigere Stufe.

## Kernmaße (mm)
| Maß | K1 | K2 | Studio-Typwert |
|---|---|---|---|
| Sockel | 80 (Bein 80, Blende 80), fest | Standard 140 / 100 / 70 je Höhenlinie, frei 70 bis 200 | ~100 |
| Korpushöhe Unterschrank | 800 fest | 730 / 800 / 860 | ~810 |
| Korpustiefe | 600 (flach 370); Ecken 680/880 | nicht angegeben | ~560, Gesamt ~600 |
| Arbeitsplatte (Stärke) | nicht angegeben | Standard 39, wählbar 10 bis 60 | ~20 |
| OK Arbeitsplatte | nicht angegeben (Korpus + Bein = 880 + Platte) | 909 / 939 / 969 (abgeleitet) | ~930 |
| Nische AP bis Oberschrank | Empfehlung mind. 500 | Standard 542,5 | meist ohne Oberschränke |
| Wandschranktiefe | 370 (Aufsatz über Kühl-/Hochschrank 600) | nicht angegeben | meist ohne Oberschränke |
| Hochschrankhöhen | 1400 (Geräte-Unterbau), 2000, 2200, 2400 | 1900/2040/2170 (Linie 800), 1970/2100/2240 (730/860) | frei |
| Breitenstufen | 200, 300, 400, 600, 800; Ecken 880, 1280 | nicht angegeben | kein Raster, mm-genau |
| Fronthöhen-Modul | Schubladen 100/200/400; Türen 400 bis 2000 in Stufen | 132,5 (Halbreihe 67,5 nur einzeln) | frei; Fuge 1,5 bis 2 je Kante |
Weitere K2-Maße: Frontstärke 12 (schlank), Rahmenfront 10, Rillenfront 7,5 Rippe / 5 Abstand, Wangen 50 und 150.
Oberschrank-Höhen K2: 270/400/530/660/800 (930 nur Linie 730); Gesamthöhen je Linie genau drei, im Abstand 132,5.
Rechenbeispiel K2: Oberschrank-Unterkante = Sockel + Korpus + Platte + Nische (Linie 730: 140+730+39+542,5 = 1451,5).

## Was die Großserie zeigt, das Studio nicht hat
- Festes Breiten-, Höhen- und Tiefenraster; Frontteilung als Fertigkombination bzw. Höhenmodul.
- Nenn- und Istmaße weichen bei Ecken um 5 mm je Seite ab (1280 nominal = 1275 tatsächlich; 880 = 875; 680 = 675).
- Standard-Nischenmaß und systematische Oberschrank-, Mittelschrank- und Aufsatzhöhen; Oberkanten auf drei festen Gesamthöhen.
- Gerätenischen je Gerätetyp fest vorgegeben (Kühl 600 x 600, Ofen 1400 bis 2400).
- Fertige Deckseiten und Leisten in festen Maßen statt Zuschnitt; Anpassung an den Raum über Breitenstufen.
- Zubehörsystem: Abfalltrennung nach Volumen, Eckkarussell, Putzschrank-Einrichtung, Einsatzkästen, Scharniere mit Öffnungswinkel 95/110/153 Grad.
- Glas-Vitrinen mit Metallrahmen und Innenlicht, offene Regalnischen mit LED, Rückwandpaneel mit Ablageschiene.
- Gestaltungsmuster: Hochschrankwand bis zur Decke mit durchlaufenden Segmentfugen, Insel mit Überstand und Wasserfall-Kante, schwebender Unterschrank, begehbarer Hochschrank-Kubus.
- Griffsysteme als Serienentscheid (Griffmulde unter der Platte, Griffleiste, Stangengriff, grifflos); Maserung läuft über alle Fronten.
- Aufbauvarianten der Front (Rahmen 10, schlank 12, Keramik- und Steinträger 16+4 und 8+12).

## Was das Studio hat, das die Großserie nicht zeigt
- mm-genaue Planung und freie Maße je Objekt (Nische, Ecke, Gerät).
- Fugenvorgabe 1,5 bis 2 je Kante (beide Kataloge nennen nur "fein und gleichmäßig", K1 nennt Frontnennhöhe = Korpushöhe).
- Restfeld als Funktionsfeld mit passendem Maß. Nächste Entsprechung: K1 nutzt den 200er Schrank als Auszug/Handtuchstange (Atom GS-INNEN-08, studio_vergleich gleich).
- Maßzeichnungen und Drei-Seiten-Ansichten; die Kataloge liefern nur Tabellen und Bilder.
- Planung meist ohne Oberschränke; in den Katalogen sind Oberschränke und Vitrinen Standardbild.
- Sockel, Arbeitsplatte und Korpus als frei gewählte Einzelmaße statt Linienwerte.

## Konfliktentscheidungen
1. **730/800/860: Höhe, nicht Tiefe.** Lesung S (K2 Abschnitt 3) nennt Unterschrank-Korpushöhen mit Sockel 140/100/70 und Platte 39; Lesung H las dieselben Zahlen als Korpustiefen (73/80/86 cm) mit Sockel 14/10/7 und Platte 3,9 cm. Entscheidung: Höhe. Gründe: (a) Tiefen von 730 bis 860 sind für Unterschränke unplausibel (K1: 600); (b) Korpus + Sockel ergibt 870/900/930 und mit Platte 909/939/969, was Arbeitshöhen entspricht; (c) die Werte sind Vielfache des Moduls 132,5 (730 = 5 x 132,5 + 67,5) und passen exakt zu den Oberschrank-Höhen und Gesamthöhen; (d) beide Lesungen stimmen bei Sockel, Platte, Modul, Nische und Gesamthöhen überein. Die Tiefenzahlen sind verworfen; die Korpustiefe von K2 bleibt offen.
2. **Oberschrankbreiten 27 bis 147 (H) = Höhen.** H las die Folge 270/400/530/660/800/930/1070/1200/1340/1470 als Breiten. Sie ist deckungsgleich mit der Höhenfolge von S und dem Modul 132,5. Gewertet als Höhen.
3. **370/500/660 niedrige Unterschränke:** S liest Höhen (grifflose Linie), H las 37/50/66/80 cm als Breiten. Nicht entschieden; als einzeln mit Hinweis geführt.
4. **Eckmaße K1:** Tabelle nennt 1280/880/680 (Nennmaß im Namen), Maßhinweis nennt 1275/875/675 (Istmaß). Kein Widerspruch, sondern Nenn gegen Ist; beide im Atom. Planung mit Istmaß.
5. **Vitrinenbreite K1:** H1/H2 300 und 400, S1 300 bis 800. Als wahrscheinlich mit Hinweis geführt.
6. **K2-Dunstabzug:** abgehängter Rahmen (H) gegen integrierter Abzug (S); als einzeln geführt.

## Offene Punkte
- K1: Arbeitsplatte (Stärke, Überstand), Arbeitshöhe, Schubladen-Bauhöhen in mm, Hängehöhe der Aufhängeschienen, Fugenmaß, Korpusstärke fehlen.
- K1: Zuordnung der Deckseitenmaße 390/620 (Breite oder Tiefe) nicht eindeutig; vermutlich Tiefe 370/600 plus 20.
- K1: U-Form und Insel nur über Montageteile belegt.
- K2: Korpusbreiten, Korpustiefen, Wandschranktiefe, Eck- und Müllsysteme in den gelesenen Teilen nicht bemaßt.
- K2: Halbreihe 67,5, Gesamthöhen Linie 860 und Aufsatzhöhen nur von einer Lesung.
- K2: Die Linien-Diagramme sind aus Beschriftungen gelesen (cm im Original); Zuordnung niedriger Unterschränke ist Deutung.
- K2: Fugen sind nur als fein beschrieben; Rücksprungtiefe des Sockels nicht bemaßt.
- K1-Stand laut einer Lesung 2022; Aktualität nicht geprüft.
