# 08 Airtable-Stammdaten: Wissen für die Bibliotheken (Material, Kante, Beschlag, Gerät)

Datenstand: 2026-11-01, nur lesend gezogen (list_records, search_records, analyze_table, Schema). Keine Schreibaufrufe.
Kennzeichnung: **belegt** = gezählt oder gelesen; **Beispiel** = Stichprobe, nicht vollständig; **Annahme** = Schluss von mir, nicht in den Daten.

## 0. Gelesen und nicht gelesen

- Gelesen wurden nur die freigegebenen Tabellen. Ausgelassen habe ich: alle Preis-, Margen-, Rabatt- und EK/VK/UVP-Felder, alle Kontaktfelder (Ansprechpartner, E-Mail, Telefon, Verantwortlich, Assignee, Kunde, Empfänger), die Notizen-Felder, "Verwendet in Projekten" (Projektnamen) und die Preisliste-Anhänge.
- Hinweis zur Schema-Abfrage: `list_tables_for_base` liefert Feldnamen und Feldtypen aller Tabellen der Base, auch der nicht freigegebenen. Von diesen habe ich keine Datensätze gelesen. Andere Bases wurden nicht geöffnet.
- **Befund beim Stichproben-Lesen:** Das Feld `Beschreibung` aller 18.136 Armac-Martin-Artikel enthält eine Preisnotiz ("Originalpreis ... (GBP), umgerechnet ..."). Gezählt: 18.136 Treffer für "Originalpreis" = exakt alle Armac-Martin-Artikel. Die Notiz habe ich in diesem Bericht nicht wiedergegeben. Beschreibung darf für diesen Hersteller nicht in eine Bibliothek übernommen werden.
- Die Dokument-URLs vom Typ `file://` enthalten absolute Pfade in einen lokal gemounteten Google-Drive-Ordner (mit Kontonamen). Im Bericht verkürzt dargestellt.

## 1. Überblick

| Base | Tabelle | Zeilen | Bemerkung |
|---|---|---|---|
| Mustermaterialien (`appYZ6oK3qjIFGiFu`) | Materialien | 18 | Gerüst, fast alle Felder leer (siehe 3) |
| | Materialkategorien | 30 | vollständig gepflegt |
| | Kollektionen | 15 | Name, Hersteller, Gruppe befüllt; Katalogfelder leer |
| | Hersteller | 59 | Kategorie und Bereich befüllt; Website 0 von 59; Partnerstatus 3 von 59 |
| Artikeldatenbank (`appcrBerh7niynxmQ`) | Kategorien | 57 | 54 mit Artikeln, 3 ohne (Sonstiges, Badarmatur, Küchenarmatur) |
| | Hersteller | 33 | 28 mit Artikeln; Website 0 von 33 |
| | Artikel | 48.965 | ein Hersteller je Artikel (Summe der Hersteller-Zählung = Gesamtzahl) |
| | Dokumente | 10.544 | alle mit URL |

## 2. Materialtaxonomie (Materialkategorien, 30 Zeilen, belegt)

Felder: Kategorie, Relevanz, Bereich, Priorität, Beschaffungsweg, Bestandszustand, Im Musterschrank, Altbestand-Ordner.

### 2.1 Alle 30 Kategorien

| Kategorie | Relevanz | Bereich | Prio | Beschaffungsweg | Bestandszustand | Im Musterschrank |
|---|---|---|---|---|---|---|
| Massivholz / Arbeitsplatten | Kern | kueche | 1 | Eigenscan Flachbett | lebendig 2024-26 | ja |
| Komposit / Quarzwerkstoff | Kern | kueche, bad | 1 | Partnerportal | lebendig 2024-26 | ja |
| Naturstein | Kern | kueche, bad, allgemein | 1 | Eigenscan Flachbett | lebendig 2024-26 | ja |
| Furnier | Kern | allgemein | 1 | Eigenscan Flachbett | lebendig 2024-26 | ja |
| Schichtstoff / HPL | Kern | kueche, allgemein | 1 | BIMobject zuerst prüfen | eingefroren 2018/19 | ja |
| MDF durchgefärbt | Kern | allgemein | 1 | BIMobject zuerst prüfen | nicht im Altbestand | ja |
| Metall / Bleche | Kern | kueche, bad, allgemein | 1 | Eigenscan Flachbett | eingefroren 2018/19 | ja |
| Fliesen / Keramik | Kern | bad, allgemein | 1 | öffentlicher Crawl | eingefroren 2018/19 | ja |
| Lacke / Farben | Kern | allgemein | 1 | öffentlicher Crawl | nicht im Altbestand | ja |
| Badausstattung / Sanitär | Kern | bad | 1 | Partnerportal | nicht im Altbestand | ja |
| Geräte | Kern | kueche | 1 | Partnerportal | nicht im Altbestand | ja |
| Spülen | Kern | kueche | 1 | Partnerportal | nicht im Altbestand | ja |
| Linoleum | regelmäßig | allgemein | 2 | öffentlicher Crawl | lebendig 2024-26 | ja |
| Licht | regelmäßig | allgemein | 2 | Partnerportal | nicht im Altbestand | ja |
| Glas | regelmäßig | kueche, allgemein | 2 | Partnerportal | nicht im Altbestand | ja |
| Terrazzo | regelmäßig | bad, allgemein | 2 | öffentlicher Crawl | eingefroren 2018/19 | ja |
| Kanten | regelmäßig | allgemein | 2 | Partnerportal | nicht im Altbestand | ja |
| Wandbeschichtung / Putz | regelmäßig | bad, allgemein | 2 | Eigenfoto Stativ | eingefroren 2018/19 | nein |
| Akustikpaneele | regelmäßig | allgemein | 2 | öffentlicher Crawl | lebendig 2024-26 | nein |
| Möbelfronten | regelmäßig | kueche, allgemein | 2 | BIMobject zuerst prüfen | eingefroren 2018/19 | nein |
| Mineralwerkstoff / Corian | regelmäßig | kueche, bad | 2 | noch offen | eingefroren 2018/19 | nein |
| Stoffe / Textil | regelmäßig | allgemein | 2 | Außendienst anfragen | lebendig 2024-26 | nein |
| Möbel / Sitzmöbel | regelmäßig | allgemein | 3 | Partnerportal | nicht im Altbestand | nein |
| Filz | selten | allgemein | 3 | Eigenscan Flachbett | eingefroren 2018/19 | ja |
| Leder | selten | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |
| Beton | selten | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |
| Kork / Gummi | selten | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |
| Kunststoff | selten | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |
| Tapete | Altlast, prüfen ob raus | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |
| Bodenbeläge | Altlast, prüfen ob raus | allgemein | 3 | noch offen | eingefroren 2018/19 | nein |

