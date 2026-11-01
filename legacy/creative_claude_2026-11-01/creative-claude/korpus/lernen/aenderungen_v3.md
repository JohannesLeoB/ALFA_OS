# Aenderungen v2 -> v3 (Runde 2)

Quellen: R2_T1, R2_T2, R2_T3 (Pruefrunde 2), R2_holdout (strenge Zaehlung ueber fremde Projektfamilien). Zaehlregel: zirkulaere treffer und nicht_pruefbar nicht gezaehlt (wie v2), zirkulaere gegen gezaehlt. EDIT/SPLIT: Zaehler 0, Status probe, alte Summe (v2 + R2) im Feld vorher. Alte IDs ersetzter Atome entfallen und werden nicht wiederverwendet; REMOVE-Atome bleiben mit Status entfernt. Status bestaetigt nur bei Holdout-treffer >= 3 aus mind. 2 fremden Familien und Gegenquote <= 20 % (Holdout und gesamt). Feld naehe: Anteil der R2-treffer innerhalb +-10 % des Startwerts (naehe_n = Anzahl Beobachtungen), null wenn nicht ablesbar.

## ADD, EDIT, SPLIT, REMOVE

| Operation | Atom-ID | ersetzt | Grund |
|---|---|---|---|
| ADD | GRI-012 | - | Pflicht 1: Griffart je Bauteilart statt ein System je Küche. R2: GRI-002b 4 gegen (T03-K1, T13-K1, T29-K1, T34-K1, T33-K1, T36-K1), GRI-005b 2 gegen (T03-K1, T29-K1), T12-K1 und T15-K1/K2/K3 mischen Mulde/grifflos je Bauteil. |
| ADD | GRI-013 | - | Pflicht 1: Bauteilart Unterschrank-Schublade. R2: GRI-004a 4 treffer (T16,T38,T40,T04-K2), GRI-003a 7 treffer. |
| ADD | GRI-014 | - | Pflicht 1: Bauteilart Unterschrank-Tür. R2: GRI-002a 7 treffer (T20-K2,T30,T28,T34,T39,T17-K2,T02). |
| ADD | GRI-015 | - | Pflicht 1: Bauteilart Oberschrank. R2: T11-K1 Oberschränke mit Messing-Knopf je Front (GRI-007 treffer); T20-K2 Technik-Oberschrank grifflos/PTO. |
| ADD | GRI-016 | - | Pflicht 1: Bauteilart Geräte-Front. R2: T13-K1 Öfen-HS Stange, T33-K1 Ofen-HS Stange, T36-K1 Griffleisten an Ofen-/Barnischentüren, T03-K1 Aufschraubgriffe an HS. |
| SPLIT | GRI-002c | GRI-002b | R2 6 gegen bei 7 treffer, Holdout 3/4: T03-K1 Aufschraubgriffe, T13-K1 Stange, T29-K1 Stangen, T34-K1 Stange, T33-K1 Stange, T36-K1 Leisten. PTO am Hochschrank nur wenn beschriftet. |
| SPLIT | GRI-002d | GRI-002b | R2 6 gegen: Hochschrank-Türen in Stangen-/Leisten-Küche ohne PTO-Beschriftung tragen Stange oder Leiste (T13-K1, T33-K1, T36-K1, T03-K1). |
| SPLIT | GRI-002e | GRI-002b | R2: T37-K1, T35 Plan-Widerspruch; Insel-/Halbinselrückseite PTO war nicht Streitpunkt (T36, T34-K1 PTO Rückseite). |
| EDIT | GRI-001c | GRI-001b | Pflicht 7: Raumliste in Bedingung entfernt. R2 7 treffer, 1 gegen (T12-K1 Eichen-Insel mit Mulde), alle 7 als überangepasst markiert (T01-K1, T13-K1, T33-K1, T35-K1, T36-K1, T37-K1, T38-K1). |
| EDIT | GRI-005c | GRI-005a | R2 4 treffer 2 gegen: T35-K1 Kühl-HS PTO, T29-K1 kurze schwarze Stange statt Edelstahl. Material nicht festlegen. |
| EDIT | GRI-005d | GRI-005b | R2 7 treffer 2 gegen (T03-K1 Aufschraubgriffe, T29-K1 Stangen am HS in grifflos Zeile). Griffart folgt Plan je Bauteil. |
| REMOVE | GRI-003b | - | In GRI-012 aufgegangen: Mischmuster Insel Mulde/Zeile grifflos nur 1 Beleg (T12-K1 zirkulär), Gegenrichtung T15-K1 (Edelstahl-Insel grifflos, Zeile Mulde). |
| SPLIT | MAS-019c | MAS-019a | R2 3 gegen bei 5 treffer: T15-K1 Gang 1900, T15-K2 1550-1600, T15-K3 1630-1650 (Soll 1000-1200). Hauptarbeitszone an der Wand: Gang Zeile bis Gegenzeile. |
| SPLIT | MAS-019d | MAS-019a | R2: T33-K1 1100, T40-K1 1100, T34-K1 1150-1160, T11-K1 ca. 1100 treffer bei Kochfeld auf Insel und Spüle an Wand, Zeilentiefe unter 680. |
| SPLIT | MAS-019e | MAS-019a | R2: T15-K1 1900, T15-K2 1550-1600, T15-K3 1630-1650 bei Kochfeld auf Insel, Zeilentiefe 700 und Inseltiefe 1200. Unterscheidung nach Zeilentiefe ist Hypothese (nur eine Familie). |
| REMOVE | MAS-019b | - | Ersetzt durch MAS-019e: Bedingung 'Insel ohne Kochen davor' trifft T15 nicht (alle drei T15-Küchen haben Kochfeld auf Insel), R2 nur zirkuläre treffer. |
| EDIT | MAS-009a | MAS-009 | Pflicht 3: Festwert 2700 verfehlt R2 oft (T14-K1 2880-2950 bei Decke 2950-2980, T34 3570-3575 bei 3600, T33 3050, T40 3200, T32 2562 bei 2600). Höhe = Raumhöhe minus Luft. |
| ADD | MAS-009b | - | Pflicht 3: Rückfallwert nur wenn Raumhöhe unbekannt. R2 T35 2395, T37 2376, T38 2390 (Halbinselküchen mit Aufsatz niedriger als Raum), T02 2723, T05 2700, T19-K3 2700. |
| EDIT | MAS-011a | MAS-011 | Pflicht 3: Luft hängt an Raumhöhe. R2 5 treffer, Luft 38 bei 2600, 590 bei 3790, 650 bei 3700, 25-55 bei 3600. |
| ADD | ANS-015 | - | Pflicht 4: Schwelle aus Belegen. Blenden 21-84 (T19 21, T04 30, T17 30/50, T20 84), Funktionsfelder ab 245 (T03 248, T37 250, T21 250, T11 250), Lücke 85-244. |
| EDIT | ANS-012a | ANS-012 | Pflicht 4: Startwert und Bereich aus Belegen. R2 7 treffer (T03 30, T04 2x30, T17 30/50, T18 2x30, T19 21, T20 84, T39 68), 0 gegen. |
| EDIT | ANS-013a | ANS-013 | Pflicht 4: R2 6 treffer (T17 295, T21 250, T33 330, T40 330, T11 250, T39 297/502), 0 gegen. Minimum auf 245 gesenkt (T03 248). |
| EDIT | BRE-005a | BRE-005 | R2 6 treffer 1 gegen: T18-K1 Restmaß 60 als 2x30 Blende, Schwelle fehlte. |
| EDIT | BRE-003c | BRE-003b | R2 10 treffer 2 gegen: T03-K1 Apotheker 248 unter 250, T04-K1 30er Füllstücke. Minimum 245, Blende unter 100 ausgenommen. |
| EDIT | ANS-006a | ANS-006 | R2 10 treffer 3 gegen (zwei neue: T04-K1 30er Füllstücke, T18-K1 2x30 Blende). Funktionsfeld nur bei Restmaß ab ca. 245. |
| REMOVE | ANS-001a | - | Pflicht 7: Bedingung 'T35-Familie' überangepasst. R2 0 treffer 6 gegen (T03-K1 30, T04-K1 30, T17-K1 30/50, T18-K1 30, T19-K1 21, T20-K1 84), außerhalb der Familie nie 70. Ersetzt durch ANS-001c und ANS-012a. |
| ADD | ANS-001c | - | Pflicht 7: Nachfolger von ANS-001a, allgemeine Bedingung nach Raumform. Belege T35,T37,T38 70, T39 68. |
| ADD | ANS-016 | - | R2-Lücke T41-K1: Stellseitenvorstand 26 vor Front ohne Atom. |
| SPLIT | MAS-006b | MAS-006a | Pflicht 6: R2 11 treffer 1 gegen (T41-K1 574). Gesamttiefe Wand bis Frontebene für Zeile an freier Wand. |
| SPLIT | MAS-006c | MAS-006a | Pflicht 6: T41-K1 574 gegen 600-700, T04-K1 604 in Nische. Nischenzeile zwischen Stellseiten ist eigene Gesamttiefe. |
| ADD | MAS-031 | - | Pflicht 6: Tiefenangaben trennen. R2 T41 574 (Gesamt), T20-K1 413-453 (Korpus Flachtiefe), T15-K1 HS-Block 467, Stellseite 26 vor Front. |
| SPLIT | MAS-025a | MAS-025 | Pflicht 5: Überstand Theke getrennt von Bank, Tresen, Tischanschluss. R2 2 treffer (T01 200, T17-K2 302), 3 nicht prüfbar. |
| ADD | LAY-021 | - | Pflicht 5: Tresen/Bar ohne Bank. R2 T36-K1 Halbinsel-Bar mit Hockern, T17-K2 Barseite mit zwei Paneelen, T36 Gang 822. |
| ADD | LAY-020 | - | Pflicht 5: Tischanschluss. R2 T09-K1 Insel mit angefügtem Tisch/Rechteckkörper ohne Atom, T35 Sitzbank mit Tisch. |
| ADD | MAS-032 | - | Pflicht 5: Sitznische mit Theke, T20-K2 Theke 1210 x 435, Tischoberkante 905. |
| SPLIT | MAS-024a | MAS-024 | Pflicht 5 / R2 aufspalten: T33-K1 Bank 1200 gegen 1615-1723 (Bank an Inselkopf). Essbank getrennt. |
| SPLIT | MAS-024b | MAS-024 | T33-K1 Bank/Regal am Inselkopf ca. 1200. |
| SPLIT | LAY-009a | LAY-009 | R2 12 treffer 1 gegen: T32-K1 runder freier Esstisch ohne Einbau, T16-K1 ungeklärt. |
| SPLIT | LAY-009b | LAY-009 | T32-K1 freier runder Esstisch, T16-K1 freier Esstisch. |
| EDIT | LAY-008a | LAY-008 | R2 6 treffer 1 gegen: T19-K2 glatte Außenseite mit Sitznische. |
| EDIT | MAS-016a | MAS-016 | R2 12 treffer 1 gegen: T17-K2 904 unter Minimum 908. |
| EDIT | MAS-018b | MAS-018a | R2 6 treffer 1 gegen: T11-K1 Plan nennt Insel, Form Halbinsel, Länge 2120. |
| ADD | MAS-012b | - | R2 T20-K2: Nischen-/Technik-Oberschrank 1045 hoch, 235 tief, doppelter Boden; MAS-012a 1 gegen. |
| SPLIT | BRE-019c | BRE-019b | R2: T17-K3 Regal/Sitzbank 430 am Blockende gegen Eckregal 250. |
| ADD | BRE-002c | - | R2: T17-K2 Insel-Schubmodule 800 gegen Zeilen-Schubmodule 900. |
| EDIT | BRE-001c | BRE-001a | R2 22 treffer 1 gegen: T02-K2 Möbel-Türpaar 360+360 statt 600. Möbel ausgenommen (BRE-023). |
| EDIT | GER-002b | GER-002a | R2 1 gegen: T18-K1 GSP Bestand zwischen Spüle und Kochfeld. |
| SPLIT | GER-014b | GER-014a | R2 T01-K1 gegen: Kochfeld über Ofen mit Knebel in Ofenfront, keine Blende, nicht prüfbar T22-K1. |
| SPLIT | GER-014c | GER-014a | T01-K1 Knebel in Backofenfront ohne Blende. |
| EDIT | GER-020a | GER-020 | R2 1 gegen: T30-K1 Spiegelrückwand über Zeile, Kochfeld auf Insel mit Muldenlüfter. |
| ADD | GER-022 | - | R2 Lücke T07-K1, T10-K1: zweites Becken in der Insel oder im Schenkel. |
| SPLIT | LAY-017a | LAY-017 | R2 2 gegen: T19-K3 Gerät Kühlschrank statt Ofen, T03-K1 Hauswirtschaft mit WM, Trockner, KG, Ofen. |
| SPLIT | LAY-017b | LAY-017 | T03-K1 Hauswirtschaftszeile mit Apotheker, WM, Trockner, KG-HS, Ofen-HS. |
| ADD | LAY-010d | - | R2 1 gegen LAY-010a: T11-K1 fünf Oberschränke (Terrazzo, Knopffronten, Inselhaube). |
| ADD | MAS-035 | - | R2 Lücke T14-K2: schwebende Regalböden bei 1590 und 1910 über OKFF. |

