# Prüfbericht Kapitel 5 „Wissenspaket Küche“

Stand 31.10.2026 · Unabhängige Prüfung. Prüfgegenstand: `paket/KAPITEL_WISSENSPAKET.md` (424 Zeilen), `paket/schema/` (6 Schemata, 3 Beispiele), `paket/pruefe_schema.py`, `paket/recherche/` RF, RC, RP, RS. Keine geprüfte Datei wurde geändert.

Fundstellen: `L123` = Zeile im Kapitel; sonst `datei:zeile` (km = kuechenmodell, pb = planungsbogen, bib = bibliothekseintrag). Verweise auf ARCHITECTURE §0–§4 gelten als gegeben.
Schwere: **hoch** = falsches Ergebnis, Datenfehler oder Blockade · **mittel** = Agent muss raten oder ein Auftragspunkt ist nur teilweise erfüllt · **niedrig** = Form, Klarheit.

---

## 1 Abdeckung des Owner-Auftrags

| # | Auftragspunkt | Stand | Fundstelle | Schwere | Korrektur |
|---|---|---|---|---|---|
| 1.1 | Konzept + Code-Design-Spec | abgedeckt | §5.1–5.13 | – | – |
| 1.2 | Mit Fusion und Claude weiterarbeiten, lernen wie man sie ersetzt | abgedeckt, Lücke | L29–38, §5.11 | hoch | Der Rückweg fehlt: Was passiert mit Änderungen, die in Fusion gemacht werden (L32: „gilt erst, wenn sie im Modell steht“)? Werkzeug `fusion_abgleich` (Fusion lesen → Diff → `korrektur_melden`) oder harte Regel „keine Maßänderung in Fusion“. Den Adapter `fusion` beschreiben: was er schreibt (Komponenten, Namen, Appearances), was er nie tut. |
| 1.3 | Planvorlagen **durchgehen** (Bestand sichten) | fehlt | nur L372 „eine Studio-Vorlage bemustern“ | mittel | Stufe 0 um ein Vorlagen-Inventar ergänzen (Liste aller Studio-Vorlagen mit Zweck, Format, Feldern, Papier); Fertig, wenn jede Vorlage einem `zweck` zugeordnet ist. |
| 1.4 | Bemustern | abgedeckt | L232 | – | Quelle in Stufe 1 auf PDF beschränken: DWG lesen hängt an ODA (L231, ungeklärt). |
| 1.5 | Vorlagen als HTML/Mustache/DXF/DWG in der App vom Nutzer erstellen/anpassen | angetippt | L227–233 | mittel | Es fehlen: Bedienkonzept des Vorlagen-Editors (Feldpalette, Vorschau, Versionen), Feldkatalog (nur 3 Beispiele: `projekt`, `blatt`, `massstab`), Escaping je Format (s. 7.2). Der Vorschlag Typst weicht von den genannten Formaten ab und ist für Nichtprogrammierer schwer editierbar. DWG ist faktisch ausgeschlossen (L231); das offen sagen. |
| 1.6 | Druckausgabe | abgedeckt | L209, L233 | niedrig | Maßstabstreue beim Druck (1:1-Schablonen wie Blanco, s. 2.2) als Prüfkriterium aufnehmen. |
| 1.7 | CAD-Ausgabe | abgedeckt | L213–220 | – | DXF-Version vereinheitlichen (W4). |
| 1.8 | Maschinen-/Werkzeugparameter (woodWOP, PaletteCAD, HOMAG-Sägen, CNC, BAZ) | angetippt | L191–192, L213, L217; setup:81–94 | mittel | **PaletteCAD kommt im Kapitel nicht vor** (nur RF 2). Kanonische Parameterschlüssel je Maschinenart festlegen (Säge: Schnittbreite, Besäumung je Seite, Stufen, Stapelhöhe, Vorschub; BAZ: Werkzeugnummer, Ø, Nutzlänge, Drehzahl, Vorschub). Felder für `werkzeug`-Einträge fehlen ganz. |
| 1.9 | Etiketten/Sticker | abgedeckt | L208; teil:45–52 | niedrig | Felder ergänzen (s. S4). |
| 1.10 | Kantenanleimmaschinen | angetippt | L216 (Stufe 3, „Format nicht öffentlich“) | niedrig | Ehrlich so lassen, aber Kantenbild und Kantenmeter als Stufe-1-Ausgabe (Etikett, Bestellung) aufnehmen. |
| 1.11 | QR-Codes | abgedeckt | L125, L208, L294 | – | – |
| 1.12 | Bauteilnamen, Gruppen, Standards | angetippt | setup:112–120; teil:11 | mittel | `gruppe` ist nur eine Element-ID, keine Baugruppen-Hierarchie (Schubkasten in Schrank), keine Fertigungsgruppen (Stapel, Verpackungsziel, RF 6). DIN 919-1 (RF 6, RF 8 Nr. 2) als Zeichnungsstandard nicht erwähnt. |
| 1.13 | Zuschnittoptimierung über Plattenkataloge (Maße, Formate, Dicken, Vorschübe, Laufrichtungen, Sägeblattdicken, Anschnitte, Seiten) | angetippt | L237–240; setup:66–94 | mittel | Im Schema fehlen: Plattenseiten/Dekorseite, Besäumung je Seite, Stufenzahl, Vorschub als feste Schlüssel; Faserbezug am Teil undefiniert. Siehe S1. |
| 1.14 | Kantenbelegung | abgedeckt | teil:29–35 | niedrig | Überstand und Vorfräsen fehlen (S2). |
| 1.15 | Bohr- und Fräsprogramme | angetippt | teil:72–87; L213, L217 | mittel | Richtung, z-Ebene, Durchgang, Bögen fehlen (S3). |
| 1.16 | Zusammenbau (Werkstatt) | fehlt | nur teil:53–56 | mittel | Zusammenbau (Korpus in der Werkstatt) und Montage (Baustelle) trennen; je Schrank Reihenfolge, Verbinder, Beschlagmontage. |
| 1.17 | Montage | angetippt | L219 (Stufe 3, ohne Inhalt) | mittel | Inhalt der Montage-PDF festlegen (Reihenfolge der Schränke, Wandbefestigung außerhalb Installationszone, Sockelfüße, Ausrichten). |
| 1.18 | Geräte-CAD-Daten | abgedeckt | L188; bib:44–56 | – | – |
| 1.19 | Autoplanung nach Parametern | abgedeckt | §5.5 | – | – |
| 1.20 | Kollisionserkennung | abgedeckt | L176 | – | Koordinatenfehler beheben (W1, B1), sonst rechnet sie falsch. |
| 1.21 | Anschlüsse | abgedeckt | L178, L211; gemeinsam:63–75 | niedrig | `anschluss` ohne ID und ohne Zuordnung zum Gerät (S7). |
| 1.22 | Steckdosen | abgedeckt | L77, ANS-03 | niedrig | Geplante Steckdosen (Ausgabe) von Bestandsdosen (Aufmaß) trennen. |
| 1.23 | Zukaufteile | angetippt | L189 | niedrig | Bestellfelder (S5). |
| 1.24 | Schubkästen | angetippt | km:77; teil:10 | mittel | Kein Baustein „Schubkasten“ mit Herstellerregeln (Nennlänge aus Korpustiefe, Zargenhöhe, Boden-/Rückwandmaß). Als Bibliotheks-`regeln` mit Beleg vorsehen und in Stufe 3 nennen. |
| 1.25 | **Peka**-Schrankausstattung | kaum | L187 (ein Halbsatz), L373, F7 | **hoch** | Keine Beilage behandelt Peka; die einzige Quelle (L424) ist eine Produktübersicht des Wandregalsystems Pecasa, kein technisches Merkblatt und keine Schrankausstattung (s. 2.2). Modelltypen für Innenauszug, Hochschrankauszug, Eckauszug, Abfallsystem fehlen (km:66, km:77, setup:54–65). Nachrecherche und Schema-Erweiterung. |
| 1.26 | Beschläge Blum, Grass, Hettich, Häfele | abgedeckt | L187 (RF 4) | – | – |
| 1.27 | **Blanco** (Spülen) | angetippt | L188 | niedrig | Nur Ausschnittschablone belegt; Einbaumaße, Unterschrankbreite, Anschlusslage aus Blanco-Daten als Bibliothekseintrag skizzieren. |
| 1.28 | Bestellwesen | angetippt | L200, L210, L377 | mittel | Kein Datenmodell für Bestellpositionen (S5); Stufe widersprüchlich (W3). |
| 1.29 | CAM | angetippt | L217–218, E15 | niedrig | Bewusst zurückgestellt, das ist vertretbar. |
| 1.30 | Schritt für Schritt | abgedeckt | §5.12 | mittel | Gating über „5 Projekte in Folge“ kann den Plan blockieren (R5). |
| 1.31 | macOS nativ, Swift-Kern, „viele Integrationen wie eine SaaS“, später SaaS | abgedeckt, Lücke | §5.9 | niedrig | Integrationskatalog fehlt (Werkstatt-Software, Händler-Shop/OCI, tapio, Ablage). Ports decken nur Rechen-/CAD-Adapter ab. |
| 1.32 | Werkstatt/Maschinen offen | abgedeckt | F2–F5 | niedrig | RF 9 Nr. 9 (Volumen pro Jahr) fehlt in den F-Fragen, entscheidet aber über Stufe 4/6. |
| 1.33 | Erste Stufe = Zuschnitt + Etiketten + Pläne | abgedeckt | L372 | mittel | Stufe 1 hängt an offenen Entscheidungen E12, E14, F13 und an Bibliothekseinträgen aus Stufe 2 (W15, W26). |
| 1.34 | Drei Ebenen Kern/Setup/Projekt | abgedeckt | §5.2 | mittel | Vorrang zwischen mehreren Setups (`erbt_von`, setup:12) ungeregelt; „Setup je Nutzer“ (Auftrag) vs. „Firma oder Gruppe“ (L45) klären. |
| 1.35 | Mensch gibt Maße und Materialien vor | angetippt | pb:72–124 | **hoch** | Materialien ja; **Maße nein**: Der Planungsbogen hat keine allgemeine Werte-Vorgabe (nur `arbeitshoehe`) und keine Maßvorgaben je Element. `ap_d = 5, herkunft projekt` (km:13) hat im Bogen keine Quelle. Siehe W13, S8. |
| 1.36 | Regeln: keine Namen, quellenbelegt, kurz | weitgehend | §6, §2 | niedrig | Siehe Abschnitt 2 und 6. |