### 2.2 Verteilungen (belegt)

- Relevanz: Kern 12, regelmäßig 11, selten 5, Altlast 2.
- Priorität: 1 zuerst 12 (= alle Kern), 2 danach 10, 3 später 8.
- Beschaffungsweg: Partnerportal 8, Eigenscan Flachbett 5, öffentlicher Crawl 5, noch offen 7, BIMobject 3, Eigenfoto Stativ 1, Außendienst anfragen 1.
- Bestandszustand: eingefroren 2018/19: 14, nicht im Altbestand: 9, lebendig 2024-26: 7.
- Im Musterschrank: 18 von 30.
- Altbestand-Ordner (Drive-Altbestand `OBERFLAECHEN_MATERIAL`): z. B. HOLZ | APL, LINOLEUM, STEIN, NATURSTEIN, FURNIER, HPL, FLIESEN, MÖBELFRONT, CORIAN, METALLE | BLECHE | GITTER | + METAL + GALVANISIEREN, TEPPICH + AUSLEGEWARE + INDUSTRIEBODEN + HOLZ | DIELEN.
- Die Taxonomie kennt keine Kategorie für Beschläge, Griffe, Schubkästen, Scharniere, Sockel oder Innenausstattung. "Kanten" ist die einzige Verbindung zu den Fertigungsteilen.

### 2.3 Auswahllisten (Vokabular, direkt als Enum-Vorlage nutzbar, belegt)

- Materialgruppe (14): Naturstein, Komposit / Keramik, HPL / Schichtstoff, MDF / Spanplatte, Furnier, Massivholz, Lack / Farbe, Metall, Glas, Fliese / Mosaik, Linoleum, Kante, Textil / Filz, Sonstiges. Dieselbe Liste existiert in Materialien und in Kollektionen, mit verschiedenen Choice-IDs.
- Farbsystem (6): RAL, NCS, Pantone, Hersteller-eigen, Natursteinname, keins.
- Glanzgrad (9): stumpfmatt / supermatt, matt, seidenmatt, seidenglänzend, glänzend, hochglanz, poliert, satiniert / gebürstet, strukturiert.
- Verwendung (12): Front, Korpus, Arbeitsplatte, Nische / Rückwand, Wandverkleidung, Boden, Waschtisch, Dusche / Nassbereich, Kante, Sichtseite / Regal, Möbelbau allgemein, Außenbereich.
- Beständigkeit (10): feuchtraumgeeignet, wasserfest, UV-stabil, kratzfest, hitzefest, lebensmittelecht, antibakteriell, fleckenempfindlich, imprägnierung nötig, nicht für Nassbereich.
- Einsatzhäufigkeit (5): Standard (fast immer im Angebot), oft, gelegentlich, Sonderfall, noch nie eingesetzt.
- Verfügbarkeit (4): aktuell, Auslauf, abgekündigt, unbekannt.
- Bereich (3): kueche, bad, allgemein.
- Schlagworte (20, visuelle Anmutung): hell, dunkel, warm, kühl, neutral, monolithisch, kontrastreich, ruhig, lebhaft, gemasert, geadert, gesprenkelt, grafisch, unifarben, haptisch, spiegelnd, natürlich, technisch, rustikal, edel.
- Partnerstatus Hersteller (4): Vertragspartner, Regulär, Gelegentlich, Inaktiv. Befüllt nur bei 3 Herstellern (BORA, Liebherr, Gaggenau = Vertragspartner).
- Vollständigkeit Kollektion (4): vollständig, lückenhaft, veraltet, unbekannt.

### 2.4 Hersteller der Mustermaterialien (59, belegt; Hersteller | Kategorie | Bereich)

- **Platten / HPL / MDF (11):** Valchromat, Kronospan, Forbo, FENIX (Arpa), Westag, Fundermax, Latho, Kaindl, Egger, Cleaf, Pfleiderer. Bereich fast durchgehend "allgemein"; FENIX zusätzlich kueche.
- **Komposit / Keramik (5):** Pyrolave (kueche, bad), Lapitec (kueche, bad), HTS Surfaces (kueche), Cosentino (Dekton / Silestone) (kueche, bad), Santamargherita (auch Naturstein; kueche, bad).
- **Naturstein (4):** Steinzeit Berlin (kueche, bad), Nerostein (allgemein), Salvatori (bad, allgemein), Santamargherita.
- **Fliese / Mosaik (3):** Bisazza (bad), Mosaic Factory (bad), Mutina (bad, allgemein).
- **Massivholz (1):** Spekva (kueche). **Metall (2):** Büchele (auch Textil / Filz; allgemein), ROY Edelstahl (kueche). **Glas (1):** Frerichs Glas. **Kanten / Zubehör (1):** Ostermann. **Möbel (2):** Mattiazzi, Brdr. Krüger. **Farbe / Lack (2):** Little Greene, RAL.
- **Geräte (10):** Neff, Falmec, Novy, BORA (Vertragspartner), IoMabe, Liebherr (Vertragspartner), Dometic, AEG, Quooker (auch Armaturen), Gaggenau (Vertragspartner). Bereich kueche.
- **Spülen (3):** Systemceram, Caressi, Reginox. **Armaturen (6):** THG Paris, QuadroDesign, Tapwell, Axor, Gessi, Quooker. **Sanitär (5):** Agape, NIC Design, Alape, Cielo, Kaldewei. **Licht (5):** Anour, BEGA, Wästberg, IP44, marset.
- Summe 62 Zuordnungen auf 59 Hersteller (Büchele, Quooker, Santamargherita haben je zwei Kategorien). Website: in keiner Zeile befüllt.

## 3. Materialien des Studios (Tabelle Materialien, 18 Zeilen, belegt)

Die Tabelle ist ein Gerüst. Sortiert nach Einsatzhäufigkeit:

| Material | Hersteller | Gruppe | Farbsystem | Oberfläche / Glanz | Verfügbarkeit | Einsatzhäufigkeit |
|---|---|---|---|---|---|---|
| FENIX NTM 0172M / FX 0772 | (nicht verknüpft) | HPL / Schichtstoff | Hersteller-eigen | supermatt, Anti-Fingerprint, thermisch selbstheilend; Glanzgrad stumpfmatt / supermatt | aktuell | **oft** |
| Valchromat Black | Valchromat | MDF / Spanplatte | Hersteller-eigen | nicht erfasst | aktuell | nicht erfasst |
| Valchromat Blue, Chocolate Brown, Green Mint, Grey, Khaki, Light Grey, Orange, Red, White Pearl, Yellow (10 weitere Zeilen) | Valchromat | MDF / Spanplatte | Hersteller-eigen | nicht erfasst | aktuell | nicht erfasst |
| Atlantic Grey, satiniert | (nicht verknüpft) | Naturstein | Natursteinname | satiniert | unbekannt | nicht erfasst |
| Taj Mahal, satiniert | (nicht verknüpft) | Naturstein | Natursteinname | satiniert | unbekannt | nicht erfasst |
| Taj Mahal, poliert | (nicht verknüpft) | Naturstein | Natursteinname | poliert | unbekannt | nicht erfasst |
| Rojo Alicante, Bianco Perlino, Arenisca San Miguel (3 Zeilen) | (nicht verknüpft) | Naturstein | Natursteinname | nicht erfasst | unbekannt | nicht erfasst |

Füllgrad der 18 Zeilen (belegt):

- 18 von 18: Material, Materialgruppe, Farbbezeichnung, Farbsystem, Bereich, Verfügbarkeit.
- 11 von 18: Hersteller-Verknüpfung (nur die Valchromat-Zeilen).
- 4 von 18: Oberfläche / Finish.
- **1 von 18** (nur FENIX): Glanzgrad, Verwendung (Front, Korpus, Wandverkleidung, Nische / Rückwand, Sichtseite / Regal), Beständigkeit (kratzfest, antibakteriell, nicht für Nassbereich), Schlagworte (dunkel, warm, unifarben, haptisch, technisch, ruhig), Einsatzhäufigkeit.
- **0 von 18:** Lieferstärken, Formate, Artikel- / Dekornummer, Hex, Lieferzeit, Zulieferer / Handelsweg, Kollektion, Materialkategorie-Verknüpfung, "Für Kundenpräsentation" (nicht angehakt).

### Zusammenfassung: was setzt das Studio wirklich ein?

- **Einsatzhäufigkeit trägt keine Aussage:** nur 1 von 18 Zeilen ist bewertet (FENIX NTM 0172M, "oft"). Eine Rangliste der real eingesetzten Plattenwerkstoffe lässt sich aus den Daten nicht ableiten.
- Indizien aus der Taxonomie (Relevanz "Kern, in fast jedem Projekt"): Massivholz / Arbeitsplatten, Komposit / Quarzwerkstoff, Naturstein, Furnier, Schichtstoff / HPL, MDF durchgefärbt, Metall / Bleche, Fliesen / Keramik, Lacke / Farben, Badausstattung / Sanitär, Geräte, Spülen. Das ist die Priorität des Studios für die Bildbeschaffung, kein Verbrauchsnachweis.
- Plattenwerkstoffe und Oberflächen, die in den Daten tatsächlich auftauchen: HPL (FENIX NTM supermatt; Kollektion Cleaf Musterkasten), durchgefärbtes MDF (Valchromat, 11 Farben), Naturstein (Atlantic Grey, Taj Mahal, Rojo Alicante, Bianco Perlino, Arenisca San Miguel; Oberflächen satiniert und poliert), Komposit / Keramik laut Kollektionen (Silestone, Dekton, SM Marble Bd. 2).
- **Stärken und Formate: keine Daten** (0 von 18). Die Beispiele "8, 12, 19, 25" und "3050x1320" stehen nur in den Feldbeschreibungen als Muster, nicht als Datenwerte.

## 4. Kollektionen / Kataloge (15 Zeilen, belegt)

| Kollektion | Hersteller | Materialgruppe | Stand | Vollständigkeit |
|---|---|---|---|---|
| FENIX NTM | FENIX (Arpa) | HPL / Schichtstoff | leer | unbekannt |
| Cleaf Musterkasten | Cleaf | HPL / Schichtstoff | leer | unbekannt |
| Valchromat Farbreihe | Valchromat | MDF / Spanplatte | leer | **vollständig** |
| WORK BOX 2021-2024 | Pfleiderer | MDF / Spanplatte | 2021-2024 | **veraltet** |
| Silestone Color Collection | Cosentino (Dekton / Silestone) | Komposit / Keramik | leer | unbekannt |
| Dekton Color Collection | Cosentino (Dekton / Silestone) | Komposit / Keramik | leer | unbekannt |
| SM Marble Bd. 2 | Santamargherita | Komposit / Keramik | leer | unbekannt |
| Salvatori Oberflächenboxen | Salvatori | Naturstein | leer | unbekannt |
| Spekva Arbeitsplatten-Hölzer | Spekva | Massivholz | leer | unbekannt |
| Büchele Metall & Filz | Büchele | Metall | leer | unbekannt |
| Furniture Linoleum Desktop | Ostermann | Linoleum | leer | unbekannt |
| Ostermann Kantenkollektion | Ostermann | Kante | leer | unbekannt |
| RAL K5 Classic (Farbfächer) | RAL | Lack / Farbe | leer | unbekannt |
| Big Book of Colour | Little Greene | Lack / Farbe | leer | unbekannt |
| Colours by Kaldewei | Kaldewei | Lack / Farbe | leer | unbekannt |

- Verteilung nach Materialgruppe: Lack / Farbe 3, Komposit / Keramik 3, HPL 2, MDF 2, Metall 1, Linoleum 1, Kante 1, Naturstein 1, Massivholz 1.
- **Katalog-URL: 0 von 15. Drive-Ordner: 0 von 15. Artikelanzahl (lt. Katalog): 0 von 15. "Katalog importiert": 0 von 15. Stand: 1 von 15.**
- Die Kollektionen sind also reine Platzhalter mit Hersteller und Gruppe, ohne Verweis auf Katalogdateien.

## 5. Artikeldatenbank (48.965 Artikel)

### 5.1 Kategorien mit Oberkategorie und Synonymen (57, belegt)

Oberkategorien und Artikelzahl (Summe über die zugeordneten Kategorien; Summe aller Zeilen = 48.965):

| Oberkategorie | Kategorien | Artikel |
|---|---|---|
| Beschläge | Griff, Beschläge, Scharnier, Haken, Müllsystem | 19.508 |
| Leuchten | Leuchte | 9.432 |
| (keine Oberkategorie) | Armatur | 6.162 |
| Spülen & Küchenarmaturen | Spüle, Arbeitsplatte, Seifenspender, Weiteres Zubehör, Reservoir, CUBE, CUBE-Zubehör, Küchenarmatur | 2.713 |
| Küchengeräte | 35 Gerätekategorien (inkl. Systemschublade) | 2.458 |
| Zubehör | Zubehör | 1.065 |
| Waschen & Pflege | Waschmaschine / Trockner, Waschautomat EFH, Wäschetrockner EFH, Textilpflegesystem | 35 |
| Bad | Badarmatur | 0 |
| Allgemein | Sonstiges | 0 |
| **ohne Kategorie** | | **7.592** |