## UPVOTE / DOWNVOTE (unveraenderte Atome, Zaehler aus v2 plus R2)

| Operation | Atom-ID | Zaehler v3 (t/g/n) | Status v2 -> v3 | Grund |
|---|---|---|---|---|
| UPVOTE | MAS-001 | 46/0/7 | bestaetigt -> bestaetigt | 23 treffer in R2, Holdout 12 (Familien 9), 0 gegen |
| UPVOTE | MAS-002 | 41/0/5 | bestaetigt -> bestaetigt | 20 treffer in R2, Holdout 8 (Familien 6), 0 gegen |
| UPVOTE | MAS-003 | 12/0/10 | bestaetigt -> bestaetigt | 5 treffer in R2, Holdout 3 (Familien 3), 0 gegen |
| UPVOTE | MAS-004 | 10/0/3 | bestaetigt -> probe | 5 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | MAS-005 | 26/0/12 | bestaetigt -> probe | 12 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | MAS-008a | 5/0/3 | probe -> probe | 5 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | MAS-010a | 7/0/0 | probe -> probe | 7 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| DOWNVOTE | MAS-012a | 0/1/0 | probe -> probe | 1 gegen in R2 (T20-K2) |
| UPVOTE | MAS-014 | 2/0/2 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | MAS-015 | 2/0/2 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | MAS-017 | 22/0/0 | bestaetigt -> probe | 11 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | MAS-020a | 4/0/1 | probe -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | MAS-021 | 2/0/2 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | MAS-028 | 4/0/1 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| DOWNVOTE | BRE-002a | 5/1/0 | probe -> probe | 1 gegen in R2 (T17-K2); 5 treffer |
| UPVOTE | BRE-002b | 5/0/0 | probe -> probe | 5 treffer in R2, Holdout 2 (Familien 1), 0 gegen |
| DOWNVOTE | BRE-003a | 8/1/0 | probe -> probe | 1 gegen in R2 (T19-K2); 8 treffer |
| UPVOTE | BRE-004 | 21/0/0 | bestaetigt -> probe | 5 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | BRE-007 | 26/0/2 | bestaetigt -> bestaetigt | 13 treffer in R2, Holdout 4 (Familien 3), 0 gegen |
| UPVOTE | BRE-008a | 14/0/0 | probe -> probe | 14 treffer in R2, Holdout 2 (Familien 2), 0 gegen |
| UPVOTE | BRE-009a | 9/0/2 | probe -> probe | 9 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | BRE-011a | 4/0/0 | probe -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | BRE-012 | 10/0/0 | bestaetigt -> probe | 5 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | BRE-014a | 11/0/2 | probe -> bestaetigt | 11 treffer in R2, Holdout 4 (Familien 2), 0 gegen; hochgestuft |
| UPVOTE | BRE-019a | 2/0/0 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| DOWNVOTE | BRE-021a | 0/1/0 | probe -> probe | 1 gegen in R2 (T20-K2) |
| UPVOTE | BRE-022 | 2/0/0 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-001 | 9/1/4 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-002 | 2/0/3 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-003 | 6/0/2 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | FRO-004 | 6/0/1 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | FRO-005a | 3/0/0 | probe -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-006 | 6/0/0 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | FRO-010 | 2/0/3 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-012 | 2/0/3 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-017a | 1/0/1 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | FRO-018 | 2/0/3 | probe -> probe | 1 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | GRI-001a | 26/0/1 | probe -> probe | 26 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | GRI-002a | 7/0/0 | probe -> probe | 7 treffer in R2, Holdout 2 (Familien 2), 0 gegen |
| UPVOTE | GRI-003a | 7/0/1 | probe -> probe | 7 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | GRI-004a | 4/0/0 | probe -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | GRI-006 | 8/0/3 | bestaetigt -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | GRI-007 | 3/0/3 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | GRI-010 | 10/0/0 | bestaetigt -> probe | 6 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| DOWNVOTE | INN-001 | 3/2/13 | schwach -> schwach | 1 gegen in R2 (T04-K1); 2 treffer |
| UPVOTE | INN-002 | 16/0/19 | bestaetigt -> probe | 5 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-003 | 6/0/4 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-004 | 17/0/0 | bestaetigt -> probe | 8 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-006 | 4/0/0 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | INN-008 | 6/0/11 | bestaetigt -> probe | 2 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-010 | 7/0/0 | bestaetigt -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-012 | 4/0/4 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | INN-013 | 6/0/5 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | INN-020 | 2/0/1 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | INN-022 | 3/0/6 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | GER-001 | 32/0/7 | bestaetigt -> probe | 16 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | GER-003 | 19/0/15 | bestaetigt -> bestaetigt | 9 treffer in R2, Holdout 4 (Familien 4), 0 gegen |
| UPVOTE | GER-004 | 38/0/2 | bestaetigt -> bestaetigt | 19 treffer in R2, Holdout 8 (Familien 7), 0 gegen |
| DOWNVOTE | GER-005a | 21/1/2 | probe -> probe | 1 gegen in R2 (T01-K1); 21 treffer |
| UPVOTE | GER-005b | 2/0/0 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | GER-006 | 12/0/2 | bestaetigt -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | GER-007 | 31/0/7 | bestaetigt -> bestaetigt | 15 treffer in R2, Holdout 4 (Familien 2), 0 gegen |
| UPVOTE | GER-008a | 11/0/2 | probe -> bestaetigt | 11 treffer in R2, Holdout 3 (Familien 2), 0 gegen; hochgestuft |
| UPVOTE | GER-009 | 13/0/1 | bestaetigt -> probe | 6 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | GER-010 | 54/0/4 | bestaetigt -> bestaetigt | 25 treffer in R2, Holdout 15 (Familien 9), 0 gegen |
| UPVOTE | GER-011a | 7/0/10 | probe -> probe | 7 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | GER-013 | 30/0/0 | bestaetigt -> bestaetigt | 14 treffer in R2, Holdout 8 (Familien 8), 0 gegen |
| UPVOTE | GER-016 | 21/0/0 | bestaetigt -> bestaetigt | 10 treffer in R2, Holdout 4 (Familien 4), 0 gegen |
| UPVOTE | GER-018 | 6/0/2 | bestaetigt -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | LAY-001a | 17/0/1 | probe -> probe | 17 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | LAY-002 | 12/0/2 | bestaetigt -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | LAY-003 | 18/0/5 | bestaetigt -> probe | 9 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | LAY-004a | 2/0/0 | probe -> probe | 2 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | LAY-004b | 2/0/0 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | LAY-005 | 2/0/3 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | LAY-006 | 6/0/0 | bestaetigt -> probe | 3 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| DOWNVOTE | LAY-010a | 15/1/6 | probe -> bestaetigt | 1 gegen in R2 (T11-K1); 15 treffer; hochgestuft |
| UPVOTE | LAY-011 | 12/0/15 | bestaetigt -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | LAY-014 | 4/0/1 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | LAY-015 | 2/0/2 | probe -> probe | 1 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | RAU-001 | 14/1/1 | probe -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | RAU-002 | 12/0/6 | bestaetigt -> probe | 4 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | RAU-003 | 4/0/9 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | RAU-004 | 13/0/0 | bestaetigt -> probe | 4 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | RAU-005a | 5/0/1 | probe -> probe | 5 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | RAU-006 | 11/0/2 | bestaetigt -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | RAU-008 | 7/0/0 | bestaetigt -> probe | 4 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | ANS-001b | 6/0/0 | probe -> probe | 6 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| DOWNVOTE | ANS-002a | 8/1/0 | probe -> probe | 1 gegen in R2 (T20-K1); 8 treffer |
| UPVOTE | ANS-003 | 10/0/4 | bestaetigt -> probe | 5 treffer in R2, Holdout 2 (Familien 2), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | ANS-008 | 4/0/11 | probe -> probe | 2 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | ANS-009 | 13/0/3 | bestaetigt -> probe | 7 treffer in R2, Holdout 1 (Familien 1), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | ANS-010 | 9/0/1 | bestaetigt -> probe | 4 treffer in R2, Holdout 0 (Familien 0), 0 gegen; zurueckgestuft: Holdout-Nachweis (>=3 treffer, >=2 Familien) nicht erreicht |
| UPVOTE | ANS-011a | 4/0/2 | probe -> probe | 4 treffer in R2, Holdout 1 (Familien 1), 0 gegen |
| UPVOTE | ANS-011c | 2/0/1 | probe -> probe | 2 treffer in R2, Holdout 0 (Familien 0), 0 gegen |
| UPVOTE | LAY-018 | 3/0/1 | probe -> probe | 3 treffer in R2, Holdout 0 (Familien 0), 0 gegen |

Summe: UPVOTE 88, DOWNVOTE 8.

Atome ohne treffer/gegen in R2 behalten Zaehler (nur nicht_pruefbar addiert).