---

## 2 Belege

### 2.1 Stichprobe von 26 Aussagen gegen die Beilagen

| # | Aussage im Kapitel | Beilage | Urteil |
|---|---|---|---|
| 1 | LEGO-Eval: beste Verfahren ≤ 10 % der Detail-Constraints (L38) | RP 3 [Q57] | stimmt |
| 2 | AP → Hängeschrank ≥ 450 mm (L68) | RP 2.1 [Q21] | stimmt |
| 3 | Nische Unterbaugeräte ≥ 820/870/920 (L72) | RP 2.1 | stimmt |
| 4 | Arbeitshöhe Ellenbogen − 100…150, ±50 (L73) | RP 2.3 | verkürzt: ±50 gilt laut RP „wenn mehrere Personen die Küche nutzen“ |
| 5 | Steckdosen 2 je 1,2 m + 3 [unsicher] (L77) | RP 2.2 | stimmt |
| 6 | Eigene Stromkreise, Status „Norm“ (L78) | RP 2.2 | ungenau: dieselbe Tabelle ist in RP 2.2 als „nicht eindeutig (?)“ markiert; L78 braucht dasselbe [unsicher] wie L77 |
| 7 | Installationszone 1000–1300, Vorzug 1150 (L79) | RP 2.2 [Q30] | stimmt (Quelle ist ein Ratgeber über DIN 18015-3, „sekundär“ korrekt) |
| 8 | DIN 68935 = Bad, EN 1116:2018-03, DIN 18022 zurückgezogen, Fünf Zonen = Blum 2005 (L82) | RP 0 | stimmt |
| 9 | Patent „mit genau diesem Ablauf“ (L142) | RP 3 [Q51] | **übertrieben**: RP sagt „nahezu die Blaupause … allerdings katalog- und rasterbasiert“ |
| 10 | CP-SAT löst Küchenlayouts in Zehnersekunden (L155) | RP 3 [Q52] | stimmt |
| 11 | RoomPlan: 16 Kategorien, JSON + USDZ, keine Genauigkeit; magicplan-DXF ohne Maße (L157) | RP 5 | stimmt |
| 12 | 30 Regeln in 10 Klassen (L164) | RP (b) | stimmt (4+4+4+4+5+2+2+3+1+1 = 30) |
| 13 | „jede Regel nennt Quelle und Status“ (L162) | RP (b) | Ziel, nicht Ist: RP (b) nennt je Regel eine Datenquelle, aber keinen Status |
| 14 | Häfele ~40.000 Artikel, Formate nicht genannt (L187) | RF 4 | stimmt |
| 15 | Schraubbilder 45/9,5; 48/6; 52/5,5 (L187) | RF 4 | stimmt |
| 16 | Peka: technische Merkblätter als PDF (L187) | keine Beilage | **unbelegt**; URL L424 ist eine Produktübersicht (s. 2.2) |
| 17 | Hersteller-CAD für SaaS „nur über Partnerprogramme“ (L198) | RF 7 | als Regel vertretbar, aber RF sagt „vermutlich nicht erlaubt [unsicher]“; als „Vorschlag:“ markieren |
| 18 | Formate nicht geschützt, „Handbuchtexte schon“ (L199) | RF 7 | **übertrieben**: RF „kann eine Verletzung sein“ |
| 19 | Kaufmännische Standards inkl. IDM „sind offen“ (L200) | RF 5 | ungenau: RF 5 nennt für IDM „Zugangsbedingungen unklar [unsicher]“ |
| 20 | CSV „Semikolon, UTF-8-BOM“ (L206, Beleg RF 1.2, 3.1) | – | **unbelegt**: steht in keiner Beilage; als „Vorschlag:“ markieren |
| 21 | woodWOP-Layer `Werkstk_19`, `V_BohrLS_8`, `T145` (L213) | RF 3.2 | sinngemäß (RF: `Werkstk_19_5`, `V_Fraes_-3T145`); „DXF R2018“ stammt aus RC 2, nicht RF 3.2, und widerspricht L264 |
| 22 | intelliDivide ab 45 €/Monat (L223) | RF 1.3 | stimmt |
| 23 | swift-mustache 0 Abhängigkeiten, spec-konform außer Lambdas (L292) | RS 4 | stimmt |
| 24 | OCCTSwift ~568 MB statisch, nur Apple (L297); ODA ab 3.000 $, 2.250 $/Jahr (L299) | RS 1, RS 5 | stimmt; bei ODA fehlt „limited commercial use“ (für SaaS wäre „Sustaining“ 7.500 $ relevant) |
| 25 | „Das Muster ist erprobt“ (Zeichenliste, L248) | RS 3 | in RS als [Einschätzung] markiert; im Kapitel als Tatsache formuliert |
| 26 | Helfer mit `inherit` geht nicht, wenn Claude Desktop startet (L310) | RS 8 | stimmt; **ausgelassen** ist der RS-8-Praxisbericht, dass AMFI sandboxed Standalone-CLIs beim Start durch fremde Apps ablehnt (betrifft die empfohlene Lösung, s. R3) |