Synonyme (Feld `Synonyme`, ein Begriff je Zeile) sind für 56 von 57 Kategorien gepflegt (nur "Sonstiges" hat keine). Die Oberkategorie fehlt nur bei "Armatur". Auswahl der Synonyme (Beispiele):

- Scharnier: Topfband, Türband, Band, Hinge. Griff: Knauf, Knopf, Bügelgriff, Muschelgriff, Stangengriff, Handle, Knob, Pull. Haken: Wandhaken, Garderobenhaken, Kleiderhaken, Hook, Robe Hook. Beschläge: Beschlag, Möbelbeschlag, Hardware, Fitting. Systemschublade: Schublade, Besteckeinsatz, Schubkasten, Auszug. Müllsystem: Abfallsystem, Mülleimer, Abfalltrennsystem, Abfallsammler.
- Spüle: Spülbecken, Einbauspüle, Becken. Arbeitsplatte: Küchenarbeitsplatte, Platte, Worktop, Countertop, Arbeitsfläche. Armatur / Küchenarmatur / Badarmatur: Wasserhahn, Mischbatterie, Hahn, Waschtischarmatur, Wannenarmatur, Brausearmatur.
- Backofen: Ofen, Backrohr, Einbaubackofen, Kombibackofen, Dampfbackofen. Kochfeld: Kochplatte, Herdplatte, Induktionskochfeld, Ceranfeld. Dunstabzug: Dunsthaube, Abzugshaube, Wandhaube, Inselhaube. Kühlschrank / Kühlgerät: Gefrierschrank, Kältegerät, Kühl-Gefrier-Kombination. Geschirrspüler: Spülmaschine, Geschirrspülmaschine. Winecooler: Weinklimaschrank, Weinkühlschrank, Weinschrank. Leuchte: Lampe, Licht, Beleuchtung, Pendelleuchte, Wandleuchte.
- Auffälligkeiten (Einschätzung): "Arbeitsplatte" und "Systemschublade" scheinen in der falschen Oberkategorie zu liegen (Spülen & Küchenarmaturen bzw. Küchengeräte). Neu angelegt am 2026-09-27: Badarmatur, Küchenarmatur (noch 0 Artikel, Armatur hält noch alle 6.162).

### 5.2 Artikel je Kategorie (vollständig gezählt)

| Kategorie | Artikel | | Kategorie | Artikel |
|---|---|---|---|---|
| Griff | 14.281 | | Kühlschrank | 75 |
| Leuchte | 9.432 | | Zubehör Backofen | 103 |
| **ohne Kategorie** | **7.592** | | Weiteres Zubehör | 102 |
| Armatur | 6.162 | | Zubehör Dunstabzüge | 156 |
| Beschläge | 2.935 | | Seifenspender | 148 |
| Spüle | 2.241 | | Muldenkochfeld | 88 |
| Scharnier | 1.324 | | Lüfter Zubehör | 52 |
| Zubehör | 1.065 | | Zubehör Steamer | 41 |
| Haken | 967 | | Mikrowelle | 40 |
| Dunstabzug | 422 | | SET | 38 |
| Kochfeld | 387 | | Wärmeschublade | 36 |
| Kühlgerät | 387 | | Steamer | 29 |
| Arbeitsplatte | 213 | | Dampfgarer | 23 |
| Backofen | 208 | | Waschmaschine / Trockner | 23 |
| Geschirrspüler | 136 | | Kochgeschirr, Winecooler, Muldenkochfeldzubehör, Glaskeramikkochfeld | 22, 22, 22, 21 |
| Vakuumieren | 20 | | Muldenlüfter | 18 |
| Backofen-Kochfeld-Set | 16 | | Zubehör Kühlschrank | 17 |
| Systemschublade | 12 | | Kühlen Zubehör | 12 |
| Kaffeevollautomat | 11 | | Zubehör Glaskeramikkochfeld | 9 |
| Zubehör Geschirrspüler | 8 | | Coffee-Center, Herd, Muldenkochfeld SET | 7, 7, 7 |
| CUBE-Zubehör | 5 | | Waschautomat EFH, Wäschetrockner EFH, Textilpflegesystem | 4, 4, 4 |
| Reservoir, Verbrauchsware | 3, 3 | | Kochfeld / Grill | 2 |
| Fritteuse, Müllsystem, CUBE | 1, 1, 1 | | Sonstiges, Badarmatur, Küchenarmatur | 0 |

### 5.3 Artikel je Hersteller (vollständig gezählt, mit Kategorie-Aufteilung)

| Hersteller | Artikel | Verteilung |
|---|---|---|
| Armac Martin | 18.136 | Griff 12.920, Beschläge 2.935, Scharnier 1.314, Haken 967 |
| Super Modular | 7.192 | Leuchte 7.192 |
| Dornbracht | 6.834 | **ohne Kategorie 5.948**, Armatur 806, Seifenspender 45, Spüle 21, Zubehör 14 |
| Vola | 3.468 | Armatur 3.176, Zubehör 131, Seifenspender 91, Weiteres Zubehör 70 |
| Tapwell | 1.751 | Armatur 1.751 |
| Marset | 1.440 | Leuchte 1.440 |
| Miele | 1.394 | **ohne Kategorie 1.394** |
| Franke | 1.394 | Spüle 856, Armatur 325, Arbeitsplatte 213 |
| Viefe | 1.361 | Griff 1.361 |
| Blanco | 902 | Spüle 902 |
| Neff | 707 | 20 Kategorien, u. a. Kochfeld 119, Zubehör Dunstabzüge 118, Geschirrspüler 65, Kühlschrank 58; ohne Kategorie 68 |
| Anour | 604 | Leuchte 604 |
| Novy | 552 | Zubehör 195, Dunstabzug 114, Kochfeld 83, ohne Kategorie 111, Leuchte 30 u. a. |
| AEG | 541 | 18 Kategorien (Kochfeld 76, Kühlgerät 57, Geschirrspüler 54 u. a.) |
| Gaggenau | 530 | Zubehör 245, Backofen 81, Kochfeld 77, Kühlgerät 41 u. a. |
| Falmec | 514 | Dunstabzug 209, Zubehör 144, Spüle 84, ohne Kategorie 68, Kochfeld 9 |
| Reginox | 436 | Spüle 302, Zubehör 103, Armatur 31 |
| V-Zug | 286 | 20 Kategorien (Backofen 30, Steamer 29, Zubehör Steamer 41, Zubehör Dunstabzüge 38 u. a.) |
| Bora | 272 | Zubehör 79, Lüfter Zubehör 52, Muldenkochfeld 24, Kochfeld 23 u. a. |
| Liebherr | 204 | Kühlgerät 204 |
| IP44 | 160 | Leuchte 148, Zubehör 12 |
| Quooker | 101 | Armatur 49, Weiteres Zubehör 31, Seifenspender 12, CUBE-Zubehör 5, Reservoir 3, CUBE 1 |
| Caressi | 76 | Spüle 76 |
| IoMabe | 41 | Kühlgerät 41 |
| Dometic | 32 | Kühlgerät 32 |
| Quadro Design | 23 | Armatur 14, Zubehör 9 |
| Gessi | 10 | Armatur 10 |
| Peka | 1 | Müllsystem 1 |
| (kein Hersteller) | 3 | ohne Kategorie |

