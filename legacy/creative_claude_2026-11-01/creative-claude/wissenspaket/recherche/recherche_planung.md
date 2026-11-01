# Recherche: Küchenplanung – Markt, Normen, Automatik, Prüfungen, Aufmaß

Stand: 31.10.2026 · Webrecherche, Quellen am Ende als [Q#].
**Ehrlichkeitsregeln:** Normtexte (DIN/EN) sind kostenpflichtig und wurden **nicht** im Original gelesen. Werte stammen aus
Inhaltsverzeichnissen, Abstracts und seriösen Sekundärquellen. Status-Kürzel in den Tabellen:
`N` Norm aktuell (sekundär belegt) · `N-zurück` zurückgezogen · `V` Verband/Richtlinie · `H` Hersteller (gerätespezifisch) ·
`R` Ratgeber (schwach) · `US` US-Richtlinie · `?` unsicher/widersprüchlich.

## 0. Korrekturen an den Annahmen des Auftrags

1. **DIN 68935 betrifft nicht die Küche.** Sie regelt Koordinationsmaße für Badmöbel, Geräte und Sanitärobjekte (Ausgabe 2009-10, aktuell) [Q22].
   Für die Küche gilt **DIN EN 1116:2018-03**, „Koordinationsmaße für Küchenmöbel und Küchengeräte“ (aktuell) [Q20].
2. **DIN 18022** („Küchen, Bäder und WCs im Wohnungsbau; Planungsgrundlagen“, 1989-11) ist **zurückgezogen**. DIN verweist ersatzweise auf
   VDI 6000 Blatt 1 (2008-02), ohne sie als Nachfolger zu bezeichnen [Q24]. Alte „DIN-Stellflächen“ aus Ratgebern stammen vermutlich von hier (`?`).
3. **„AMK-Zonenplanung“ ist nicht belegt.** Das Fünf-Zonen-Modell ist als **Blum DYNAMIC SPACE** (Pressemitteilung 2005) dokumentiert [Q35].
   Für die AMK ist nur die Empfehlung zur Arbeitshöhe nach Ellenbogenhöhe (2011) belegt [Q31].
4. **Abstände für Dunstabzug und Kochfeld** sind keine Normwerte. Es sind Herstellerangaben, die je Gerät und Haubentyp abweichen [Q39–Q42].
   → Sie gehören in die **Gerätedaten**, nicht in die Kern-Grundwerte.
5. **„KPS.Konfigurator“** wurde als Produktname nicht gefunden. Belegt ist die Produktfamilie KPS.MAX (vision/manage/protect/web/suite) [Q5].

## 1. Planungssoftware im Markt (DE/EU)

| Software | Anbieter / Zielgruppe | Kern (laut Quelle) | Daten | Auto-Planung / Prüfung | Q |
|---|---|---|---|---|---|
| **CARAT** | MHK-Gruppe, seit 1989. Küchenfachhandel, laut MHK >45.000 Planer in >80 Ländern | 3D/fotorealistisch, Auftragsabwicklung, Empfehlungstool, Online-Planer, VR, Aufmaß-App EasyRoom | Herstellerdaten. Seit 2022 Pilot: Bosch-Hauspreisliste HPL+ direkt in CARAT | Prüffunktionen nicht öffentlich belegt | Q1,Q2,Q63 |
| **KPS** (designstudio, business, KPS.MAX) | SHD AG, Andernach. Küchen- und Badhandel. SHD hält seit 2016 die Mehrheit an ArtiCAD (UK) | Planung, CRM („KPS.MAX manage“), Online-Planer und Lead-Tool („KPS.MAX web“), VR/360° („vision“) | – | **KPS protect**: Kollisions-, Öffnungskollisions- und Abstandsprüfungen. Hinweise zu Planbarkeit, Sicherheit, Ergonomie und Vollständigkeit. Prüfbericht, Abrechnung pay-per-use. ATAK-Integration für Nobilia und Pino | Q3–Q6 |
| **Winner Flex** | Compusoft, heute Cyncly. Küchenstudios und Handel | Cloud, Echtzeit-Kalkulation, automatische Angebote, Bestellung an Hersteller, BIM-Export nach Revit | Eigene Katalogdatenbank. Eine Drittquelle nennt „>100 Küchenhersteller“ (`?`) | **„[Hersteller] Bestellkontrolle“**: Prüfservice des Herstellers mit Fehlern, Warnungen und Hinweisen je Positionsnummer, inklusive Erklärbildern | Q7–Q10 |
| **2020 Design Live** | 2020, heute Cyncly. Nordamerika-lastig | Herstellerkataloge und generische Kataloge über 2020 Cloud, EZ Render, Anbindung an magicplan | Herstellerkataloge | Keine Prüfungen dokumentiert | Q11 |
| **Palette CAD** | Schreiner, Tischler, Innenarchitekten | Schrankkonfigurator, Stücklisten, Verschnittoptimierung, CAM („1.000 CAM-Integrationen“ laut Anbieter), Renderings | Originaldaten von Blum, Häfele, Hettich, Egger u. a. Seit 2025 Blum-Bibliothek mit Fünf-Zonen-Layouts | Layoutvorlagen (I, U, Insel). Keine Regelprüfung belegt | Q12 |
| **PYTHA** | 3D-CAD für die Holzverarbeitung, auch Luxusküchen | Stückliste, Säge- und Nesting-Optimierung, CNC-Schnittstelle, automatische Konstruktionsweisen | Teilebibliothek (Beschläge, Profile) | – | Q13 |
| **imos iX** | imos AG, Herford (seit 1993). Tischlerei bis Industrie | Parametrisches 3D-CAD, Raum- und POS-Konfigurator, CNC direkt aus CAD, MES, KI-Rendering | – | – | Q14 |
| **Polyboard** | Boole & Partners (FR). Möbel- und Korpusbau | Parametrischer Korpusbaum, Zuschnitt und Nesting, Bohrbilder, CNC-Postprozessoren, Kauflizenz | – | Keine Küchenlogik | Q15 |
| **SketchUp + Plugins** | Allrounder | OpenCutList (kostenlos, Zuschnittlisten), GKWare Cab Maker (Korpusse aus Presets), CabMaker32 | Keine Herstellerdaten | – | Q16 |
| **IKEA-Planer** | Endkunden. Systemgebunden (METOD, ENHET, KNOXHULT) | Manuelles Platzieren. Sonder-Arbeitsplatten nur nach Prüfung durch Fachberater | IKEA-Sortiment | Keine dokumentierte Prüfung | Q17 |

**Datenstandard:** IDM („Integriertes Datenmodell“) stammt vom Daten Competence Center e.V. (DCC, Herford) und existiert seit 2002 [Q18].
Es dient dem Austausch von Stamm-, Katalog- und Bestelldaten zwischen Industrie, Handel und Softwarehäusern. Laut SHD-Artikel (2013) ist die Küche die
Ausnahme mit funktionierender Stammdaten-Durchgängigkeit [Q18]. Die Details zu IDM-Küche-Inhalten (Planungs- und Prüfregeln) sind öffentlich nicht belegt (`?`).

**Raster der Industrie (Beispiel nobilia) [Q19]:** Korpushöhen fest (Unterschrank 720 mm, XL 792; Wandschrank 360 bis 864 mm), Breitenraster 20 bis 120 cm,
Sockel 20/70/100/150/200 mm (Standard 150), Eckpassstück 50 bis 170 mm, Passleisten 100/200 mm. 20-mm-Sockel sind „nicht in Aktivbereichen“ erlaubt.

**Was der Markt gut macht:** Katalog, Preis, Angebot und Bestellung in einem Fluss; herstellergeprüfte Typenlogik; Prüfberichte vor der Bestellung;
Rendering für den Verkauf. Tischler-CAD (PYTHA, imos, Palette, Polyboard) liefert Konstruktion, Stückliste und CNC.

**Lücke für ein Studio wie unseres:**
1. Die Intelligenz der Handelssoftware hängt an **Typennummern und Rastern**. Prüfregeln kommen vom Hersteller und greifen nur bei Katalogtypen.
   Freie mm-Maße fallen aus diesem Raster heraus.
2. Tischler-CAD ist **konstruktionsstark, aber planungsdumm**. Es kennt keine Zonen, keine Ergonomie, keine Geräte-Einbauregeln, keine Anschlusslogik
   und hat keinen Prüfbericht. Belegt sind dort nur Layoutvorlagen.
3. **Kein Werkzeug kombiniert** freie Geometrie, ein regelbasiertes Prüfregister auf Geometrie statt auf Typen, Variantenvorschläge
   mit Bewertung und eine Übergabe an das eigene CAD (z. B. Fusion).
4. Hersteller-Prüfservices sind **Black Boxes** (pay-per-use, proprietär). Ein offenes, erklärbares Regelregister mit Quellenangabe je Regel wäre ein Unterschied.

## 2. Normen und Richtwerte

### 2.1 DIN EN 1116:2018-03 (Koordinationsmaße Küche)
Die Norm ersetzt DIN EN 1116:2004-09 und ist aktuell. Sie gilt nicht für gewerbliche Küchen [Q20]. Laut Inhaltsverzeichnis regelt sie [Q20]:
- Arbeitsplattenhöhe und Nischenhöhe für Unterbaugeräte
- Abstand von der Arbeitsplatte zum Hängeschrank
- Sockel, Tiefen, Überstand, Breiten, Blenden
- Einbau und Anschluss von Geräten

Werte laut CATAS-Zusammenfassung (Juni 2018) [Q21]:
- **Arbeitshöhen fest:** 850, 900, 950 mm. Im Text steht „+50 mm“; das Format ist verstümmelt (`?`).
- **Nischenhöhe Unterbaugeräte:** ≥ 820, 870 bzw. 920 mm.
- **Sockel:** ≥ 80 mm, bei vertikal beweglichen Möbeln ≥ 100 mm nach EN 14749.
- **Arbeitsplatte bis Unterkante Hängeschrank:** ≥ 450 mm.
- **Arbeitsplattentiefe:** ≥ 600 mm.
- **Hängeschranktiefe:** 310 bis 400 mm.
- **Nischenbreiten:** 450 und 600 mm (Außenmaß). Möbelnennbreiten 400, 500, 600 und 900 mm.
- **Kochfeld bis Haube:** Die Norm nennt keinen Wert und verweist auf den Hersteller.

Weitere Normen:
- **DIN 68930:2025-07** (Gebrauchstauglichkeit von Küchen- und Badmöbeln) ist eine Prüfnorm, keine Planungsnorm. Neu ist eine Prüfung des Fugenbilds im Einbauzustand [Q23].
- **Alte „DIN“-Stellflächen** (Ratgeber, Norm nicht benannt, vermutlich DIN 18022, `N-zurück`): Spüle 90, Arbeitsfläche 60, Herd 60 und Abstellfläche 30 cm,
  zusammen 240 cm. Zweite Arbeitsfläche 120 cm [Q38].

### 2.2 Elektro: DIN 18015-2:2021-10, DIN 18015-3, RAL-RG 678
DIN 18015-2:2021-10 regelt die Mindestausstattung (Tabelle 2 nach Räumen) [Q25]. Die Küchenspalte wurde aus dem Hager-Tipp 21 rekonstruiert [Q26].
Die Spaltenzuordnung im PDF-Text ist **nicht eindeutig** (`?`), daher vor Verwendung im Original prüfen:

| Ausstattung Küche (Ausstattungswert 1 = DIN) | Anzahl |
|---|---|
| Beleuchtungsanschlüsse | 2 |
| Steckdosen allgemein | 3 |
| Steckdosen **je 1,2 m Arbeitsflächenbreite** | 2 |
| Steckdose IuK/RuK | 1 |
| Kühl-/Gefriergerät, Dunstabzug | je 1 |
| Eigene Stromkreise: Elektroherd (3 × 230 V), Mikrowelle/Dampfgarer, Geschirrspüler | je 1 |

- Baunetzwissen nennt „Dreifachsteckdosen im Abstand von 1,2 m“ über der Arbeitsplatte [Q27].
- Die HEA nennt eigene Stromkreise auch für den Backofen [Q29].
- RAL-RG 678 definiert die Ausstattungswerte 1 bis 3 und 1plus bis 3plus. t-online nennt 17 Steckdosen (Ausstattungswert 1) bzw. 21 (Ausstattungswert 2) für eine Beispielküche [Q28].
  Diese Zahl ist abhängig von der Arbeitsflächenlänge und nicht übertragbar (`?`).
- **DIN 18015-3 (Installationszonen)** [Q30]:
  - Waagerechte Zonen 30 cm breit, beginnend 15 cm über dem Boden und 15 cm unter der Decke.
  - Senkrechte Zonen 20 cm breit, ab 10 cm von Ecken, Türen und Fenstern.
  - **Mittlere Zone über Arbeitsflächen: 100 bis 130 cm**, Vorzugshöhe 115 cm. Vor 2007 lag sie bei 90 bis 120 cm.
  - Relevant als **Bohrverbotszone** für Hängeschrank-Befestigung und Nischenrückwand.

### 2.3 Ergonomie: Arbeitshöhe
- **AMK (2011):** Die ideale Arbeitshöhe liegt **10 bis 15 cm unter der Ellenbogenhöhe**. ±5 cm sind tolerierbar, wenn mehrere Personen die Küche nutzen.
  Das Kochfeld darf tiefer liegen (Topfrand ist die Arbeitsebene), die Spüle höher (Spülboden ist die Arbeitsebene) [Q31]. `V`
- **Küche&Co (2016):** Kochen ≥ 20 cm unter dem Ellenbogen. Spüle 10 bis 15 cm unter dem Ellenbogen, gemessen am Spülboden [Q32]. `R`
- **Neff:** Ellenbogenhöhe − 15 cm (Beispiel: 114 → 99 cm). Üblicher Standard ca. 92 cm.
  Hochgebauter Geschirrspüler mit Unterkante 5 bis 10 cm unter der Arbeitshöhe [Q33]. `H/R`

### 2.4 Zonen, Arbeitsflächen, Arbeitsdreieck
- **Fünf Zonen** (Blum DYNAMIC SPACE, 2005): Bevorraten, Aufbewahren, Spülen, Vorbereiten, Kochen/Backen.
  Behauptete Ersparnis bis 20 % Wege und Zeit; die Zahl ist nicht unabhängig belegt [Q35].
  - Aufbewahren liegt neben dem Spülen, Vorbereiten zwischen Spüle und Herd [Q36].
  - Rechtshänder planen von links nach rechts: Kühlen → Spüle → Herd. Linkshänder spiegeln [Q37].
- **Hauptarbeitsfläche Spüle–Kochfeld:** ≥ 80 cm (Neff) bzw. ≥ 90 cm (Plana, Küche&Co). Optimal 120 cm, Neff nennt 120 bis 140 cm [Q32,Q34,Q36].
  **Ablage neben dem Kochfeld ≥ 30 cm** [Q34].
- **Arbeitsdreieck:** Ursprung in Arbeitsstudien der 1920er und an der University of Illinois (1946–49) [Q45].
  - NKBA: Summe ≤ 7,9 m (26′), jeder Schenkel 1,2 bis 2,7 m [Q44]. `US`
  - Hindernisse ≤ 30 cm Einragung in einen Schenkel. Kein Hochschrank zwischen zwei Punkten [Q45].
- **Landeflächen (NKBA)** [Q44]:
  - Spüle: 610 mm auf der einen, 457 mm auf der anderen Seite.
  - Kochfeld: 305 und 381 mm.
  - Kühlschrank: 381 mm an der Griffseite.
  - Geschirrspüler: Kante ≤ 914 mm von der Spüle, 533 mm Stehraum an Eckhindernissen. `US`

### 2.5 Durchgänge und Barrierefreiheit
- **Gegenüberliegende Zeilen:** ≥ 1,20 m, ausgelegt auf 60 cm Plattentiefe; die Norm wird nicht genau benannt [Q38]. `R`
- **NKBA:** Laufweg ≥ 914 mm. Arbeitsgang ≥ 1067 mm (eine Person) bzw. ≥ 1219 mm (mehrere) [Q44]. `US`
- **DIN 18040-2:2011-09** ist laut DIN aktuell; eine Neuausgabe ist nicht belegt [Q46]. Werte laut Sekundärquellen:
  - Bewegungsfläche 120 × 120 cm, für Rollstuhl 150 × 150 cm. Gleiche Tiefe vor Küchenmöbeln [Q47,Q48]. `N`
  - Übereck-Anordnung von Herd, Arbeitsplatte und Spüle **empfohlen**. Unterfahrbarkeit „sollte möglich sein“ [Q47].
  - LBS/Verbraucherzentrale [Q48], ohne Zuordnung zu einem Normabschnitt (`?`):
    - Greifbereich der Einbaugeräte 40 bis 140 cm.
    - Unterfahrbare Arbeitsfläche: Oberkante ca. 80 cm, Unterkante 67 cm, Breite ≥ 90 cm (besser 120).
    - Sockelzone 30 bis 40 cm hoch und 20 cm tief.
    - Hängeschrank ca. 30 cm über der Arbeitsfläche.

### 2.6 Geräte-Einbau (Herstellerangaben, nur Beispiele)
- **Haube über Kochfeld (Neff) [Q39]:** Gas 65 cm ab Topfträger. Elektro/Induktion je Haubentyp: Wand-/Inselhaube 55, Schräghaube 45, Unterbauhaube 65,
  Zwischenbauhaube/Lüfterbaustein 50, Flachschirm/Designhaube 43 cm. Die Seite widerspricht sich („45 cm nie unterschreiten“ vs. 43 cm, `?`).
- **Haube, weitere Quellen:** Coolblue Gas ≥ 65, Elektro ≥ 55, max. 80 cm [Q40]; Konsument Elektro 65, offene Flamme 90 cm [Q38].
  → **Widersprüche; immer die Geräteanleitung verwenden.**
- **Kochfeld:**
  - Gorenje-Induktion (60 cm): ≥ 40 mm zur Schrankkante. Hängeschrank oder Haube ≥ 500 mm, sonst gilt die Haubenanleitung. Fuge ≥ 2 mm [Q41].
  - Bosch-Induktion (PIE…): 65 mm von Oberkante Arbeitsplatte bis Oberkante Schublade, Zwischenboden empfohlen [Q42].
    Über Geschirrspüler 60/65 mm mit Pflichtzubehör, über Backofen ≥ 5 mm Lüftungsspalt.
    Arbeitsplatte ≥ 20 mm (bei Geschirrspüler 20 bis 40 mm, bei Backofen ≥ 30 mm). Möbel ≥ 90 °C hitzebeständig.
- **Geschirrspüler unter Kochfeld (BSH):** Abstand ≥ 60 mm (Gas, Induktion) bzw. 65 mm (Glaskeramik).
  Kein Einbau unter oder über Backofen ohne Herstellerfreigabe [Q43]. Neff: nicht direkt unter Backofen oder Kochfeld [Q33].

## 3. Automatische Planung: Forschung und Praxis

| Arbeit | Ansatz | Erkenntnis für uns |
|---|---|---|
| **Make it Home** (ACM TOG/SIGGRAPH 2011) [Q49] | Priors aus Beispielszenen, Kostenfunktion (u. a. Sichtbarkeit, Zugänglichkeit), Simulated Annealing / Metropolis-Hastings | Kein signifikanter Unterschied zu Designerlayouts bei der Funktionalität. Kostenfunktion plus stochastische Suche funktioniert |
| **Interactive Furniture Layout** (SIGGRAPH 2011) [Q50] | Gestaltungsrichtlinien als Dichtefunktion, MCMC-Sampling auf der GPU, **Vorschläge während der Nutzer plant** | 18 Laien in 5 Räumen: In 4 Räumen wurden Layouts mit Vorschlägen signifikant bevorzugt. **Mensch bleibt Entscheider** |
| **Küchen-Patent** (US 2010/0245351, eingereicht 2010) [Q51] | **Küche:** Reservierte Zonen (Türen, Fenster, Heizkörper) → freie Teilzonen → Templates (I, L, U, II, Insel) → Pflichtelemente nach Faustregeln (Dreieck, Mindestabstände, Wasseranschluss, Fenster) → Auffüllen per Zielfunktion (Längenrest plus gewichtete Strafen, harte Regeln mit Maximalgewicht) → Partikelschwarm → mehrere Lösungen zum Vergleich. Meldet die verletzte Regel, wenn keine Lösung existiert | Nahezu die Blaupause für „Regeln + Solver + Bewertung + Mensch wählt“. Allerdings katalog- und rasterbasiert |
| **Kitchen Layout Generation as an Optimization Problem** (Bachelorarbeit, Karls-Universität Prag, 2025) [Q52] | Formales Modell „Kitchen Layout Problem“ mit MILP und MiniZinc | Gurobi und **CP-SAT (Open Source) lösen zuverlässig in Zehnersekunden**, CP-SAT meist schneller |
| **Holodeck** (AI2/UPenn u. a., 2023/24) [Q53] | GPT-4 wählt qualitative Relationen (Rand, nahe, gegenüber, ausgerichtet …) → DFS- oder MILP-Solver (Gurobi). Weiche Constraints | LLM liefert **Absichten, nicht Koordinaten**. Raster und 90° begrenzen die Präzision |
| **I-Design** (ETH Zürich, 2024) [Q54] | Fünf LLM-Agenten → Szenengraph mit Korrektur-Agent → Backtracking-Platzierung | Konsistenzprüfung des Graphen vor dem Solver lohnt sich. Scheitert in vollen Räumen |
| **LayoutVLM** (Stanford/Google, 2024/25) [Q55] | Das VLM liefert Startposen plus differenzierbare Relationen → Gradientenoptimierung mit Kollisionskosten | Hybrid aus LLM-Vorschlag und Optimierer schlägt reine LLM-Ausgabe |
| **DirectLayout** (2025) [Q56] | LLM erzeugt numerische Layouts direkt (Chain-of-Thought, 3D-Front) | Ohne Solver keine Garantien |
| **LEGO-Eval** (2025) [Q57] | Benchmark für feingranulare Constraints | Beste Verfahren erfüllen **höchstens 10 %** der Detail-Constraints. **LLM allein ist für mm-Planung ungeeignet** |

**Was praktisch funktioniert:**
- Eine Küche ist überwiegend **eindimensional entlang von Wandsegmenten** (Ketten von Korpusbreiten), dazu Inseln und Ecken.
- Das passt ideal zu **ganzzahliger Constraint-Programmierung in mm** (CP-SAT, MiniZinc). Gleichungen wie Summe der Breiten plus Blenden gleich Wandlänge sind exakt lösbar, auch ohne Raster.

**Architektur-Empfehlung:** (1) Mensch oder LLM (aus Briefing) liefert **strukturierte Vorgaben**: Fixmaße, Materialien, Geräteliste, Prioritäten.
(2) Regelregister übersetzt sie in harte und weiche Constraints. (3) Solver erzeugt **N Varianten**. (4) Bewertung mit erklärbaren Teilscores
(Ergonomie, Zonenfluss, Stauraum, Fertigung, Kosten). (5) Prüfbericht. (6) **Mensch wählt und fixiert**, dann Iteration.
Das LLM übersetzt und erklärt nur; es setzt nie Koordinaten ohne Solver und Prüfer.

## 4. Kollisions- und Plausibilitätsprüfungen

**So löst es Profisoftware:**
- **KPS protect:** Kollisions-, Öffnungskollisions- und Abstandsprüfungen. Hinweise zu Planbarkeit, Sicherheit, Ergonomie und Vollständigkeit [Q4].
  Die Regeln stammen „aus Planungsvorgaben und Erfahrungswerten“ und werden laufend erweitert; herstellerspezifische Regeln sind mit Herstellern geplant.
  Der Anbieter behauptet, ~40 % der Küchenaufträge seien fehlerhaft und eine Reklamation koste ~350 €. Das ist eine Anbieterangabe (`?`).
- **Winner Flex Bestellkontrolle:** Der Hersteller-Service prüft das Design und liefert eine Liste aus **Fehler / Warnung / Hinweis**, sortiert nach Positionsnummer,
  mit Erklärtext, Beispielbildern und Schulungslinks. Die Prüfung ist jederzeit wiederholbar [Q8].
- **Gemeinsames Muster:** regelbasiert (keine KI), drei Schweregrade, Bezug auf das Element, Erklärung mit Quelle, Lauf vor der Bestellung und während der Planung.

**Typische Prüfklassen** (Werte siehe Abschnitt 2; „H“ heißt, der Wert kommt aus den Gerätedaten):
1. **Statische Kollision:** Korpus, Gerät, Wand, Fenster, Heizkörper, Rohr oder Schräge überschneiden sich.
2. **Öffnungskollision (Hüllkörper):** Tür- und Auszugsweg gegen Griffe, Nachbarfronten, Wand, Fensterbank; Geschirrspüler- und Backofentür gegen Griffe im Eck;
   Kühlschranktür (Öffnungswinkel, Scharnierseite) gegen Wand, Fächer brauchen meist ≥ 90° (H); Klappen gegen Haube und Decke.
3. **Eckblockade:** Fronten oder Griffe beider Eckschenkel blockieren sich → Passstück/Blende nötig (nobilia: Winkelpassstück 50 bis 170 mm [Q19]).
4. **Vertikale Abstände:** Kochfeld zu Haube (H), Kochfeld zu Hängeschrank, Arbeitsplatte zu Hängeschrank (≥ 450 mm nach EN 1116).
5. **Seitliche Abstände:** Kochfeldausschnitt zu Hochschrank, Wand oder Schrankkante (H, z. B. ≥ 40 mm); Ablage neben Kochfeld ≥ 300 mm; Spüle zu Ecke/Wand.
6. **Unterbau-Kompatibilität:** Kochfeld über Geschirrspüler, Backofen oder Schublade (Abstand, Zwischenboden, Lüftungsspalt, Plattenstärke, H); kein GS unter Backofen.
7. **Lüftung:** Sockel- und Rückwandöffnungen, Rückwandabstand, Schlitze für Einbaukühlgeräte und Backofen (H).
8. **Wärme/Gas:** Material ≥ 90 °C an Kochstellen (H). Gas: Haube ab Topfträger (H); Abstände nach TRGI **nicht recherchiert**.
9. **Anschlusszonen:** Wasser/Abfluss im Spülen- bzw. GS-Bereich (Toleranz einstellbar); Herdanschluss erreichbar; Steckdosen nicht hinter festen Geräten;
   Befestigungen nicht in der Installationszone 100 bis 130 cm.
10. **Elektro-Mindestausstattung:** Steckdosen je 1,2 m Arbeitsfläche; eigene Stromkreise für Herd, Mikrowelle/Dampfgarer, GS (`?`, siehe 2.2).
11. **Ergonomie:** Arbeitshöhe ≈ Ellenbogen − 100…150 mm; Kochebene tiefer, Spülboden höher; Hauptarbeitsfläche ≥ 800/900 mm; Zonen nach Händigkeit; Greifhöhen.
12. **Wege:** Gang zwischen Zeilen/Insel ≥ 1200 mm (barrierefrei 1500). Arbeitsdreieck nur als **weicher** Score.
13. **Vollständigkeit:** Sichtseiten, Blenden, Passleisten, Sockel, Abschlüsse, Plattenstöße vorhanden; Fugenbild konsistent; jedes Gerät hat Nische und Anschluss.
14. **Fertigbarkeit (Tischler):** Plattenformate und APL-Längen, Stoß nicht über Spüle/Kochfeld; Beschlag-Mindestbreiten (Auszug, Scharnier);
    Wandtoleranzen und Winkelabweichung, Ausgleich über Passleiste.

## 5. Aufmaß: Werkzeuge und Datenfluss

| Werkzeug | Prinzip | Export / Daten | Bemerkung | Q |
|---|---|---|---|---|
| **Leica DISTO Plan (Sketch Plan)** | Laserdistanzmesser über Bluetooth/WLAN. Skizze von Hand, Maße werden auf Linien übertragen, Fang- und Verdeckte-Ecke-Werkzeuge | JPG, PDF (Pro nur im Abo), **DXF/DWG 2D und 2D plus Höhe** | Kein CSV genannt. Kein automatischer Grundriss | Q60 |
| **magicplan** | Smartphone (AR/LiDAR), optional Laser | PDF, SVG, JPG, PNG, **DXF (ohne Maße!)**, IFC, OBJ, **USDZ** (einziges 3D-Format mit Objekten), CSV/PDF-Statistik, XLS-Kalkulation | Laser-Kopplung auf der Exportseite nicht belegt. Anbindung an 2020 Design | Q61,Q11 |
| **Flexijet 3D + FlexiCAD** | Motorisierter Laserkopf, zeichnet beim Messen direkt in 3D-CAD | **DWG/DXF (3D)**. Projiziert CAD-Punkte zurück an die Wand | „Unter 1 mm“ ist eine Händlerangabe ohne Prüfmethode (`?`) | Q62 |
| **Apple RoomPlan (API, iOS 16+)** | LiDAR-Scan → `CapturedRoom` | Daten: `walls`, `doors`, `windows`, `openings`, `floors`, `objects`, `sections` (Surface/Object mit `transform` 4×4, `dimensions` als Bounding-Box, `category`, `confidence`). **Encodable/Decodable → JSON**. USD(Z)-Export `.parametric` (Größen änderbar), `.mesh` oder `.model`, optional mit `metadataURL` | 16 Objektkategorien, darunter `dishwasher`, `oven`, `refrigerator`, `sink`, `stove`, `storage`, `washerDryer`. **Apple nennt keine Genauigkeit.** Forum-Erfahrung „oft ~15 cm“ ist anekdotisch | Q58,Q59 |
| **CARAT EasyRoom / Graebert SiteMaster Kitchen** | Aufmaß-App bzw. Aufmaß-Import nach CARAT | Ecken des CARAT-Grundrisses werden per „Magnet“ auf die Aufmaßecken gezogen. Grüne Prüfmarke je Wand | Zeigt das Abgleichsproblem zwischen Aufmaß und Planung | Q1,Q63 |

**Vom Aufmaß zum Planungsbogen (Empfehlung):**
- **Zweistufig:** (1) RoomPlan/magicplan liefert Topologie und Grobmaß (Wände, Öffnungen, Bestandsgeräte). (2) **Laser-Kontrollmaße** (DISTO) überschreiben
  kritische Maße: Wandlängen auf Arbeits- und Sockelhöhe, Diagonalen/Winkel, Lot und Ebenheit, Fensterbrüstung, Lage von Rohren und Dosen.
- **Normalisiertes Raum-JSON:** Wand-Polygon in mm mit **Messquelle und Unsicherheit je Maß**; Öffnungen mit Brüstung/Sturz; Anschlüsse (Wasser kalt/warm,
  Abfluss, Herd 400 V, Dosen, Gas, Abluft); Hindernisse (Heizkörper, Rohre, Schrägen); Bohrverbotszonen.
- RoomPlan-JSON direkt mappen (`walls`/`openings` → Polygon/Öffnungen, `objects` → Bestand). DXF/DWG (DISTO, Flexijet) per Layer-Konvention importieren.
  Messwerte bleiben „nicht verifiziert“, bis Kontrollmaße vorliegen.

## (a) Kern-Grundwerte mit Quelle

| Wert | Bereich / Default | Quelle | Status |
|---|---|---|---|
| Arbeitshöhe | Ellenbogen − 100…150 mm, Toleranz ±50 mm | AMK 2011 [Q31] | V |
| Kochebene / Spülboden | Kochen ≥ 200 mm unter Ellenbogen; Spülboden 100–150 mm darunter | Küche&Co [Q32], AMK-Tendenz [Q31] | R/V |
| Feste Arbeitshöhen (Industrie) | 850 / 900 / 950 mm | EN 1116:2018 via CATAS [Q21] | N, Format `?` |
| Nischenhöhe Unterbaugeräte | ≥ 820 / 870 / 920 mm | EN 1116 [Q21] | N |
| Sockelhöhe | ≥ 80 mm (beweglich ≥ 100 mm); 20 mm nicht in Aktivbereichen | EN 1116 [Q21]; nobilia [Q19] | N / H |
| Arbeitsplattentiefe | ≥ 600 mm | EN 1116 [Q21] | N |
| Hängeschranktiefe | 310–400 mm | EN 1116 [Q21] | N |
| Arbeitsplatte → Unterkante Hängeschrank | ≥ 450 mm (Norm); Praxis 500–650 mm; Rollstuhl ~300 mm | EN 1116 [Q21]; Konsument [Q38]; LBS [Q48] | N / R |
| Hauptarbeitsfläche Spüle–Kochfeld | ≥ 800–900 mm, optimal 1200 mm | Neff [Q34], Plana [Q36], Küche&Co [Q32] | R |
| Ablage neben Kochfeld | ≥ 300 mm (NKBA: 305 / 381 mm) | Neff [Q34]; NKBA [Q44] | R / US |
| Ablage an der Spüle | 610 / 457 mm | NKBA [Q44] | US |
| Geschirrspüler ↔ Spüle | ≤ 914 mm Kantenabstand | NKBA [Q44] | US |
| Arbeitsdreieck | Summe ≤ 7,9 m, Schenkel 1,2–2,7 m (weicher Score) | NKBA [Q44], Wikipedia [Q45] | US |
| Gang zwischen Zeilen | ≥ 1200 mm; Rollstuhl 1500 mm; NKBA 1067 / 1219 mm | Konsument [Q38]; DIN 18040-2 [Q47]; NKBA [Q44] | R / N / US |
| Bewegungsfläche barrierefrei | 1200 × 1200 / 1500 × 1500 mm | DIN 18040-2:2011-09 [Q46–Q48] | N |
| Greifbereich Einbaugeräte (barrierefrei) | 400–1400 mm | LBS/VZ RLP [Q48] | R `?` |
| Unterfahrbarkeit | Oberkante ~800, Unterkante ~670 mm, Breite ≥ 900 mm | LBS/VZ RLP [Q48] | R `?` |
| Steckdosen über Arbeitsfläche | 2 je 1,2 m Breite + 3 allgemein (DIN, Mindestausstattung) | DIN 18015-2:2021-10 via Hager [Q26], Baunetz [Q27] | N `?` |
| Eigene Stromkreise | Herd (3 × 230 V), Mikrowelle/Dampfgarer, Geschirrspüler, ggf. Backofen | Hager [Q26]; HEA [Q29] | N |
| Installationszone über Arbeitsfläche | 1000–1300 mm, Vorzugshöhe 1150 mm | DIN 18015-3 via [Q30] | N (sekundär) |
| Haube ↔ Kochfeld | Gas 650 mm ab Topfträger; Elektro/Induktion 430–650 mm je Haubentyp; max. ~800 mm | Neff [Q39], Coolblue [Q40] | H, **gerätespezifisch** |
| Kochfeld ↔ Schrankkante seitlich | z. B. ≥ 40 mm | Gorenje [Q41] | H, gerätespezifisch |
| Kochfeld über Schublade / GS / Backofen | 65 / 60–65 / ≥ 5 mm Lüftung | Bosch PIE [Q42]; BSH [Q43] | H, gerätespezifisch |
| Hitzebeständigkeit Möbel | ≥ 90 °C | Bosch [Q42] | H |

Bei **Herstellerwerten** speichert der Kern nur die **Regel** (z. B. „Haubenabstand ≥ Geräteangabe“) und einen **Fallback mit Warnung**.
Die Zahl kommt aus den Gerätedaten des Projekts.

## (b) Typische automatische Prüfregeln (Kurzregister)

Format: ID · Regel · Schwere (F = Fehler, W = Warnung, H = Hinweis) · Datenquelle

1. KOL-01 · Keine Volumenüberschneidung Korpus/Gerät/Raum · F · Geometrie
2. KOL-02 · Öffnungshüllkörper (Tür, Auszug, Klappe, Gerätetür) frei von Griffen, Fronten, Wand, Fensterbank und Haube · F · Beschlag + Griffdaten
3. KOL-03 · Eckblockade: Mindest-Passstück so, dass Fronten und Griffe beider Schenkel öffnen · F · Eckgeometrie + Griffüberstand
4. KOL-04 · Kühlgerätetür ≥ 90° (bzw. Herstellerwinkel) öffnbar, Fächer entnehmbar · W · H
5. ABS-01 · Haube ↔ Kochfeld ≥ Herstellerwert (Gas ab Topfträger) · F · H (Fallback 650 mm, W)
6. ABS-02 · Arbeitsplatte ↔ Unterkante Hängeschrank ≥ 450 mm, Ziel nach Studio-Setup · F/W · EN 1116 + Setup
7. ABS-03 · Kochfeldausschnitt ↔ Hochschrank/Wand/Schrankkante ≥ Herstellerwert · F · H
8. ABS-04 · Ablage neben Kochfeld ≥ 300 mm beidseitig bzw. einseitig · W · Richtwert
9. GER-01 · Unterbau unter Kochfeld kompatibel (Abstand, Zwischenboden, Plattenstärke) · F · H
10. GER-02 · Kein Geschirrspüler unter/über Backofen, Kochfeld nur mit Freigabe · F · H
11. GER-03 · Lüftungsquerschnitte bei Einbaugeräten (Sockel, Rückwand, Schlitz) · F · H
12. GER-04 · Nischenmaß ≥ Geräte-Einbaumaß (B/H/T) inklusive Toleranz · F · H
13. ANS-01 · Spüle und Geschirrspüler innerhalb der Wasser-/Abfluss-Zone (Toleranz aus Setup) · W · Aufmaß
14. ANS-02 · Jedes Elektrogerät hat einen erreichbaren Anschluss bzw. eigenen Stromkreis · W · Aufmaß + DIN 18015-2
15. ANS-03 · Steckdosen über Arbeitsfläche ≥ Mindestausstattung, nicht hinter festen Geräten · H/W · DIN 18015-2 `?`
16. ANS-04 · Befestigungen nicht in der Installationszone 1000–1300 mm ohne Leitungsortung · W · DIN 18015-3
17. ERG-01 · Arbeitshöhe im Band Ellenbogen − 100…150 mm · W · Projekt (Nutzerdaten)
18. ERG-02 · Hauptarbeitsfläche zwischen Spüle und Kochfeld ≥ 800 mm (Ziel ≥ 900/1200) · W · Richtwert
19. ERG-03 · Zonenreihenfolge passend zur Händigkeit (Kühlen → Spülen → Vorbereiten → Kochen) · H · Projekt
20. ERG-04 · Arbeitsdreieck im Bereich (Score, nicht blockierend) · H · NKBA
21. ERG-05 · Häufig genutzte Geräte im Greifbereich (z. B. 400–1400 mm, Backofen-Oberkante ~ Schulterhöhe) · H · Projekt
22. WEG-01 · Gang zwischen Zeilen/Insel ≥ 1200 mm (barrierefrei 1500) · W/F · Setup
23. WEG-02 · Raumtür schlägt nicht in Geräte- oder Auszugsbereich · W · Aufmaß
24. VOL-01 · Sichtseiten, Blenden, Passleisten, Sockel, Abschlüsse vollständig · W · Stückliste
25. VOL-02 · Jedes Gerät in der Geräteliste ist platziert, jede Nische hat ein Gerät · F · Projekt
26. FER-01 · Arbeitsplatten- und Plattenlängen ≤ Materialformat, Stoß nicht im Spülen-/Kochfeldausschnitt · F/W · Materialdaten (Setup)
27. FER-02 · Korpus- und Frontbreiten ≥ Beschlagsminimum (Auszug, Scharnier) · F · Beschlagsdaten
28. FER-03 · Fugenbild konsistent (Fugenmaß aus Setup) · H · Setup
29. TOL-01 · Kritische Maße mit Unsicherheit > Schwelle (z. B. nur Scan) → Nachmessen anfordern · W · Aufmaß-Metadaten
30. SIC-01 · Kochfeld nicht unter einem öffnenden Fenster, keine Steckdose direkt über dem Kochfeld · W · Praxisregel (`?`, keine Normquelle gefunden)

## (c) Positionierung / Lücke

- **Markt:** **Handel** = Typen, Raster, Preis, Bestellung, Herstellerprüfung (CARAT, KPS, Winner Flex). **Tischler-CAD** = Konstruktion, Stückliste, CNC
  (PYTHA, imos, Palette CAD, Polyboard). **Endkunde** = einfache Konfiguratoren (IKEA).
- **Lücke:** **Planungsintelligenz für freie, mm-genaue Tischlerküchen**: offenes **Regelregister auf Geometrie** (Quelle und Status je Regel),
  Varianten aus einem Constraint-Solver, erklärbarer Prüfbericht (F/W/H wie die Bestellkontrolle), Übergabe an das Studio-CAD.
- **Abgrenzung:** Kein Katalog- und Bestellsystem, keine Konkurrenz zu CNC-CAM. Wir sind die Schicht **davor**: vom Aufmaß und Briefing zum geprüften Planungsbogen.
- **Belegte Stützen:** Prüfberichte sind etabliert und werden bezahlt (pay-per-use) [Q4,Q8]; Regeln + Solver + Bewertung + Wahl ist in Patent und Forschung
  erprobt [Q50–Q52]; reine LLM-Layouts verfehlen Detail-Constraints [Q57].

## (d) Offene Fragen

1. **Normoriginale beschaffen:** DIN EN 1116:2018 (Arbeitshöhen-Format, Breitentabellen), DIN 18015-2:2021-10 Tabelle 2 (Küchenspalte), DIN 18040-2 (Küchenabschnitt).
   Prüfen, ob das Studio Zugang über DIN Media oder die Kammer hat.
2. **Gas:** Abstände nach TRGI bzw. Hersteller zu Wand, Hochschrank und Fenster wurden nicht recherchiert. Plant das Studio überhaupt Gas?
3. **Gerätedaten:** Woher kommen Einbaumaße und Abstände? Manuell aus Anleitungen, über Hersteller-Planungsdaten (z. B. BSH, V-ZUG Planungshilfen) oder über IDM? Ist IDM für Nicht-Händler zugänglich?
4. **Beschlagsdaten:** Blum, Hettich und Häfele stellen Daten für Palette CAD und andere bereit. Gibt es offene Formate für eigene Mindestbreiten- und Öffnungsprüfungen?
5. **RoomPlan-Genauigkeit:** Kein belastbarer Wert gefunden. Eigener Test nötig: 3 bis 5 Küchen scannen und gegen DISTO-Maße vergleichen.
6. **Ergonomie-Daten:** Erfasst das Studio Ellenbogenhöhe und Händigkeit der Hauptnutzer im Briefing? Die Kernregel ERG-01 braucht diese Daten.
7. **Studio-Setup statt Kern:** Bevorzugte Abstände (Hängeschrank 500/550/600?), Fugenmaß, Sockelhöhe, Plattenformate und Griffkonzept (grifflos?) gehören ins Nutzer-Setup.
8. **Rechtslage:** Darf das System bei Elektro und Gas nur Hinweise geben? Haftung und Abgrenzung zur Fachplanung durch Elektro- bzw. Gasinstallateur klären.
9. **Solver-Wahl:** CP-SAT (Open Source, ganzzahlig in mm) ist naheliegend [Q52]. Validieren mit 3 bis 5 realen Studioküchen als Testfälle.

---
## Quellen
- Q1 MHK – CARAT: https://www.mhk.de/en/services/carat/  ·  Q2 MHK – CARAT & Bosch HPL+ (11.07.2022): https://www.mhk.de/en/news/11072022-carat-and-bosch-increase-user-friendliness-for-kitchen-planners
- Q3 softwareABC24 – KPS: https://www.softwareabc24.de/kuechenhandel-software/kps  ·  Q4 KPS protect: https://kuecheundbadforum.de/files/article/b5397bae019efe8d489824fe207dcaba.pdf · https://kuecheundbadforum.de/files/article/7274627ecc9c9ecd217342b23828dc70.pdf
- Q5 Möbelmarkt – KPS.MAX: https://db.moebelmarkt.tv/media/orig/09a6c648a97713150a0249c203efced3.pdf  ·  Q6 SHD übernimmt ArtiCAD (2016): https://kandbnews.co.uk/?p=5383
- Q7 Compusoft – Winner Flex: https://www.compusoftgroup.com/kitchen/which-3d-kitchen-planner-is-right-for-you/  ·  Q8 Winner Flex Bestellkontrolle: https://winnerdesign.support.compusoftgroup.com/hc/de/articles/12596787394193
- Q9 KI-Syndikat – Winner Flex (Drittquelle, teils unbelegt; Aussage „CARAT aus gleichem Haus“ widerspricht MHK → nicht übernommen): https://www.ki-syndikat.de/tools/winner-flex/  ·  Q10 Compusoft + 2020 → Cyncly: https://www.woodshopnews.com/news/compusoft-2020-rebrands-as-cyncly
- Q11 2020 Design Live: https://www.2020spaces.com/?p=281205 · magicplan-Bezug: https://www.2020spaces.com/?p=190585  ·  Q12 Palette CAD: https://www.palettecad.com/en/carpenters-joiners · Blum × Palette CAD (2025): https://www.blum.com/at/de/unternehmen/presse/pressemeldungen-detail_92864.html
- Q13 PYTHA: https://webpreview26.pytha.de/en/application/woodworking/  ·  Q14 imos (Forestsource): https://forestsource.io/software/imos
- Q15 Polyboard (Forestsource): https://forestsource.io/software/polyboard  ·  Q16 SketchUp-Forum Plugins: https://forums.sketchup.com/t/choosing-a-cabinet-and-cut-list-extension-for-sketchup-pro/249996
- Q17 IKEA-Planer: https://www.ikea.com/ch/en/customer-service/knowledge/articles/f9212eab-5e1c-493a-aa38-a84dc0362c8a.html  ·  Q18 IDM/DCC: https://docs.roomle.com/rubens/content-creation/idm/idmabout · SHD-Artikel 2013: https://www.shd.de/fileadmin/data_news/pdf/MK_07_13_S68.pdf
- Q19 nobilia Typenübersicht: https://www.nobilia.de/fileadmin/assets/downloads/nobilia_typenuebersicht_kurztypenliste_DE.pdf  ·  Q20 DIN EN 1116:2018-03: https://www.dinmedia.de/de/norm/din-en-1116/275325871 · Inhaltsverzeichnis: https://www.din.de/de/mitwirken/normenausschuesse/nhm/wdc-beuth:din21:275325871/toc-2688518/download
- Q21 CATAS – UNI EN 1116:2018 (06/2018): https://catas.com/uploads/media/unien1116-eng.pdf  ·  Q22 DIN 68935:2009-10 (Bad): https://www.dinmedia.de/en/standard/din-68935/119396417
- Q23 DIN 68930:2025-07: https://www.dinmedia.de/de/norm/din-68930/391970147  ·  Q24 DIN 18022:1989-11 (zurückgezogen): https://dinmedia.de/en/standard/din-18022/1489302
- Q25 Bauprofessor – DIN 18015-2:2021-10: https://www.bauprofessor.de/news/neue-din-18015-2-elektrische-anlagen-in-wohngebaeuden-teil-2-art-und-umfang-der-mindestausstattung/  ·  Q26 Hager-Tipp 21 (DIN 18015-2:2021-10, Tabelle 2): https://assets.hager.com/step-content/P/HA_39676155/Document/std.lang.all/23DE0014-TIP-HAGERTIPP-21-WEB.pdf
- Q27 Baunetzwissen Elektroinstallation: https://www.baunetzwissen.de/drucken/elektroinstallation-in-wohngebaeuden-152968  ·  Q28 t-online Steckdosen Küche (2019): https://www.t-online.de/heim-garten/bauen/id_86984480/so-viele-steckdosen-gehoeren-in-die-kueche.html
- Q29 HEA – RAL-RG 678 (03/2011): https://www.agitano.com/wp-content/uploads/2015/05/hea-ral-678.pdf  ·  Q30 Installationszonen Küche (DIN 18015-3): https://www.elektro-wandelt.de/ratgeber/Elektro-Installationszonen-in-der-Kueche/
- Q31 DHZ – AMK Ellenbogenhöhe (2011): https://www.deutsche-handwerks-zeitung.de/?p=105954  ·  Q32 Küche&Co Ergonomie (2016): https://www.kuecheco.at/CMS/Newsroom/Pressemitteilungen/2016/2016-02-22-Ergonomie/KuCo-Pressemitteilung-Ergonomie.pdf.pdf
- Q33 Neff Ergonomie: https://www.neff-home.com/de/neff-entdecken/kuechenplanung/schritte/ergonomie  ·  Q34 Neff Spüle & Arbeitsfläche: https://www.neff-home.com/de/neff-entdecken/kuechenplanung/schritte/spuele-und-arbeitsflaeche-positionieren
- Q35 Blum DYNAMIC SPACE (2005): https://www.pressetext.com/news/dynamic-space-von-blum.html  ·  Q36 Plana Zonenplaner: https://www.plana.de/wp-content/uploads/2024/03/zonenplaner_v3.pdf
- Q37 Schwäbisch Hall Ergonomie (2017): https://www.schwaebisch-hall.de/content/dam/dambsh/unternehmen/dokumente/presseinformationen/2017/2017-06-28_ergonomie-bei-der-kuechenplanung.pdf  ·  Q38 Konsument „Küchen planen“ (Leseprobe): https://konsument.at/system/files/2022-02/Leseprobe_K%C3%BCchen%20planen%20und%20einrichten.pdf
- Q39 Neff Haubenhöhe: https://www.neff-home.com/de/produkte/dunstabzugshauben/hoehe-dunstabzugshaube  ·  Q40 Coolblue Haubenabstand: https://www.coolblue.de/beratung/abstand-zwischen-kochfeld-und-dunstabzugshaube.html
- Q41 Gorenje Induktion Einbau: https://partners.gorenje.com/fts/htmlNavodila/899682de.html  ·  Q42 Bosch Induktion PIE… Montage: https://media3.bsh-group.com/Documents/9000884188_C.pdf
- Q43 BSH Geschirrspüler Montage: https://media3.bsh-group.com/Documents/9000757332_C.pdf  ·  Q44 NKBA Kitchen Planning Guidelines: https://kb.nkba.org/uploads/2022/05/Kitchen-Planning-Guidelines.pdf
- Q45 Wikipedia – Kitchen work triangle: https://en.wikipedia.org/wiki/Kitchen_work_triangle  ·  Q46 DIN 18040-2:2011-09 (aktuell): https://www.din.de/en/wdc-beuth:din21:142706210
- Q47 nullbarriere – Küche DIN 18040-2: https://nullbarriere.de/din18040-2-kuechen.htm  ·  Q48 LBS/Verbraucherzentrale RLP Flyer Wohnen (2023): https://www.verbraucherzentrale-rlp.de/sites/default/files/2023-06/lbs_flyer_wohnen_2023_web_2.pdf
- Q49 Make it Home (DOI 10.1145/2010324.1964981): https://www.cs.princeton.edu/courses/archive/spring11/cos598A/abstracts/Yu11.html  ·  Q50 Interactive Furniture Layout (2011): https://graphics.stanford.edu/projects/furniture/
- Q51 Patent US 2010/0245351: https://patents.justia.com/patent/20100245351  ·  Q52 Karls-Universität 2025 (Bachelorarbeit): https://dspace.cuni.cz/handle/20.500.11956/200842
- Q53 Holodeck: https://arxiv.org/abs/2312.09067  ·  Q54 I-Design: https://arxiv.org/abs/2404.02838
- Q55 LayoutVLM: https://arxiv.org/abs/2412.02193  ·  Q56 DirectLayout: https://arxiv.org/abs/2506.05341
- Q57 LEGO-Eval: https://arxiv.org/abs/2511.03001  ·  Q58 Apple RoomPlan: https://developer.apple.com/documentation/roomplan/capturedroom · …/capturedroom/usdexportoptions · …/capturedroom/object/category-swift.enum
- Q59 Apple-Forum Genauigkeit: https://developer.apple.com/forums/thread/712500  ·  Q60 Leica DISTO Plan – Sketch Plan: https://shop.leica-geosystems.com/sites/default/files/2024-04/02_DISTO%20Plan%20App%20-%20Sketch%20Plan_DE.pdf
- Q61 magicplan Exportformate: https://help.magicplan.app/export-formats  ·  Q62 Flexijet (LIGNA): https://www.ligna.de/en/news/news-articles/state-of-the-art-cad-measuring-system-that-helps-even-the-most-skilled · Händler: https://stonegatetooling.com/knowledge-base/key-questions-about-the-flexijet-the-future-of-digital-templating/
- Q63 Graebert SiteMaster Kitchen → CARAT: https://help.graebert.com/en/articles/3020549-step-4-adaptation-of-the-floor-plan-in-carat