Ergebnis: 15 von 26 stimmen, 7 ungenau oder verkürzt (Nr. 4, 6, 13, 17, 19, 21, 25), 4 unbelegt oder übertrieben (Nr. 9, 16, 18, 20).

### 2.2 URLs aus §5.14 per WebFetch (8 geprüft)

| URL | Aussage im Kapitel | Befund |
|---|---|---|
| martinfowler.com/bliki/StranglerFigApplication.html | Strangler Fig, 2024 | stimmt (22.08.2024). Fowler nennt zusätzlich „transitional architecture“ und Nahtstellen; das Kapitel hat dafür keinen Baustein (R5). |
| platform.claude.com/docs/en/api/skills-guide | 30 MB, ≤ 20 Skills je Anfrage, kein Netz, keine Paketinstallation | stimmt wörtlich |
| swift.org/blog/announcing-swift-6/ | Foundation vereinheitlicht, statisches Linux-SDK | stimmt |
| occt3d.com/…/open-cascade-technology-changes-its-license-gnu-lgpl | LGPL 2.1 + OCCT-Ausnahme | stimmt (Ankündigung 2013, ab OCCT 6.7.0) |
| cdn.blanco.com/…/141536_Schablone_STYLE.pdf | Blanco-Ausschnittschablone als PDF | stimmt: Ausschnittschablone STYLE (Silacron/Silgranit), Maßstab 1:1 |
| peka.com/…/Pecasa-TechLeaflet-peka-DEU.pdf | „Peka technisches Merkblatt (Beispiel)“ | **falsch etikettiert**: „Pecasa Produkt-Übersicht“ (09/2025) eines Wand-Regalsystems; keine Bohrdaten, keine Mindestbreiten, CAD nur als Verweis auf die Website. Belegt nichts zur Schrankausstattung. |
| arxiv.org/abs/2305.16291 (Voyager) | Fähigkeiten als ausführbarer Code in wachsender Bibliothek | stimmt |
| arxiv.org/abs/2308.10144 (ExpeL) | „Atom-Verfahren wie in den Lernrunden“ | ExpeL lernt Einsichten in natürlicher Sprache; der Begriff „Atom“ kommt dort nicht vor. Als Analogie kennzeichnen. |

### 2.3 Falsche oder unklare Kürzel und Belegformen

| Fundstelle | Befund | Schwere | Korrektur |
|---|---|---|---|
| L386 E12 „§1.3; R:5“ | „R:5“ ist kein definiertes Kürzel (L21) | niedrig | auflösen oder streichen |
| L217 CNC MPR „RF 1.1“ | Pilot-Empfehlung steht in RF 1 „Andocken an HOMAG“ und RF 8 Nr. 7 | niedrig | „RF 8“ |
| L158 `grossserie_v1.md`; L212 `praesentation.py`; L206 „Python-Weg v3.3“ | Belege außerhalb des Pakets, verletzen die Belegform L23 | mittel | als Beilage aufnehmen oder als „Projektkorpus, nicht beigelegt“ kennzeichnen |
| L353 „Runde-3-Quote von 93,9 % ist kontaminiert“ | ohne Quelle und ohne Kontext | niedrig | Quelle nennen oder streichen |
| L48 „RP 0.4“ | RP 0 ist eine nummerierte Liste ohne Unterabschnitte | niedrig | „RP 0 Nr. 4“ |

---

## 3 Widersprüche