- Hersteller-Zeilen ohne Artikel: Wever Ducré, W+, Joseph Giles, Hailo, "Supermodular" (Dublette zu "Super Modular").
- Schreibweisen zwischen den Bases: Mustermaterialien nutzt BORA, marset, QuadroDesign; Artikeldatenbank Bora, Marset, Quadro Design. Mustermaterialien hat dafür das Feld "Artikel-DB Hersteller" als Join-Schlüssel (laut Schema; Werte nicht gelesen).
- Überschneidung der Hersteller beider Bases: 18 (Neff, Falmec, Novy, Bora, IoMabe, Liebherr, Dometic, AEG, Quooker, Gaggenau, Tapwell, Reginox, Caressi, Quadro Design, Gessi, IP44, Marset, Anour). Nur in der Artikeldatenbank: Super Modular, Armac Martin, Vola, Dornbracht, Miele, Viefe, V-Zug, Franke, Blanco, Peka und vier leere Zeilen. Nur in Mustermaterialien: 41 Hersteller (alle Plattenwerkstoffe, Steine, Fliesen, Sanitär usw.).

### 5.4 Weitere Kennzahlen Artikel (belegt)

- Status: Aktiv 14.760, Auslaufend 37, **leer 34.168**.
- Einheit: Stück 24.395, Paar 1.291 (Scharniere), SET 38, **leer 23.241**.
- Variante (Oberfläche / Farbe): befüllt bei Armac Martin 18.136, Dornbracht 5.809, Tapwell 1.751, Miele 900, Blanco 857, Anour 604, Caressi 76, IoMabe 29, Quadro Design 18, Gessi 10, Vola 4. Beispiele: Satin Brass Satin Lacquered, Dark Bronze, Aged Copper, Matte Black, Honey Gold, Dark Platinum gebürstet, Light Gold (PVD).
- Gewicht g: 1.383 (nur Miele). EAN: 16.563. Produktlink: 1. Bild-URL: 20.671. Bild-Anhang: 0.
- 3D-Dateien (Links): 1.796 Artikel, nach Hersteller: Neff 457, Reginox 336, Marset 266, Gaggenau 194, Tapwell 182, V-Zug 168, Liebherr 147, Falmec 46. Formate laut Linktext: ZIP (CAD/DWG/DXF/OBJ), ZIP mit DWG/OBJ/FBX, STP (3D-CAD), DXF-Ausschnittzeichnung (Reginox, Einbauspülen).
- Die Bezeichnung vieler Geräte ist zusammengesetzt aus "Hersteller + Kategorie + Beschreibung + Artikelnummer" (z. B. bei Neff, V-Zug, Bora, AEG). Zum Normalisieren eignet sich das Feld Artikelnummer.

### 5.5 Maße: wie viele Artikel haben Maße? (belegt)

| Messgröße | Artikel | Anteil |
|---|---|---|
| Breite mm befüllt | 1.421 | 2,9 % |
| Tiefe mm befüllt | 1.421 | 2,9 % |
| Höhe mm befüllt | 1.386 | 2,8 % |
| Breite, Höhe und Tiefe alle befüllt | 1.386 | 2,8 % |
| Textfeld "Maße" befüllt | **0** | 0 % |
| Hersteller der 1.421: | Miele 1.386 (alle ohne Kategorie, Stück, Gewicht in g), Falmec 35 (Kategorie Spüle, nur Breite und Tiefe) | |

- **Für 47.544 von 48.965 Artikeln (97,1 %) gibt es keine strukturierten Maße.**
- Maße stehen bei den übrigen im Text. Grober Indikator (Teilstring-Suche, "mm" trifft auch Fremdtreffer, also eine Obergrenze): "mm" in der Bezeichnung bei 20.464 Artikeln (davon 18.136 Armac Martin: z. B. "64MM", "128MM"), "cm" bei 1.880; "mm" in der Beschreibung bei 5.829, "cm" bei 996.
- Muster der Texte (Beispiel): Franke-Spülen "403x433x200mm", "780x510mm", "970x500mm"; Viefe-Griffe "CC128L160mm" (Lochabstand CC, Länge L); Armac Martin "64MM", "50MM X 38MM"; Franke-Arbeitsplatten "Tiefe bis 850mm", "Maximallänge bis 3800mm", "Dicke wahlweise 20, 30 oder 40mm"; Neff und AEG: "60cm", "80cm", "86,5cm Höhe", "Einbaumaß 14cm".

### 5.6 Dokumentlage (belegt)

Dokumente je Typ (10.544): Datenblatt 5.812, Montageanleitung 3.035, Zeichnung 790, Bedienungsanleitung 472, Sonstiges 435. Barcode und Bild: 0.

Verteilung der Links: 6.202 Dokumente zeigen auf einen lokalen Pfad (`file://` in die Papers-Ablage im Drive, Unterordner `Dokumente/<Hersteller>/` bzw. `Geräte/<Hersteller>/`), 4.342 auf eine Web-URL (franke.com Produktblatt-API, media3.bsh-group.com, api-prod.dornbracht.com, tapwell.com u. a.). Lokale Pfade sind nicht portabel (rechnerspezifisch). Nach Typ lokal / Web: Montageanleitung 2.774 / 261, Datenblatt 2.130 / 3.682, Zeichnung 621 / 169, Bedienungsanleitung 316 / 156, Sonstiges 361 / 74.

Artikel mit mindestens einem Dokument und nach Typ (verschiedene Artikel, aus der Verknüpfung berechnet):

| Messgröße | Artikel | Anteil an 48.965 |
|---|---|---|
| mit mindestens einem Dokument | 6.734 | 13,8 % |
| mit Datenblatt | 5.775 | 11,8 % |
| **mit Montageanleitung** | **2.986** | **6,1 %** |
| mit Zeichnung | 794 | 1,6 % |
| mit Bedienungsanleitung | 472 | 1,0 % |
| mit Sonstigem | 364 | 0,7 % |
| mit Maßen (siehe 5.5) | 1.421 | 2,9 % |