| ID | Fundstellen | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| W1 | L124 vs. gemeinsam:5 | **hoch** | Raumsystem „Ursprung links hinten, x entlang Wand A, y in den Raum, z nach oben“ ist **linkshändig** (Blick vom Raum auf Wand A: rechts × zum Betrachter = unten). gemeinsam.schema verlangt „rechtshaendig“. STEP, GLB und Fusion sind rechtshändig; Folge wären gespiegelte Küchen (Anschlagseiten, Händigkeits-Zonen). | Rechtshändig festlegen, z. B.: im Grundriss Wand A unten, Ursprung links unten (vom Raum aus gesehen die **rechte** Ecke von Wand A), x entlang Wand A, y in den Raum, z nach oben. Wandansichten spiegelt nur der Plan-Adapter. Skizze ins Kapitel, Kreuzprodukt-Test ins Prüfskript. Teilsystem (L124, teil:5) ebenso eindeutig machen: „z in die Dicke“ ist zweideutig, Koordinaten auf Schmalflächen l1…b2 sind nicht definiert. |
| W2 | L14, L32 vs. teil:22, km:5 | mittel | „Adapter schreibt nie zurück“, aber `zuschnitt` wird „vom Adapter berechnet und hier festgehalten“; km:5 nennt Planer und Prüfer als zurückschreibende „Adapter“. | Zuschnittmaß von `PartEngine` (Kern) berechnen lassen; km:5 umformulieren: „Schreiben: Planer, Prüfer, `teile_ableiten`. Adapter: nie.“ |
| W3 | L204–221 (Spalte „Stufe“) vs. L367–377 | **hoch** | Zwei Stufenzählungen: Bestellliste 1 vs. 6; DXF, STEP, 3D 2 vs. 4; Anschlussplan, Präsentation 2 vs. nirgends; Kante, CNC, Montage 3 vs. 6 oder nirgends. | Spalte in §5.8 auf die Nummern von §5.12 umstellen; jede Ausgabe genau einer Stufe zuordnen. |
| W4 | L213 „DXF R2018“ vs. L264 „R12, dann AC1015“ | mittel | RS 5 schätzt AC1015 auf 1.000–1.800 Zeilen; R2018 (AC1032) ist mehr und unbelegt. | Eine Version festlegen (Vorschlag: R12 für Stufe 2, AC1015 bei Bedarf) und L213 anpassen. |
| W5 | L229 „Feldsyntax überall Mustache“ vs. setup:103 `html_jinja`, setup:116–118 `{schrank:02d}` | mittel | Drei Platzhalter-Syntaxen. | `html_jinja` streichen; Namensschema in Mustache-Form oder ausdrücklich als eigene Mini-Syntax definieren. |
| W6 | L59 vs. gemeinsam:11, km-Beispiel | **hoch** | „Vorschlag = aus Kern, Setup-Regel … → `herkunft = annahme`“. Dann wäre jeder Kern- und Setup-Default eine Annahme und stünde in `annahmen[]`; die Werte `kern`/`setup` im Enum und im Beispiel (`sockel_h: setup`) widersprechen dem. | Trennen: bestätigter Setup-/Kernwert → `setup`/`kern` (kein Bericht nötig); unbestätigter Vorschlag (Setup-Regel-Kandidat, gelernter Wert, Fallback) → `annahme`. Tabelle L56–60 entsprechend ändern. |
| W7 | pb:141, L337, setup:102, setup-Beispiel:36 | **hoch** | Drei Vokabulare für Ausgaben: `werkplanung`/`werkplan`/`blatt_werkplan`, `bestellung`/`bestellliste`, `elektro_sanitaer`/`anschlussplan`, `modell_3d`/`vorschau_3d`, `zuschnitt`/`zuschnittliste`+`zuschnittplan`; `cnc`, `kanten` ohne `ziel`; `dxf` ohne Bogen-Eintrag. | Ein Enum `ausgabe` in gemeinsam.schema, von Bogen, Setup und `ausgeben` gemeinsam genutzt. |
| W8 | L91, L185 vs. bib:70 | niedrig | „Preise nur im Setup“, aber `bibliothekseintrag.preis`. | Feld streichen; Preise als `setup.preise[bibref]`. |
| W9 | L135 (Invariante 5) vs. bib:67, L197 | mittel | „freigegebener Eintrag“ gibt es im Status-Enum nicht; neue Einträge starten `ungeprueft` → entweder schlägt jedes frische Modell fehl, oder die Invariante ist wirkungslos. | Invariante präzisieren: Fertigung nur mit `geprueft`; Planung erlaubt `ungeprueft` mit Warnung; `veraltet` → Warnung. |
| W10 | L134, L136 vs. teil:72–87 | mittel | Invariante 4 „außer Durchgang“, Invariante 6 „Teilungsvermerk“: beide Felder fehlen im Schema. | `bearbeitung.durchgang: bool`, `teil.teilung` ergänzen. |
| W11 | L126, L340 vs. km-Schema | **hoch** | „Fertigung nur aus freigegebener Revision“, aber weder Feld (`freigabe`) noch Werkzeug (`freigeben`). | `kuechenmodell.freigabe {revision, datum, durch_rolle}` und Werkzeug `revision_freigeben`; `ausgeben` für Fertigungsziele verweigert unfreigegebene Revisionen. |
| W12 | L146 vs. pb:15–27 | mittel | Fertig-Kriterium „jedes Maß hat Quelle und Unsicherheit“, das Schema hat nur eine globale `genauigkeit_mm`; Grundrisspunkte sind nackte Zahlen. | Maße als `wert` (mit `toleranz`, `beleg`) oder eine Messliste `messungen[]` mit Quelle je Maß. |
| W13 | L50 vs. pb:72–124, km:13 | **hoch** | „Vorrang Projekt > Setup > Kern“, aber der Bogen hat keinen Ort für Projektwerte außer `arbeitshoehe`. `ap_d = 5 (projekt)` im Modell hat keine Quelle im Bogen. | `vorgaben.werte: {schluessel → wert}` ergänzen; Werteauflösung liest genau dort. |
| W14 | L155, L374 vs. L286, F13 (L409) | mittel | CP-SAT-Sidecar für L/U/Insel in der Desktop-App, aber L286 setzt voraus „Python, OR-Tools nur im SaaS“. Dann kann die App keine L/U-Küchen planen. | F13 vor Stufe 3 entscheiden; bis dahin L286 als offene Annahme kennzeichnen. |
| W15 | L304, L372 vs. E14, F13; setup-Beispiel:30 | mittel | Stufe 1 setzt den Typst-Helfer voraus (E14, F13 offen); die Beispiel-Vorlage ist `html_mustache`. | E12, E14, F13 als Fertig-Kriterium in Stufe 0 aufnehmen. |
| W16 | L352 vs. L361 | niedrig | Ablösung nach „5 Projekten in Folge“ vs. „Parität ≥ 0,95“. | Ein Kriterium. |
| W17 | L223 vs. L207, L280, L372 | mittel | „Profi-Zuschnittoptimierung nicht selbst bauen“ (RF 8), aber eigene CutEngine und Abnahme „Verschnitt ≤ Python“. | Grenze klar sagen: eigene Optimierung = Vorschau und Kleinaufträge; Werkstatt bekommt Liste für ihren Optimierer; welcher Plan geht an die Säge? |
| W18 | L341 vs. L155, L239 | mittel | „Gleicher Aufruf → gleicher Hash“ gilt nicht für Solver mit Zeitlimit (CP-SAT mit mehreren Workern, PackingSolver `time_limit`) und nicht für PDF mit Zeitstempel/Dokument-ID [Einschätzung]. | Idempotenz nur für reine Funktionen fordern; Solver-Ergebnis mit Seed/deterministischer Zeit in der Revision speichern; Hash über Zeichenliste/kanonisches JSON statt PDF-Bytes. |
| W19 | L377 vs. L266, L275 | mittel | „Gleicher Golden Master auf macOS und Linux“, aber PDF entsteht auf macOS über CoreGraphics, auf Linux anders. | Golden Master auf Ebene Zeichenliste/JSON; PDFs per Rastervergleich mit Toleranz. |
| W20 | L306 vs. Beispiele | mittel | „Byte-gleich zurückschreiben“: Die Beispiele sind handformatiert und enthalten explizite `null` (km 6×, pb 1×, setup 2×), die Codable mit Optionals weglässt; geprüft: keine Beispieldatei ist in kanonischer Form. | Roundtrip semantisch prüfen (kanonisches JSON vergleichen); `null` vs. „fehlt“ bewusst definieren (z. B. `kante: null` = keine Kante). |
| W21 | L125 vs. km:18,22,35; pb:11–13; teil:8; km:65 | mittel | „IDs klein, ASCII“, Beispiele nutzen `Z1`, `Z1-02`, `A`, `…-Z102-…`; Schema erzwingt das Muster für Element-, Teil- und Wand-IDs nicht. | `$ref: id` überall; Beispiele anpassen. |
| W22 | L125, setup:116 vs. RF 6 | mittel | Barcode trägt die Teil-ID; das Namensschema erzeugt lange, variable IDs (28 Zeichen im Beispiel). RF 6: kurze Codes fester Länge, Seriennummer statt Name. | `teil.nr` (z. B. `<auftrag>-<laufnr>`, feste Länge) für Code 128; sprechende ID nur im Klartext. |
| W23 | L164, L168 vs. km:57, km-Schema:43 | niedrig | Regel-IDs `ABS-02` vs. Befund `anschluss.strom_unbestaetigt`; Regel `schwere` vs. Befund `stufe`. | Ein Feldname, ein ID-Schema. |
| W24 | pb:24 vs. pb:40, F11 | mittel | `arbeitshoehe 910, herkunft projekt` (= bindende Vorgabe) ist zugleich offene Frage. | `herkunft: annahme`, im Modell ebenso. |
| W25 | L191–192 vs. bib:9, setup:81–94 | niedrig | Maschinen und Werkzeuge „nur Setup“, zugleich Bibliotheksarten `maschine`, `werkzeug`. | Einen Ort wählen. |
| W26 | L372 vs. L373, L135 | mittel | Stufe 1 braucht Material- und Kanteneinträge (bibrefs), der Bibliotheksdienst kommt erst in Stufe 2 → Invariante 5 scheitert in Stufe 1. | Minimale Material-/Kanten-Einträge (JSON-Dateien) in Stufe 0/1. |
| W27 | L210 vs. L372, L304 | niedrig | Bestellliste „Stufe 1“, fehlt im Stufe-1-Inhalt und in „Stufe 1 braucht davon nur“. | Entscheiden; vorgeschlagen: Stufe 1 (geringer Aufwand, hoher Nutzen). |