Nach Hersteller (Artikel mit Datenblatt / Montageanleitung): Marset 963 / 787 (von 1.440), Neff 704 / 497 (von 707), Anour 564 / 456 (von 604), Gaggenau 530 / 162 (von 530, dazu Bedienungsanleitung 163), Novy 205 / 211 (von 552), AEG 169 / 177 (von 541), V-Zug 143 / 160 (von 286), Liebherr 155 / 156 (von 204), Franke 1.169 / 0 (von 1.394), Dornbracht 846 / 0 (von 6.834), Falmec 46 / 52 (von 514), Tapwell 0 / 160 (Zeichnung 403, von 1.751), Reginox 0 / 0 (Zeichnung 327, von 436), Quooker 0 / 68 (Zeichnung 49, von 101), IoMabe 41 / 41 (von 41), Caressi 0 / 41 (von 76), Bora 83 / 1 (von 272), Blanco 72 / 0 (von 902), Gessi 10 / 10.
**Ohne jedes Dokument: Armac Martin (18.136), Super Modular (7.192), Vola (3.468), Miele (1.394), Viefe (1.361), Peka.**

Nach Kategorie (Artikel mit Dokument / Anteil; Montageanleitung):

| Kategorie | Artikel | mit Dokument | mit Montageanleitung |
|---|---|---|---|
| Leuchte | 9.432 | 1.650 | 1.273 |
| Armatur | 6.162 | 1.595 | 222 |
| Spüle | 2.241 | 1.217 | 41 |
| Zubehör | 1.065 | 391 | 92 |
| Kochfeld | 387 | 294 | 193 |
| Kühlgerät | 387 | 288 | 238 |
| Dunstabzug | 422 | 231 | 209 |
| Backofen | 208 | 203 | 152 |
| Geschirrspüler | 136 | 113 | 98 |
| Kühlschrank | 75 | 75 | 73 |
| Scharnier | 1.324 | 10 | 10 |
| Systemschublade | 12 | 5 | 3 |
| Griff / Beschläge / Haken | 14.281 / 2.935 / 967 | 0 / 0 / 0 | 0 / 0 / 0 |
| ohne Kategorie | 7.592 | 67 | 21 |

### 5.7 Beispiele nach Warengruppe (Beispiel, nicht vollständig)

**Beschläge (Armac Martin, Griff/Scharnier/Haken/Beschläge).** Beschreibung wegen Preisnotiz nicht übernommen. Dokumente und Maßfelder: keine.

| Bezeichnung | Artikelnummer | Kategorie | Einheit / Variante | Maß |
|---|---|---|---|---|
| 64MM SOLID BRASS BUTT HINGE SBSL CW SBSL POZI SCREWS | 204/64/SBSL-POZI | Scharnier | Paar / Satin Brass Satin Lacquered | 64 mm nur im Namen |
| 50MM X 38MM STEEPLE FINIAL HINGE DBZ | 2300/STEEPLE/50/DBZ | Scharnier | Paar / Dark Bronze | 50 x 38 mm im Namen |
| 128MM BARWICK PULL HANDLE WITH BACKPLATE PLAIN PBL | BWK/PLAIN/128/PBL | Griff | Stück / Polished Brass Lacquered | 128 mm im Namen |
| 38MM COTSWOLD BUN KNOB ONLY MBL | COTK/BUN/KNOBONLY/38/MBL | Griff | Stück / Matt Black Lacquered | 38 mm im Namen |
| 45MM DIGBETH FLUSH LATCH PLAIN NBP | DIG/LATCH/FLUSH/PLAIN/45/NBP | Beschläge | Stück / Aged Nickel | 45 mm im Namen |
| 70MM DOUBLE WARDROBE HOOK SAS | 0845/70/SAS | Haken | Stück / Satin Antique Satin Lacquer | 70 mm im Namen |
| CHAMBERLAIN PLAIN 1-GANG 2-WAY 20 AMP 250V ROCKER SWITCH ... | CHA/PLAIN/1G/ROC/2WAY/BLK/SAUL | Beschläge | Stück | Schalter, kein Möbelbeschlag |

Anmerkung: Unter "Beschläge" liegen auch Toilettenpapierhalter, Schalter und Schrauben (z. B. "(12'S) 8G x 3/4 Pozi Flat Csk SBUL"). Die Kategorie ist gemischt.

**Griffe (Viefe).** BRAVE - CC128L160mm metallic grey handle (0452128FM23); ROMA - CC160L175mm matt black handle (0241160ZM2); WING - CC128L200mm brushed black pull (0600128L30); BOL - hook in matt black+beech D45mm (7015045NM223, ein Haken unter Griff). Keine Beschreibung, keine Maßfelder, keine Dokumente.

**Schubkästen / Auszüge (Systemschublade, 12 Artikel).** Es sind ausschließlich Geräteschubladen: BORA Multischublade 140mm (MS140, 3 Datenblatt-Einträge), BORA Multischublade Glasfront 140mm (MSF140), BORA Ebenen-Rost (MSER); Neff Dampfschublade N19DJ01Y0 ("Einbaumaß 14cm", Datenblatt, Montageanleitung, 3D-ZIP-Link); V-Zug Vakuumierbeutel 1012507 (ein Verbrauchsartikel, falsch einsortiert). Müllsystem (1): Peka Öko Complet Aqua Q, K:600/T:495mm Auszugssystem 40 l anthrazit für Quooker (200.2787.43), mit Produktlink in einen Webshop (der einzige Artikel mit Produktlink).

**Scharniere (Topfbänder), Innenausstattung, Füße / Sockel, Platten, Kanten.** Keine echten Artikel vorhanden. Kontrollsuche über die Bezeichnung (Teilstring, ohne Unterscheidung Groß/Klein): Blum 0, Hettich 0, Topfband 0, Schubkasten 0; "Sockel" 43 Treffer (Gerätezubehör, Marset-Leuchtensockel, Neff-Weinschrank mit Sockelaggregat, Miele "APCL108 Sockel SmartBiz"), "Fuß" 4 (Miele Silikonfuß für Gourmetplatte, Franke Bodengitter mit Füßen 676x401x26mm), "Besteck" 9 (Geschirrspüler-Besteckkörbe, Falmec Besteckkasten aus Holz 293x128mm), "Kante" 28 (alle Franke-Spülen: Kantenradius, gefaste Kante), "Auszug" 131 (Geräteauszüge). Die Kategorie Scharnier besteht aus 1.314 Armac-Martin-Artikeln (Zierbänder, Einheit Paar) und 10 Neff-Artikeln (nicht gesichtet; Annahme: Gerätescharniere, keine Möbelbänder).