---

## 4 Schemata

### 4.1 Prüfskript

`python3 -I pruefe_schema.py schema` (im Paketordner):

```
Schemata gueltig: bibliothekseintrag.schema.json, gemeinsam.schema.json, kuechenmodell.schema.json, planungsbogen.schema.json, setup.schema.json, teil.schema.json
kuechenmodell.nische-2460.json ok
planungsbogen.nische-2460.json ok
setup.studio-beispiel.json ok
exit=0
```

Zusatzproben (eigene Python-Aufrufe, nichts geändert):
- `pruefung.stand = "gestern"` besteht: `date-time` wird nicht geprüft (Format-Prüfer fehlt), nur `date`.
- Unbekannte Felder in Teil, Element, Modell und Bogen bestehen (kein `additionalProperties: false`); ein Tippfehler wie `tippfehler_dicke` fällt nicht auf.
- Ein Teil `art: platte` ohne `material`, `dicke`, `fertig` besteht.
- Großbuchstaben-IDs bestehen.
- Invariante 2 ist im Beispiel verletzt: `werte` enthält keinen Wert mit `annahme`, `annahmen[]` hat zwei Einträge.

| ID | Fundstelle | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| P1 | L138 | mittel | „Ein absichtlich fehlerhaftes Modell scheitert an drei erwarteten Stellen“: Das Negativbeispiel liegt nicht im Paket, das Skript hat keinen Negativtest. Nicht nachprüfbar. | `schema/beispiel/fehler/` mit erwarteten Fehlerpfaden; Skript prüft „scheitert genau dort“. |
| P2 | pruefe_schema.py | mittel | Prüft nur das Schema, keine der Invarianten 1–6 (L130–136). | Invarianten als Funktionen ergänzen (alle sechs sind in < 60 Zeilen Python prüfbar). |
| P3 | pruefe_schema.py:16–19 | niedrig | Unbekanntes Dateipräfix (z. B. `bibliothekseintrag.*.json`) → `KeyError`. Für `bibliothekseintrag` und `teil` gibt es kein Beispiel; beide Schemata sind ungetestet (Teil nur eingebettet). | Beispiele ergänzen, `paare` erweitern, unbekannte Präfixe melden statt abstürzen. |
| P4 | pruefe_schema.py:21 | niedrig | `date-time` ungeprüft. | `rfc3339-validator` voraussetzen oder Prüfung selbst schreiben. |

### 4.2 Fachliche Lücken