**Spülen.** Franke 135.0682.983 "MRG 210-37 403x433x200mm 3 1/2 Stopfenventil ... steingrau" (Datenblatt); Franke 124.0381.390 "MRK 611-78, 780x510mm, ... Glacier" (Datenblatt); Franke 114.0477.968 "Antea, AZG 651, 970x500mm, Cashmere, ..." (Datenblatt); Blanco 527254 "BLANCO ELON XL 6 S-F, vulkangrau" (Datenblatt); Reginox R30929 "Amsterdam 10 black silvery" (Verkaufszeichnung, DXF-Ausschnitt, STP-3D-Modell). Strukturierte Maße nur bei Falmec (35 Spülen, Breite und Tiefe).

**Arbeitsplatten (Franke, 213 Edelstahl-Arbeitsplatten).** 105.0558.536 "Pure Steel, Diamond Finish, Tiefe bis 850mm, 8mm massiv Edelstahl, Maximallänge bis 3800mm"; 105.0559.260 "Fine Steel, Dicke wahlweise 20, 30 oder 40mm, Whirl Finish"; 105.0558.648 "Pure Steel, Crystal Finish, Tiefe bis 550mm, 4mm, bis 3900mm". Alle Maße im Text; Dokumente nur bei 2 von 213.

**Einbaugeräte.**

| Gerät | Hersteller / Artikelnummer | Kurzbeschreibung | Links |
|---|---|---|---|
| Backofen | V-Zug 2105900007 | Combair V6000 45P | Datenblatt, Bedienungsanleitung, Montageanleitung, ZIP 3D-Planungsdaten |
| Backofen | Neff B64FT33N0 | FullSteam Slide&Hide Einbaubackofen, 6,8" TFT | Datenblatt, Montageanleitung, 3D-ZIP (CAD/DWG/DXF/OBJ) |
| Kochfeld | Neff T56YHF1C0 | 60cm, Induktion, 4 Zonen, FlexDesign-Rahmen | Datenblatt, Montageanleitung, 3D-ZIP |
| Kochfeld | AEG KIF6840IS | Induktionskochfeld autark 80cm | Datenblatt, Montageanleitung |
| Kühlgerät | Liebherr IRBc 4120-22 | Einbau-Kühlschrank, integriert, Festtür, BioFresh | Datenblatt, Bedienungsanleitung, Montageanleitung, 3D-ZIP (DWG/OBJ/FBX) |
| Geschirrspüler | Neff S297TCX00E | vollintegriert, 14 Maßgedecke, 86,5cm Höhe | Datenblatt, Montageanleitung, 3D-ZIP |
| Geschirrspüler | AEG NG52IE10K | vollintegriert 60cm, 82cm Höhe | keine |
| Dunstabzug | Falmec 102622 | Inselhaube 175cm schwarz, EEK C | Datenblatt, Montageanleitung, 3D-Modell-ZIP |
| Dunstabzug | Neff D97XDP2S5 | integrierte Designhaube N70, 90 cm, Abluft / Umluft | Datenblatt, Montageanleitung, 3D-ZIP |
| Gerät ohne Kategorie, mit Maßen | Miele 12866530 "KFMC 3834 L" | Breite 850, Höhe 2300, Tiefe 780 mm | keine |
| Gerät ohne Kategorie, mit Maßen | Miele 13094430 "G 7281 SCVi" | Breite 670, Höhe 970, Tiefe 690 mm, Variante Edelstahl | keine |
| Armatur | Tapwell 9423051 "TAP7300 Matte Black" | Variante Matte Black | Zeichnung (Drawing-PDF) |
| Armatur | Dornbracht 27632811-99 (ohne Kategorie) | Wannen-Vierlochbatterie, Beschreibung mit Ausladung, Armaturenhöhe, Bohrungsdurchmesser als Text | Datenblatt |

Bei Dornbracht steht die Technik (Ausladung, Armaturenhöhe, Bohrungsdurchmesser, Durchfluss) als " · "-getrennter Text in der Beschreibung.

## 6. Folgerungen für die Bibliotheken

### 6.1 Was ist schon da

- **Taxonomie und Vokabular:** 30 Materialkategorien mit Relevanz, Priorität, Beschaffungsweg und Bereich; 14 Materialgruppen, 6 Farbsysteme, 9 Glanzgrade, 12 Verwendungen, 10 Beständigkeiten, 20 Schlagworte, 5 Einsatzhäufigkeiten. Direkt als Enums und Filter für die Materialbibliothek nutzbar.
- **Hersteller-Landkarte:** 59 Hersteller mit Kategorie und Bereich; 11 Plattenhersteller, 5 Komposit-/Keramikhersteller, 4 Natursteinhändler, Ostermann als einziger Kantenlieferant, 10 Gerätehersteller (3 Vertragspartner).
- **Geräte und Zubehör (Gerät):** 2.458 kategorisierte Küchengeräte (35 Kategorien) und 35 Waschgeräte; dazu Miele mit 1.394 Artikeln ohne Kategorie (Annahme: Geräte und Zubehör, nur 3 Zeilen gesichtet). Die Kategorien samt Synonymen eignen sich für die Suche. Dornbracht (5.948 ohne Kategorie) sind laut Stichprobe Armaturen und Brausen, kein Gerät.
- **Spülen und Arbeitsplatten:** 2.241 Spülen (Franke, Blanco, Reginox, Caressi, Falmec, Dornbracht), 213 Edelstahl-Arbeitsplatten; für Reginox DXF-Ausschnitt und STP vorhanden.
- **Dokumentverweise:** 10.544 Links (Datenblatt, Montageanleitung, Zeichnung, Bedienungsanleitung), 1.796 Links zu 3D-/CAD-Dateien. Für Neff, Gaggenau, V-Zug, Liebherr, Falmec, Marset, Tapwell, Reginox.
- **Verbindungsschlüssel:** Interne ID (ART-nnnnnn) und "Artikel-DB Hersteller" (laut Schema) verbinden Mustermaterialien und Artikeldatenbank.

### 6.2 Was fehlt oder ist unbrauchbar