| ID | Bereich | Fundstelle | Schwere | Fehlt | Korrektur |
|---|---|---|---|---|---|
| S1 | Zuschnitt | setup:66–94; teil:21–27 | mittel | Plattenseiten (Dekor-/Sichtseite, ein-/beidseitig), Besäumung je Seite (PackingSolver kann es, RC 3), Stufenzahl, Stapelhöhe, Vorschub als feste Schlüssel; Bezug von `faser` (parallel zu x?); Regel `faser ≠ keine` ⇒ `drehbar = false`; Zugabe je Seite. | `saege`-Parameterobjekt typisieren; `teil.sichtseite`; `faser` mit Bezug beschreiben. |
| S2 | Kanten | teil:62–71 | niedrig | Überstand, Vorfräsen, Kantenbild für Etikett, Kantenmeter für Bestellung. | Felder ergänzen; Kantenmeter als abgeleitete Ausgabe. |
| S3 | CNC | teil:72–87; bib:23–26 | mittel | `z`/Ebene, Richtung (Horizontalbohrung, Reihenrichtung), Winkel, `durchgang`, Bögen in `kontur` (nur Punkte), Bezugspunkt eines Bohrbilds, Platzierung/Spiegelung beim Einsetzen; `teil.beschlaege.bohrbild` ist freier Text statt Verweis; Programmname/Barcode je Teil. | Felder ergänzen; Bohrbild als `{bibref, bezug, x, y, seite, gespiegelt}`. |
| S4 | Etikett | teil:45–52 | niedrig | Code-128-Inhalt getrennt von QR, Vorlagenverweis, Position am Teil; Enum `sichtseite_nein` ist unklar. | `code128`, `vorlage`, `position`; Enum `oben/unten/beliebig`. |
| S5 | Bestellung | bib:6–73; setup:138–141 | mittel | Lieferant, Bestellnummer, Verpackungseinheit, Mengeneinheit, Lieferzeit; Bestellposition; `preise` ist ein untypisiertes Objekt. | `bestellposition`-Definition; `setup.preise` als Map `bibref → {eur, einheit, stand}`. |
| S6 | Montage/Zusammenbau | teil:53–56; km:62–104 | mittel | Elementbezogene Montage (Reihenfolge der Schränke, Wandbefestigung, Aufhängung, Sockelfüße); Trennung Werkstatt/Baustelle. | `element.montage {schritt, ort: werkstatt/baustelle, befestigung}`. |
| S7 | Anschlüsse | gemeinsam:63–75 | niedrig | ID, Zuordnung zu Gerät/Element, Dimension (DN, Querschnitt), Bestand vs. geplant. | Felder ergänzen. |
| S8 | Planungsbogen | pb:72–124, pb:15–27 | **hoch** | Werte-Vorgaben (W13), Maßquelle je Maß (W12), Maßvorgaben/feste Elemente je Position, Bodengefälle. | `vorgaben.werte`, `vorgaben.elemente_fest[]`, `messungen[]`, `boden_abweichung_mm`. |
| S9 | Küchenmodell | km:6–60 | **hoch** | `freigabe` (W11), `fest` je Element (L153), `variante` und `scores` (L150–151), `annahmen` als Schlüssel statt Freitext, Bezugssystem von `freiraum`. | Felder ergänzen; `annahmen: [schluessel]`. |
| S10 | Innenausstattung (Peka) | km:66, km:77; setup:54–65 | mittel | Typen für Innenauszug, Hochschrankauszug, Eckauszug, Abfallsystem; Beschlagsystem `innenausstattung`. | Enums und `beschlagsysteme` erweitern, sobald Peka recherchiert ist. |
| S11 | Strenge | alle | mittel | `additionalProperties` offen; Pflichtfelder je `art` fehlen (`if/then`); ID-Muster nicht durchgesetzt; `bibref.stand` optional, obwohl L127 „Projekt friert den Katalogstand ein“. | Objekte schließen; `if art = platte then required [material, dicke, fertig]`; `stand` im Modell Pflicht. |
| S12 | Werte | setup:17–36; gemeinsam:29 | niedrig | `raster`, `lochreihe`, `verbinder`, `rueckwand` ohne Herkunft (gegen gemeinsam:25); Einheiten ohne `m`, `m2`, `%`, `s`. | als `wert` führen oder Ausnahme dokumentieren; Einheiten ergänzen. |

### 4.3 Fehler in den Beispielen

| ID | Fundstelle | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| B1 | km:27 | **hoch** | Freiraum Auszug y −600…0: liegt **hinter Wand A**. Der Schrank steht bei y 0…560; der Auszug gehört nach y ≈ 579…1160. Kollisionsprüfung KOL-02 würde nie greifen. | korrigieren; Bezugssystem von `freiraum` (Raum oder Element) festlegen. |
| B2 | km:42–43 vs. teil:5, setup:8,10 | mittel | Teilursprung „vorn“ (l1 = vordere Kante, bekantet). Rückwandnut bei y = 16 liegt dann 16 mm hinter der Vorderkante; Einstand 16 gilt von hinten (y ≈ 535,5). Lochreihe bei x = 37, y = 200, obwohl `abstand_vk = 37` (y = 37). Reihenrichtung nicht angebbar. | Werte korrigieren; Richtungsfeld (S3). |
| B3 | km:58 vs. km:9–15 | mittel | `annahmen[]` enthält Werte, die nicht in `werte` stehen (Invariante 2 verletzt). `werte` fehlen `korpus_t`, `rueckwand_d`, `front_d`, `fuge_front`, Lochreihe, obwohl die Teile sie nutzen (L50: „Bausteine lesen nur dort“). Die Bestandssteckdose (`annahme`, pb:18) fehlt in `km.anschluesse`. | Beispiel vervollständigen. |
| B4 | pb:24, km:12 | mittel | Siehe W24. | `annahme`. |
| B5 | km:18,22,35,49; pb:11–13 | mittel | Großbuchstaben-IDs (W21). | klein schreiben. |
| B6 | km:52 | niedrig | Boden 560 tief ohne Nut kollidiert mit der Rückwand in der Nut. | Boden kürzen oder nuten. |
| B7 | setup-Beispiel:24, 30, 36 | niedrig | `ptx`, `cnc: mpr`, Vorlage `html_mustache` nehmen offene Entscheidungen vorweg (L218, E15, E14). | neutrale Werte oder Kommentar „Beispiel, nicht Entscheidung“. |
| B8 | km:25 vs. pb:97 | niedrig | `griff: "pto"` vs. Enum `grifflos_pto`. | gleiches Enum. |

---

## 5 Für Agents lesbar

Gut: Leitwörter (L9–15), Lesereihenfolge (L17), „Fertig, wenn“-Spalten in §5.5 und §5.12, Belegform, Markierung [unsicher]/[Einschätzung]/„Vorschlag:“.

| ID | Fundstelle | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| A1 | L204–221 vs. L367–377 | **hoch** | Zwei Stufenzählungen (W3); ein Agent baut die falschen Ausgaben zuerst. | eine Zählung. |
| A2 | L319–337 | **hoch** | Werkzeug-Ein- und Ausgaben sind nicht als Schema definiert (`fehlend[]`, `konflikte[]`, `folgen[]`, `dateien[]`, `bericht`, `vorschlaege[]`, Fehlercodes außer `revision_veraltet`). MCP braucht `inputSchema`. Es fehlen Werkzeuge zum Schreiben des Bogens (`werte_aufloesen` erwartet eine gespeicherte `bogen_id`, es gibt kein `bogen_speichern`), zum Freigeben, zum Aufmaß-Import (RoomPlan-JSON, DISTO-DXF) und zum Fusion-Abgleich. | `schema/werkzeuge.schema.json` mit `$defs` je Werkzeug; Werkzeugliste ergänzen. |
| A3 | L126, L323–327 | mittel | Unklar, welche Werkzeuge die Revision erhöhen (`pruefen` schreibt Befunde, `teile_ableiten` „ja, idempotent“). Erhöht `pruefen` die Revision, scheitert jedes folgende `ausgeben` an `revision_veraltet`. | Tabelle um Spalte „Revision +1“ ergänzen; Befunde und Teile als abgeleitete Daten einer Revision führen. |
| A4 | L166–173 | mittel | Regelsprache (`wenn`, `pruefe`, `ueber()`, `abstand_z()`) ist nicht definiert; ein Agent kann keine Regel korrekt schreiben, der Kern keine auswerten. | In Stufe 2 Regeln als Kernfunktionen mit Metadaten (ID, Quelle, Status, Testfälle); eine Ausdruckssprache erst, wenn Nutzer Regeln selbst schreiben sollen. |
| A5 | setup:14 vs. §5.2; L148 | mittel | „Mindestsatz siehe Kapitel 5.2“: §5.2 hat keinen Konstruktions-Mindestsatz. Das Fertig-Kriterium „jeder Bausteinparameter aufgelöst“ ist ohne Liste nicht prüfbar. | Pflichtschlüssel je Baustein als Tabelle (z. B. `korpus_d`, `rueckwand_d`, `front_d`, `fuge_front`, `sockel_h`, `korpus_t`). |
| A6 | L146, L151, L232, L372–374 | mittel | Vage Kriterien: „kritische Maße“ (RP 5 hat die Liste), „Scores erklärbar“, „≤ 0,5 mm“ (Messmethode?), „jede Maßzahl = Modellmaß“ (wie gemessen?), „findet die gebaute Küche unter seinen Varianten“ (Toleranz?), „Befunde vom Menschen bestätigt“. | Messmethode je Kriterium nennen (z. B. Maßzahlen auf der Zeichenliste vergleichen, nicht im PDF; Variante gleich, wenn Modulfolge gleich und Breiten ±1 mm). |
| A7 | L59, L353, L407, L158 | niedrig | Undefinierte Begriffe: „Atom“, „Lernrunden“, „Runde-3-Quote“, „Bildschirmvideo-Runde“, „Korpus“. | in die Leitwörter aufnehmen oder streichen. |
| A8 | L232, L304, L372 | mittel | Schritte, die an offenen Entscheidungen hängen (E14, F13, E12), sind nicht als blockiert markiert. | Marker „blockiert bis E14“. |
| A9 | L62/L361; L86–93/L353; L233/L293/L388; L155/L286/L297 | niedrig | Doppelt: Übernahmequote, Lernweg, Typst-Begründung, Sidecar-Begründung. | je einmal, sonst Verweis. |

---

## 6 Namensregel

| Fundstelle | Befund | Schwere | Korrektur |
|---|---|---|---|
| Kapitel | Keine Personen- oder Kundennamen gefunden. | – | – |
| L206 „Python-Weg v3.3“, L371 „Küche v3.3 und Nischenküche“, L407 „Nischenküche 2460 (Bildschirmvideo-Runde)“ | Interne Projektbezeichnungen statt neutraler IDs; grenzwertig. | niedrig | neutrale IDs (`ref-a`, `nische-2460`) und nur diese. |
| Schemata, Beispiele | Keine Namen; IDs neutral (`nische-2460`, `studio-beispiel`). | – | – |
| RC Fließtext | GitHub-Benutzerkürzel einzelner Personen: „PackingSolver (fontanf)“, „OCCTSwift (gsdali)“, „Woodworking Workbench (dprojects)“, „freecad-mcp (neka-nat)“, „build123d-mcp (pzfreo)“. | niedrig | im Fließtext nur Projektnamen; Kürzel bleiben in URLs. |
| RS Fließtext | „OCCTSwift (Org SecondMouseAU, Spiegel gsdali)“. | niedrig | wie oben. |
| RP Quellenliste | „Q50 Merrell et al. 2011“ = Autorenname. | niedrig | Titel statt Autor. |
| URLs mit Personenkürzeln (nur zur Kenntnis) | RC: github.com/gumyr, bernhard-42, messense, mikedh, secnot, fontanf (+ fontanf.github.io), groue, gsdali, pzfreo, neka-nat, dprojects, CreativeDesigner3D, metafloor. RS: github.com/joergs-git, swhitty, schwa, warrenm, fwcd, juj, wabiverse, gsdali (+ gsdali.github.io). RP: …/Yu11.html (Q49). | – | als Quellen-URLs zulässig; keine Änderung nötig. |

---

## 7 Risiken und Fehlentscheidungen

**R1 Swift-Kern** (Owner-Vorgabe, daher gesetzt) · mittel. Das Risiko liegt in der Breite: 8.000–13.000 Zeilen neuer Code (RS 10), darunter DXF-, STEP-, GLB-, PDF-, QR- und Guillotine-Writer, die es in Python schon gibt, und trotzdem Python-Sidecars für B-Rep und CP-SAT. Ergebnis wäre ein Zwei-Sprachen-System mit doppelten Implementierungen. Vorschlag: Swift-Kern zuerst nur für Modell, Werteauflösung, Regeln, Teile, Zeichenliste, CSV/ZPL/SVG und CoreGraphics-PDF. DXF/STEP erst bauen, wenn F12 und die Werkstatt (F2/F3) es verlangen. F13 („Hilfsprozesse in der App?“) vor Stufe 1 entscheiden, weil davon Stufe 1 (Typst), 3 (CP-SAT) und 4 (STEP mit Bohrungen) abhängen.

**R2 Typst** · mittel bis hoch. (a) Der Owner nennt HTML/Mustache/DXF/DWG als vom Nutzer anpassbare Formate; Typst ist Code-Satz und für Nichtprogrammierer schwer editierbar. (b) „Mustache arbeitet auf jedem Text gleich“ (L229) stimmt nur syntaktisch. Escaping ist je Format verschieden: Mustache escapt HTML; in Typst sind `#`, `$`, `*`, `_`, `[`, `]` aktiv, in ZPL `^` und `~`, in DXF zerstört ein Zeilenumbruch die Gruppencode-Paare. Ein Teilname kann so Ausgaben beschädigen. (c) Typst liest JSON selbst (`json()`/`sys.inputs`, RC 2, RS 3), Mustache in Typst ist überflüssig. (d) Typst ist 0.x und muss gepinnt werden; der Helfer muss in der Sandbox signiert eingebettet werden. Vorschlag: vom Nutzer editierbare Vorlagen als SVG/HTML mit Mustache und Escaper je Format; Planblätter sind meist einseitig, dafür könnte `WKWebView.createPDF` mit fester Seitengröße reichen, denn der Paginierungsfehler betrifft mehrseitige Ausgaben [Einschätzung, per Spike prüfen]. Typst nur intern für mehrseitige Stücklisten, falls F13 es erlaubt. E14 per Spike in Stufe 0 entscheiden.