| Bibliothek | Fehlt oder ist leer (belegt) |
|---|---|
| **Material** | Stärken, Formate, Dekornummer, Hex, Lieferzeit, Handelsweg: 0 von 18. Einsatzhäufigkeit 1 von 18. Hersteller-Link bei 7 von 18 nicht gesetzt. Kataloge: URL, Drive-Ordner, Artikelanzahl 0 von 15. Kein Zusammenhang Materialien zu Materialkategorien (Link 0 von 18). Materialien ist nur ein Gerüst mit 18 Zeilen. |
| **Kante** | Keine Kantenartikel in der Artikeldatenbank. In Mustermaterialien nur: Kategorie "Kanten" (Prio 2, noch kein Bestand), Hersteller Ostermann, Kollektion "Ostermann Kantenkollektion" (Vollständigkeit unbekannt, ohne Katalog). Kantenstärke, Kantenbreite, Dekorzuordnung und Verfügbarkeit gibt es nirgends. |
| **Beschlag** | Die 19.508 Beschlagsartikel sind fast alle Armac Martin (18.136; Zierbeschläge, Preisnotiz in der Beschreibung, keine Dokumente, keine Maßfelder) und Viefe-Griffe (1.361, mit Lochabstand nur im Namen). Es gibt **keine** Schubkastensysteme, Topfbänder, Auszüge, Klappenbeschläge, Innenausstattung oder Sockelfüße (Blum, Hettich: 0 Treffer). Systemschublade und Müllsystem sind Geräte-/Einbauartikel. |
| **Gerät** | Strukturierte Einbaumaße (Nischenmaß, Ausschnittmaß) fehlen außer bei Miele (1.386) und Falmec (35). Bei Neff, AEG, Gaggenau, V-Zug, Bora, Liebherr gibt es keine Breite/Höhe/Tiefe. Dornbracht (5.948) und Miele (1.394) haben keine Kategorie. Status leer bei 34.168 Artikeln. |
| **Allgemein** | Maße strukturiert nur 2,9 %. Montageanleitung 6,1 %. Datenblatt 11,8 %. Einheit leer bei 23.241. 6.202 Dokumentlinks sind lokale Pfade. |

### 6.3 Vorschläge (Annahme, nicht aus den Daten)

- Maßfelder je Bibliothek vorsehen, die in der Quelle fehlen: Plattenstärke und Format (Material), Kantenstärke und Kantenbreite (Kante), Lochabstand und Länge (Griff), Nenngröße und Bohrbild (Scharnier), Nischenmaß B/H/T und Ausschnittmaß (Gerät, Spüle). Im Datenbestand liegen diese Werte nicht vor.
- Maße aus Textmustern ableiten, jeweils mit Konfidenz markieren: "CC128L160mm" (Viefe), "403x433x200mm" (Franke), "60cm", "Einbaumaß 14cm", "Tiefe bis 850mm". Armac Martin: Zahl vor "MM" im Namen. Quelle: Bezeichnung, nicht Beschreibung.
- Fehlende Gerätemaße aus den vorhandenen Datenblatt-PDFs (5.812 Links) oder den 3D-ZIPs (1.796) holen. Dort ist Maßmaterial wahrscheinlich, aber nicht geprüft.
- Armac Martin gesondert behandeln: Beschreibung nicht übernehmen, Variante (Oberfläche) und Namen nutzen.
- Die 7.592 Artikel ohne Kategorie vor einem Import klassifizieren (Dornbracht, Miele zuerst), damit die Gerätebibliothek nicht ihre größten Lieferanten verliert.
- Für "Schubkasten/Beschlag" eine andere Quelle suchen (siehe offene Fragen).

## 7. Offene Fragen

1. **Wo liegen die Beschlags- und Plattendaten?** Weder Mustermaterialien noch Artikeldatenbank enthalten Schubkastensysteme, Topfbänder, Klappenbeschläge, Innenausstattung, Sockel oder Plattenformate/-stärken. Gibt es sie in einer anderen Base, im Drive-Altbestand `OBERFLAECHEN_MATERIAL`, in Papers oder in Herstellerkatalogen, und darf die App sie lesen? (Andere Bases habe ich nicht geöffnet.)
2. **Woher kommt die Einsatzhäufigkeit?** Das Feld ist nur bei FENIX NTM befüllt. Soll es aus Angeboten oder Projekten abgeleitet werden (Quelle außerhalb dieser Tabellen), oder wird es von Hand gepflegt?
3. **Soll Materialien als Hauptentität befüllt werden?** Aktuell 18 Zeilen, Kollektion-, Kategorie- und Hersteller-Verknüpfungen fehlen. Wird sie über die Intake-/Medien-Pipeline gefüllt oder muss die Bibliothek eigene Einträge anlegen?
4. **Kollektionen ohne Katalog:** Soll die Bibliothek auf Katalog-PDFs verweisen (Katalog-URL und Drive-Ordner sind 0 von 15)?
5. **Zwei Materialvokabulare:** Materialkategorien ("Schichtstoff / HPL", "MDF durchgefärbt", "Komposit / Quarzwerkstoff", "Lacke / Farben") und Materialgruppe ("HPL / Schichtstoff", "MDF / Spanplatte", "Komposit / Keramik", "Lack / Farbe") und die Hersteller-Kategorie ("Platten / HPL / MDF", "Farbe / Lack") benennen dasselbe unterschiedlich. Es gibt keine Zuordnungstabelle. Welches Vokabular ist maßgeblich?
6. **Armac Martin:** Sind die 18.136 Artikel (Zierbeschläge, Schalter, Schrauben, Preisnotiz in der Beschreibung) bewusst in der Beschlagsbibliothek vorgesehen, oder nur ein Sortiment für Sonderprojekte? Soll die Beschreibung bereinigt werden?
7. **Unkategorisierte Artikel:** Ist die Kategorisierung von Dornbracht und Miele in Arbeit? Die neuen Kategorien Badarmatur und Küchenarmatur (angelegt 2026-09-27) sind noch leer, Armatur hält alle 6.162.
8. **Status:** Ist "leer" (34.168) gleichbedeutend mit "Aktiv"? Was bedeutet "Auslaufend" (37) für die Bibliothek?
9. **Maßfelder:** Gelten die Werte bei Miele als Außenmaß des Geräts oder als Nischenmaß? Die Einheit ist Millimeter (Breite 850 / Höhe 2300 / Tiefe 780 bei einem Kühlgerät), Gewicht in Gramm.
10. **Hersteller-Dubletten:** "Super Modular" und "Supermodular", Schreibweisen BORA/Bora, marset/Marset, QuadroDesign/Quadro Design. Wer führt sie zusammen?
11. **Lokale Dokumentlinks:** 6.202 von 10.544 Dokumenten zeigen auf `file://`-Pfade im Drive-Mount. Wie soll die App sie auflösen (Drive-ID, relativer Pfad in Papers)?
12. **Website der Hersteller:** in beiden Hersteller-Tabellen 0 Einträge. Wird sie für die Bibliotheken gebraucht?