**R3 Eigener MCP-Server** · mittel. 600–1.000 Zeilen (RS 8) unterschätzen die Pflege: Protokollversionen, Capabilities, Abbruch, Fortschritt, strukturierte Ausgaben, später Streamable HTTP und OAuth für die SaaS. Das Argument „nur GRDB“ (§1.3) trifft `kitchen-mcp` kaum, weil es ein eigenes Executable außerhalb der App ist. Vorschlag: transportfreier Werkzeugkern (Registry, Schemas, Dispatcher; so auch RS „MCPKern“) und swift-sdk nur im Executable `kitchen-mcp`; eigener Transport nur, wenn swift-sdk scheitert. Zusätzlich fehlt im Kapitel der RS-8-Befund, dass AMFI sandboxed Standalone-CLIs beim Start durch fremde Apps ablehnt; die Empfehlung „eigene Sandbox + App Group“ (L310) ist damit unbewiesen. Vor Stufe 5 als Spike prüfen; Ausweg laut RS 8: Developer-ID-Proxy (stdio → localhost).

**R4 Sidecars** · mittel. Python (build123d, OR-Tools) in einer signierten, sandboxed macOS-App bedeutet eine eingebettete Laufzeit mit vielen nativen Bibliotheken, Notarisierung und Größe [Einschätzung]. Vorschlag: In der Desktop-App nur native Einzelbinaries (Typst; PackingSolver hat eine C++-CLI, RC 3); Python nur in CI, Entwicklung und SaaS. Das Sidecar-Protokoll braucht Vertragstests und gepinnte Versionen (PackingSolver 0.1.x, build123d 0.x).

**R5 Würgefeige-Plan** · hoch. (a) Kein Rückweg Fusion → Modell (s. 1.2): Solange täglich in Fusion gearbeitet wird, driftet das Modell oder Arbeit geht verloren. (b) Fowlers „transitional architecture“, also eine Stelle, die entscheidet, ob alter oder neuer Weg ausliefert, fehlt; `kueche` könnte sie sein, kommt aber erst in Stufe 5. (c) Strenges Gating („nächste Stufe erst danach“) plus „5 Projekte in Folge“ (Stufe 4) kann bei unbekanntem Projektvolumen (RF 9 Nr. 9) Monate blockieren. (d) „Fusion bleibt für Sonderformen“ teilt die Wahrheit: Sonderformen sind nicht im Modell. Vorschlag: Werkzeug `fusion_abgleich`; Fusion-Sonderformen als `freiform`-Element mit Hüllquader und STEP-Verweis; synthetischer Testkorpus (z. B. 20 parametrische Küchen) neben echten Projekten; unabhängige Stufen (Bibliotheken, Prüfregeln) parallel erlauben.

**R6 Schema zuerst mit quicktype** · mittel. Byte-gleicher Roundtrip ist so nicht erreichbar (W20). Deutsche Feldnamen landen als Swift-Properties; falls §1.4 englische Namen verlangt, braucht es ein Mapping. Ob quicktype `$defs` und dateiübergreifende `$ref` aus Draft 2020-12 vollständig umsetzt, ist ungeprüft [unsicher]. Vorschlag: Spike in Stufe 0 (alle sechs Schemata → Swift → Beispiele semantisch zurück); sonst Swift-Typen von Hand und das Schema als Test-Orakel.

**R7 Koordinaten** · hoch. Siehe W1 und B1. Das ist der einzige Befund, der unbemerkt falsche Fertigung erzeugen kann (gespiegelte Küche, Bohrungen auf der falschen Seite). Vor jeder weiteren Arbeit beheben.

**R8 Determinismus als Fundament der Golden Masters** · mittel. Siehe W18, W19. Golden Masters auf Ebene Zeichenliste und kanonisches JSON, nicht auf PDF- oder STEP-Bytes; Solver mit festem Seed, einem Worker und deterministischem Zeitbudget, Ergebnis in der Revision gespeichert.

---

## Die 10 wichtigsten Korrekturen (Reihenfolge)

1. **Koordinatensysteme rechtshändig und eindeutig festlegen** (Raum und Teil, mit Skizze, inkl. Schmalflächen), Beispiel-Freiraum und Bearbeitungen korrigieren, Kreuzprodukt-Test ins Prüfskript (W1, B1, B2, R7).
2. **Eingabeklassen und Herkunft entwirren**: `annahme` nur für Unbestätigtes; Planungsbogen bekommt `vorgaben.werte`, Maßquelle je Maß und feste Elemente (W6, W12, W13, S8, 1.35).
3. **Eine Stufenzählung und ein Ausgaben-Vokabular** (gemeinsames Enum für Bogen, Setup und `ausgeben`) (W3, W7, A1).
4. **Werkzeugschema schreiben** (`werkzeuge.schema.json`) und Werkzeugliste schließen: `bogen_speichern/aendern`, `revision_freigeben`, `aufmass_importieren`, `fusion_abgleich`; Revisionsregel je Werkzeug (A2, A3, W11).
5. **Küchenmodell ergänzen**: `freigabe`, `fest`, `variante`/`scores`, `annahmen` als Schlüssel; Schemata schließen (`additionalProperties: false`, `if/then` je `art`, ID-Muster, `bibref.stand` Pflicht) (S9, S11, W21).
6. **Prüfskript ausbauen**: Invarianten 1–6, Negativbeispiele mit erwarteten Fehlerpfaden, Beispiele für `teil` und `bibliothekseintrag`, `date-time`-Prüfung; Beispiele auf Invarianten bringen (P1–P4, B3–B5).
7. **Stufe 0 um Entscheidungen erweitern**: E12, E14 (Spike), F13 vor Stufe 1; minimale Material-/Kanten-Einträge; Bestellliste einer Stufe zuordnen; Vorlagen-Inventar (W14, W15, W26, W27, 1.3).
8. **Vorlagenweg überarbeiten**: Escaper je Format, Typst nur mit nativem JSON, vom Nutzer editierbare Vorlagen in SVG/HTML, Feldkatalog, Bemustern zunächst aus PDF (R2, W5, 1.5).
9. **Fertigungsschema vervollständigen**: Säge-Parameter typisiert (Kerf, Besäumung je Seite, Stufen, Plattenseiten), Bearbeitung mit z/Richtung/Durchgang/Bögen, Bohrbild-Bezug, kurze Teilnummer für Code 128, Bestellposition, Montage je Element, Innenausstattung (S1–S7, S10, W22).
10. **Belege bereinigen**: Peka nachrecherchieren und die falsch etikettierte Quelle ersetzen; unbelegte Aussagen als „Vorschlag:“ markieren (Semikolon/BOM, `grossserie_v1.md`, Runde-3-Quote); Übertreibungen glätten (Patent „genau“, Handbuchtexte, IDM „offen“); DXF-Version vereinheitlichen; „R:5“ auflösen; AMFI-Befund aus RS 8 aufnehmen (2.1, 2.2, 2.3, W4, R3).
