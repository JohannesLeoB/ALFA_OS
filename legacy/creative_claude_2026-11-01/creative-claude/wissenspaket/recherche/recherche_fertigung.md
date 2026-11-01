# Recherche: Fertigungsausgaben für die Tischlerei (Küche/Möbel)

Stand: 31.10.2026 · Web-Recherche, keine lokalen Quellen.
Kennzeichnung: **[belegt]** = Quelle sagt das so · **[unsicher]** = nicht oder nur indirekt belegt · **[Einschätzung]** = eigene Bewertung.

**Kurzfazit**
- Die Maschinenformate der Branche sind **proprietär**. Öffentlich und offiziell spezifiziert ist keines davon: weder HOMAG MPR/MPRX noch der Zuschnitt-Austausch PTX oder Blums BXF. Spezifikationen gibt es nur über Partnerprogramme oder Hersteller-Kontakte.
- **Offen und dokumentiert** sind nur die kaufmännischen Standards (BMEcat, openTRANS, ETIM, OCI, IDM über den DCC) und DXF/STEP als Geometrie.
- Der universelle, risikoarme Weg in die Tischlerei ist eine **Teileliste als CSV/Excel** (Cut Rite, Ardis und intelliDivide lesen sie ein). Dazu kommen **DXF pro Teil/Fläche mit Layer-Konvention**, **PDF-Zeichnungen** und **Etiketten**.
- Tischler akzeptieren fremde CNC-Programme nur zögerlich, weil fehlerhafte Programme die Maschine gefährden können [belegt, Forum]. Die Werkzeugnummern sind ohnehin maschinenspezifisch.

---

## 1 HOMAG-Ökosystem

### 1.1 woodWOP – MPR / MPRX / MPRXE
- woodWOP ist die CNC-Programmiersoftware von HOMAG/Weeke. Die Versionen reichen von 1.0 (1991) bis 8.1 (2023). MPRX gibt es seit 6.1 (2012), MPRXE („Exchange-Format“) seit 8.0 [belegt]. Laut HOMAG-Broschüre können externe CAD/CAM-Systeme über MPRXE den Wizard-Makro und String-Variablen ansteuern [belegt].
- MPR ist ein **Textformat**. Laut einer Drittquelle (Mozaik-Supportartikel) besteht es aus dem Header `[H` (u. a. VERSION, MAT, INCH, FM/FW-Vorschübe, ZS), dem Werkstück `<100` (LA, BR, DI = Länge, Breite, Dicke), den Bearbeitungsmakros `<10x` (z. B. `<102 BohrVert` mit XA, YA, TI, DU, `<103 BohrHoriz`) und dem Ende `!` [belegt in Drittquelle]. **[unsicher]** Die Makronummern sind nicht mit HOMAG-Dokumentation abgeglichen und müssen an echten MPR-Dateien der Tischlerei geprüft werden.
- **Eine öffentliche Spezifikation von HOMAG wurde nicht gefunden** [unsicher, ob sie existiert]. Wer MPR schreibt, stützt sich auf Partnerdokumente oder Beispieldateien. TopSolid nennt im eigenen Handbuch die Exportwahl „WoodWop 4 oder 5“ [belegt].
- Viele Programme schreiben MPR: Polyboard Pro PP (natives MPR), TopSolid'Wood und Alphacam [belegt]. Für Autodesk Fusion gibt es einen woodWOP-Postprozessor (HSM), der MPR ausgibt [belegt, Forum; Stand und Umfang unsicher].
- Ab woodWOP 7.0 lassen sich 3D-Daten als DXF, STEP und IGES importieren, ab 7.1 auch STL. Version 8.0 erkennt Nuten, Taschen und 2D-Bohrungen als Features [belegt].
- Seit 6.1 importiert woodWOP DXF auch ohne Layerzuordnung. Mit Layern gilt die **woodWOP-DXF-Konvention** (siehe 3.2) [belegt].

Quellen: https://homag.com/en/software/woodwop-versions · https://wtp.hoechsmann.com/de/lexikon/pdf/hom_woodwop_8_81_2023_de.pdf · https://mozaik.support.cyncly.com/hc/en-us/articles/44440810771601 · https://www.p-s-s.de/files/2018/TopSolid_intern/Handbuecher/XX/15_Schnittstellenbeschreibung%20WoodWop.pdf · https://wooddesigner.org/homag-weeke-integration-polyboard/ · https://www.woodworker.de/forum/threads/fusion-360-und-schreiner-cnc.111781/post-713469

### 1.2 Cut Rite (dt. „Schnitt Profi(t)“), Zuschnittoptimierung
- Cut Rite ist ein HOMAG-Produkt, aktuell in **Version 12**. Es gibt die Editionen Advanced, Professional und Nesting sowie die Zusatzmodule „Auftragsbearbeitung/variable Stücklisten“ und „Lagerverwaltung“ [belegt].
- **Teilelisten-Import:** PTX, CSV und XLS(X) mit bis zu 50 Variablen. Plattenlisten lassen sich per CSV/Excel importieren. Teile kommen außerdem aus woodWOP-Dateien, der Teilebibliothek oder aus DXF [belegt]. Einen XML-Import nennt die Broschüre nicht [unsicher].
- **Parameter:** Sägeblatt- und Besäumeinstellungen (Schnittbreite, Besäumschnitt), Spannungsfreischnitte, materialabhängige Parameter, Maserung (längs/quer/keine), Maserungsbilder sowie Streifensortierung für Power Concept, combiTec und flexTec (je nach Edition) [belegt].
- **Plattenbibliothek/Lager:** Rohplatten und Reste, Reservierung pro Auftrag, Rücklauf von Resten. Plattenlager werden über eine SQL-Server-Schnittstelle angebunden [belegt].
- **Etiketten:** Ein Label-Designer für Text, Barcodes und Grafik. Gedruckt wird in Schnittreihenfolge oder an der Maschine, auch für Reste und Stapel. Barcodes dienen dem fehlerfreien Programmaufruf am BAZ [belegt].
- Microvellum schreibt „CutRite/Magicut V8.0+“. Der Name Magi-Cut hängt also historisch mit Cut Rite zusammen [belegt]; **[unsicher]** wer PTX ursprünglich definiert hat.

Quellen: https://www.hoechsmann.com/fr/lexikon/pdf/hom_cut_rite_11_2019_en.pdf · https://www.hoechsmann.com/pl/lexikon/pdf/hom_schnittprofit_version_12_cutrite_2022_de.pdf · https://stilesmachinery.com/software/cut-rite/ · https://intercom.help/microvellum-knowledge-base/en/articles/13910312-microvellum-saw-connections-reference

### 1.3 HOMAG-Softwarelandschaft (Cloud/tapio, iX)
- **HOMAG iX** ist das frühere woodCAD|CAM und heißt seit dem 1.4.2020 so. Entwickelt wird es von **imos AG** als Softwarelieferant [belegt]. Siehe auch 2 (imos gehört seit 2026 zu Cyncly).
- **intelliDivide Cutting** ist eine Cloud-Optimierung über tapio. Classic kostet 45 €/Monat, Advanced 95 €/Monat (10.000 Teile), Premium 395 €/Monat (100.000 Teile), jeweils netto [belegt]. Teile kommen per Upload, Copy&Paste oder über eine CAD/CAM- bzw. ERP-Schnittstelle. Ausgabe ist ein „HOMAG-SAW“-Format oder PDF. Fremdsägen funktionieren nur eingeschränkt [belegt].
- **productionManager** ist die digitale Auftragsmappe; jedes Teil hat eine eigene ID. Die Basisversion ist kostenlos [belegt]. Der **materialManager** verwaltet Material und Platten und dient als ERP-Datenschnittstelle [belegt].
- **smartWOP** (CAD) erzeugt CNC-Programme, Stücklisten und Zeichnungen und übergibt sie an productionManager und intelliDivide [belegt].
- **Zuschnitt-Assistent** (HOMAG Schweiz, 2021): CHF 4.190 inklusive **Zebra GK420D**. Die Etiketten enthalten „alle wichtigen Informationen inkl. Kantenbild und Barcode“ [belegt].
- **Kantenanleimmaschine:** Mit woodCommander/„HOMAG Select“ werden Programme über Tags und Werkstückinformationen gewählt; Kanten lassen sich mit Bearbeitungsprogrammen verknüpfen. Ein Edge Data Plugin bindet den Kantenband-Assistenten an [belegt]. **[unsicher]** Das genaue Datenformat (Barcode → Programmnummer) ist nicht öffentlich beschrieben.
- **Nesting:** Das woodWOP-8-Nesting-Plugin ersetzt woodNest Basic. Daneben gibt es intelliDivide Nesting und die Cut-Rite-Nesting-Edition [belegt].

Quellen: https://www.homag.com/en/news-events/news/article/woodcadcam-becomes-homag-ix · https://www.tapio.one/en/intelliDivide-cutting · https://info.tapio.one/downloads/intelliDivide_adv_PD_ENU.pdf · https://furnitureproduction.net/products/smartwop-and-productionmanager-homags-dynamic-software-duo · https://www.homag.com/fileadmin/service/promotion/homag_schweiz_DF_Zuschnitt_Assistent_DE_2021_05_18.pdf · https://www.homag.com/fileadmin/product/edge/brochures/woodcommander/edge-software-woodcommander-de.pdf

**Andocken an HOMAG** [Einschätzung]: (a) Teileliste als CSV/XLSX für Cut Rite oder intelliDivide, (b) DXF nach woodWOP-Layerkonvention für das BAZ, (c) MPR erst, wenn echte Beispieldateien und die Werkzeugtabelle der Tischlerei vorliegen, (d) PTX und MPRXE nur mit Partnerdoku von HOMAG.

---

## 2 CAD/CAM-Systeme der Branche: wie sie CNC-Daten erzeugen

| System | Hersteller / Eigentümer | CNC-Ausgabe | Bemerkung |
|---|---|---|---|
| **Palette CAD / Palette CAM** | Palette CAD GmbH | an „WOP-Systeme gängiger CNC-Hersteller“; Formate auf der Website nicht genannt [unsicher] | CAM nur zusammen mit CAD erhältlich; Blum-Integration (Konfigurator, BXF-Import, CAD2BXF → EASYSTICK) ab V7 kostenlos [belegt] |
| **imos iX** | imos AG, Herford; nicht Weinig. Kooperation mit HOMAG seit 2010 (HOMAG eSOLUTION), **von Cyncly übernommen, gemeldet am 21.08.2026** [belegt] | iX CAM erzeugt CNC-Programme „für alle gängigen Maschinenhersteller“, Nesting, Barcode-Etiketten, Produktionslisten [belegt] | technologische Basis von HOMAG iX; Auswirkungen der Übernahme auf HOMAG iX offen [unsicher] |
| **SWOOD** | EFICAD / Dassault Systèmes, Add-in für SolidWorks | anpassbare Postprozessoren, G-Code; u. a. Biesse, HOMAG, SCM [belegt]; ob nativ MPR/CIX: [unsicher] | Nesting als separates Modul |
| **TopSolid'Wood** | TopSolid (ehem. Missler) | TopSolid'WoodCam mit Postprozessoren, die mit Maschinenherstellern entwickelt wurden; dokumentierter MPR-Export (woodWOP) und bSolid-Schnittstelle [belegt] | Parasolid-Kern |
| **Cabinet Vision** | Hexagon | S2M Center; UCS-Skripte (auch JavaScript); True-Shape-Nesting; xLabel mit QR (seit 2023); importiert Blum **BXF2** (2025.1) [belegt]; erzeugt u. a. SCM-XXL [belegt, Drittquelle] | |
| **Microvellum** | Microvellum | „Processing Stations“; die Station „CutRite ASCII“ schreibt **PTX**; Sägen: Biesse Optiplanning-XML/CPOUT, SCM MaestroCut-XML, Sigma, Schelling; CNC-Auto-Labeling [belegt] | AutoCAD-basiert [unsicher, auf der Produktseite nicht bestätigt] |
| **Polyboard / OptiCut / OptiNest** | Wood Designer | Polyboard: natives MPR, DXF-Postprozessor mit Layer-Variablen, Biesse CIX (BPP nur über Biesse BatchRun); OptiCut: Holzma **PTX** + HolzLink, Biesse Selco XML/CPOUT/NC500 [belegt] | Barcode auf dem Etikett = Name der CNC-Datei je Fläche [belegt] |
| **Mozaik** | Cyncly | G-Code; kostenlose Standard-Postprozessoren für über 175 Marken als **offene, editierbare Textdateien**; 225 $/Monat [belegt] | NBM-Etiketten, CNC-Auto-Labeling |
| **Ardis** (Optimierer) | Ardis | herstellerunabhängig, über 30 Maschinenhersteller; Import SQL/CSV/Excel/Access/XML/TXT [belegt] | in DE-Tischlereien oft neben imos im Einsatz [Forum] |

**Maschinenseitige Formate** (nur Überblick): HOMAG/Weeke MPR/MPRX/MPRXE; Biesse CIX (bSolid/BiesseWorks) und BPP (vom Barcode-Scanner der Maschine gelesen) [belegt, Forum]; SCM XXL (Xilog) und PGM für ältere Xilog 3 [belegt, Drittquelle], PGMX (Maestro) [unsicher]. Sägen: PTX (HOMAG/Holzma, laut Optimalon auch SCM), Biesse Optiplanning-XML/CPOUT, SCM MaestroCut-XML [belegt].

**Allgemeines Muster** [Einschätzung]: Alle Systeme halten ein **internes Teile- und Bearbeitungsmodell** und erzeugen daraus mit **maschinenspezifischen Postprozessoren** (Werkzeugtabelle, Nullpunkt, Flächenbezug) die Ausgaben. Zuschnitt und Nesting werden fast immer an einen Optimierer (Cut Rite, Ardis, intelliDivide) delegiert.

Quellen: https://palettecad.com/en/palette-cam · https://www.blum.com/de/de/services/produktion-fertigung/cad-cam-schnittstelle/schnittstellenpartner/palette-cad/ · https://www.ta.com/news/cyncly-acquires-imos-adding-leading-cadcam-integration-and-automation-capabilities-to-its-kitchen-bathroom-and-furniture-manufacturing-platform/ · https://woodindustry.ca/cyncly-acquires-imos-to-expand-cad-cam-and-furniture-manufacturing-capabilities/ · https://financialreports.eu/filings/homag-group-ag/ma-activity/2010/2113885/ · https://imos3d.com/en/products/manufacturing-assembly · https://www.goengineer.com/swood/cam · https://www.topsolid.com/en/products/topsolidwood · https://hexagon.com/products/product-groups/computer-aided-manufacturing-cad-cam-software/cabinet-vision/release-history · https://industrialmonitordirect.com/blogs/knowledgebase/scm-icut-post-processor-selecting-xxl-or-pgm-output · https://intercom.help/microvellum-knowledge-base/en/articles/13909668-cut-rite-ptx-parts-file-import-from-microvellum-overview · https://wooddesigner.org/help-categories/opticut-cnc-saw-integration/ · https://wooddesigner.org/forum/cnc-and-other-software/biesse-cix-and-bpp-file/ · https://www.mozaiksoftware.com/products/mozaik-cnc · https://www.moldtech.de/wp-content/uploads/Broschuere-Ardis-Optimizer.pdf

---

## 3 Offene Austauschformate für Zuschnitt und CNC?

### 3.1 PTX („Pattern Exchange“)
- PTX ist ein **kommagetrenntes Textformat** für Teile, Platten, Schnittbilder und Schnittinformationen [belegt]. Zeilen beginnen mit einem Satztyp, z. B. `PARTS_UDI` mit den Feldern INFO1 bis INFO60. Leere Felder werden als aufeinanderfolgende Kommas geschrieben. Kommas in Namen verschieben die Daten und beschädigen die Datei [belegt].
- Optimalon nennt die Version **1.08** und als direkte Nutzer HOMAG Plattenaufteiltechnik und SCM [belegt].
- Schreiben können PTX unter anderem Microvellum, OptiCut und Optimalon (Online-Tool) [belegt].
- **Eine öffentliche Spezifikation wurde nicht gefunden.** Satztypen außer PARTS_UDI (z. B. HEADER, JOBS, BOARDS) sind **nicht verifiziert** [unsicher]. PTX ist ein **De-facto-Standard aus dem HOMAG-Umfeld, kein offener Standard** [Einschätzung].
- Ein **herstellerneutrales, offenes Zuschnitt-Austauschformat wurde nicht gefunden.** In der Praxis dient **CSV/Excel mit konfigurierbarer Spaltenzuordnung** als gemeinsamer Nenner, denn Cut Rite, Ardis und intelliDivide lesen es alle ein [belegt je Produkt].

### 3.2 DXF-Layer-Konventionen für CNC/Nesting
- **Es gibt keine branchenweite Norm**: Jede CAM- oder Maschinensoftware hat eigene Layer-Codes [belegt indirekt, Polyboard: z. B. anderes Dezimaltrennzeichen „P“ für Masterwood].
- **woodWOP-DXF (Postprozessor 5.0 Basic):** Werkstück `Werkstk_<Dicke>` (z. B. `Werkstk_19_5`), Bohren `V_Bohr<Modus>_<Tiefe>` (z. B. `V_BohrLS_8`), Tasche `V_Tasche_10`, Werkzeug `T<Nr>` (z. B. `V_Fraes_-3T145`), Schwenkwinkel `W<Grad>`, Unterflur `U_…`, horizontal `H_…`. Bohrungen sind nur als Kreise erlaubt, 1 Zeichnungseinheit = 1 mm [belegt]. Der Durchmesser kommt vermutlich aus der Kreisgeometrie [unsicher].
- **Polyboard-DXF:** Werkzeugname als Layer-Variable; Taschen mit 2 Layern (Kontur + Ausräumen); wahlweise eine Datei pro Teil (Nesting/6-seitig) oder pro Fläche (`…_f1.dxf`) [belegt].
- **OPC UA for Woodworking (OPC 40550-1)** beschreibt Maschinenstatus, Meldungen, KPIs und Job-Strukturen, aber **kein Bearbeitungsprogramm-Format** [belegt/unsicher: Job-Inhalt nicht vollständig geprüft].

Quellen: https://www.globenewswire.com/news-release/2021/02/25/2183039/0/en/Optimalon-Software-Introduces-Support-for-CNC-Saw-Machines-in-Online-Panel-Cutting-Tool-by-Generation-PTX-Files.html · https://optimalon.com/online_cut_optimizer.htm · https://www.homag.com/fileadmin/software/downloads/woodwop-dxf_import_basic.pdf · https://wooddesigner.org/help-centre/polyboard-post-processor-parameters-dxf/ · https://reference.opcfoundation.org/specs/OPC-40550-1/1

---

## 4 Beschläge & Zubehör

### Blum
- **E-SERVICES:** Registrierung kostenlos; den Zugang zu einzelnen Anwendungen schaltet die Blum-Ansprechperson frei [belegt].
- **Produkt- und Korpuskonfigurator** (kostenlos, web). Ausgaben: Beschlagliste, Holz- bzw. Zuschnittliste, Bearbeitungsübersicht und Fertigungszeichnungen, CAD-Export, **BXF** [belegt].
- **BXF = „Blum eXchange-Format“** mit Beschlag- und Fertigungsdaten der Holzteile (Zuschnitte, Bohrpositionen). Es geht in CAD-Software oder an MINIPRESS/EASYSTICK. **Schnittstellen-Details für Softwarepartner gibt es nur über die Blum-Ansprechperson** [belegt]. Eine Version **BXF2** existiert (Cabinet Vision 2025.1) [belegt].
- **CAD/CAM-Datenservice:** 3D-Daten, 2D-Fertigungszeichnungen mit Bohrpositionen und CAM-Bearbeitungsmakros („WOP-Formate für die meisten Hersteller“) [belegt].
- **Produktdaten-Service** für Softwarepartner: Komplettpaket mit Updates. Format und Konditionen werden nicht genannt [unsicher].
- **Schnittstellenpartner:** u. a. IMOS, CAD+T, cadwork, SmartWOP, TopSolid'Wood, Polyboard, PaletteCAD, Swood, CABINET VISION, alphacam, Vectorworks [belegt].
- **Bestellung:** „Meine Bestelllisten“ und eine Händlerschnittstelle zu über 190 Online-Shops [belegt]. Der Mechanismus (OCI? Warenkorb-URL?) ist **nicht dokumentiert** [unsicher].

### Hettich
- **Hettich Plan:** browserbasierter Korpuskonfigurator. Er liefert Artikel, Zuschnittlisten und CAD-Daten; registrierte Nutzer können an Händler oder Hettich bestellen [belegt]. Der Produktname „Plan & Order“ **wurde nicht gefunden** [unsicher].
- **CAD-Pakete:** DWG/DXF (2D/3D), SAT, STEP, IGES, 3DS, MAX [belegt].
- **CAD-Partnerliste 2026** mit rund 30 Partnern (u. a. imos, Palette CAD, Microvellum, Mozaik, SWOOD, TopSolid, Cabinet Vision, Vectorworks interiorcad). **CADENAS** ist als PARTcommunity-Portal in den eShop eingebettet: kostenloser Download nach Registrierung [belegt].

### Grass, Häfele, Kesseböhmer
- **Grass:** iFurn-Datenbank (Login über GRASS), iFurn Composer für einfache Baugruppen, ZIP mit STEP je Produktgruppe; Partner u. a. TopSolid, PaletteCAD, imos (iMos3D), Pytha [belegt].
- **Häfele:** CAD-Datenbank mit rund 40.000 Artikeln (2D/3D) und kleine Rechner (Plattengewicht, Klappenbeschlag) [belegt]. Formate und CNC-Daten werden nicht genannt [unsicher].
- **Kesseböhmer:** CAD-Portal und FREElift-Konfigurator; Formate, Plattform und Bohrdaten sind **auf der Seite nicht angegeben** [unsicher].
- **CADENAS:** 3Dfindit ist die Hauptplattform, PARTcommunity die Vorgängerplattform. Über 134 Formate, kostenlose Downloads. Die **Nutzungsbedingungen stehen in einem eigenen Dokument, das nicht geprüft wurde** [unsicher].

### Bohrbilder
- **System 32:** Löcher Ø 5 mm, Abstand 32 mm, erste Reihe 37 mm von der Vorderkante, 12–14 mm tief. **Kein Normungsgremium**, sondern ein De-facto-Standard [belegt, Wikipedia].
- **Topfband:** Der Topf Ø 35 mm ist herstellerübergreifend gleich. **Die Schraublochbilder unterscheiden sich:** 45/9,5 (Blum; auch Hettich Selekta TB), 48/6 (Blum INSERTA), 52/5,5 (Hettich). Die Topftiefe beträgt z. B. 13 mm (Hettich Selekta) [belegt]. Bohrabstand zur Kante und Bohrtiefe hängen vom Produkt ab und **müssen aus Herstellerdaten kommen** [Einschätzung].

Quellen: https://www.blum.com/de/de/services/haeufig-gestellte-fragen/ · https://www.blum.com/de/de/services/planung-konstruktion-produktauswahl/korpuskonfigurator/ · https://www.blum.com/de/de/services/produktion-fertigung/cad-cam-schnittstelle/ · https://www.blum.com/ca/en/services/industrial-production/cad-cam-dataservice/ · https://www.blum.com/de/de/services/planung-konstruktion-produktauswahl/produktdaten-service/ · https://www.blum.com/at/de/landingpages/services/meine-projekte-meine-bestelllisten-haendlerschnittstelle/ · https://web.hettich.com/en-dk/hettich-plan/about-hettich-plan · https://web.hettich.com/en-ro/planning/hettich-cad/cad-data-packages · https://www.hettich.com/fileadmin/Hettich_International/Service/Overview_CAD-Partner-2026_EN.pdf · https://www.grass.eu/en/tec-center/cad-data/ · https://www.hafele.co.nz/en/info/service/configuration-tools/406/ · https://kesseboehmer.com/en/storage-solutions/eservices/cad · https://3dfindit.com/llms.txt · https://en.wikipedia.org/wiki/32_mm_cabinetmaking_system · https://www.woodworker.de/forum/threads/topfbaender-bohrbild.79322/post-304294

---

## 5 Kataloge & Bestellwesen

| Standard | Träger | Format | Zweck / Nutzer |
|---|---|---|---|
| **IDM** (Integriertes Datenmodell) | **DCC – Daten Competence Center e.V.**, Herford, seit 2002 | XML, Wurzelelement `T_NEW_CATALOG`; Varianten Küche/Bad 3.0, Polster, Wohnen 1.0, Living 4.0 | Typen, Merkmale/Optionen, Preislogik, Stücklisten mit Entscheidungsregeln. Genutzt von Serien-Küchenherstellern (z. B. Nobilia, Häcker, Leicht) für Planungs- und Handelssoftware [belegt]. Download der Spezifikation über dcc-moebel.org; **Zugangsbedingungen unklar** [unsicher] |
| **BMEcat** | BME e.V. | XML; 1.0 (1999), 1.2 (2001), 2005, 2005.2 (2022); Transaktionen T_NEW_CATALOG, T_UPDATE_PRODUCTS, T_UPDATE_PRICES | Katalogdaten B2B (Artikel, Preise, Merkmale); Klassifikation frei wählbar [belegt] |
| **ETIM** | ETIM International | Klassifikation; ETIM 10.0 (12/2024: 159 Gruppen, 5.640 Klassen); 11.0 für 12/2026 geplant; IXF (XML) bzw. xChange (JSON) | Merkmalsklassen, meist innerhalb von BMEcat [belegt]. Abdeckung von Möbelbeschlägen **ungeprüft** [unsicher] |
| **openTRANS** | Fraunhofer IAO + Uni Duisburg-Essen | XML; 2.1 (2009); RFQ, ORDER, ORDERRESPONSE, DISPATCHNOTIFICATION, INVOICE … | Bestell- und Belegfluss, abgestimmt auf BMEcat [belegt] |
| **OCI** (Punchout) | ursprünglich SAP, ERP-unabhängig | HTTP-Rücksprung mit Warenkorb | Einkauf aus dem ERP direkt im Lieferanten-Shop [belegt]; Alternative cXML |
| Weitere | DATANORM (Bau/Handwerk), EDIFURN (EDIFACT Möbel), OFML (Büromöbel) | | [belegt, Übersicht sepia] |

**Bewertung** [Einschätzung]: Für eine Tischlerei mit Einzelfertigung ist **IDM kaum relevant**, solange sie nicht über Küchenstudios verkauft. Für die Beschaffung von Beschlägen und Platten zählen eher Händler-Shops (Blum-Händlerschnittstelle, OCI/BMEcat beim Großhändler) oder einfache Bestelllisten (CSV mit Artikelnummer und Menge). Welche Händler OCI oder BMEcat anbieten, **wurde nicht verifiziert**.

Quellen: https://docs.roomle.com/rubens/content-creation/idm/idmformat.md · https://docs.roomle.com/rubens/content-creation/idm/idmabout.md · https://www.moebelmarkt.de/files/article/1850659873f31b03c18a233604df07d9.pdf · https://sepia.com/en/austauschformate-produktdaten · https://www.xictron.com/de/blog/bmecat-etim-produktkataloge-b2b-austauschen/ · https://smartstore.com/en/plug-in-automatizing-purchases-how-opentrans-optimizes-business-processes/ · https://conrad.ch/de/ratgeber/industrie-40/e-procurement-wiki/oci-punchout.html

---

## 6 Etiketten & Kennzeichnung

- **Übliche Inhalte von Teile-Etiketten** [belegt, zusammengeführt]: Auftrags- bzw. Projektnummer, Teilenummer, Bezeichnung, Maße (L × B × D), Material/Dekor, **Kantenbild** (welche Kante welches Band), Bearbeitungs- oder CNC-Programm-Code, Schrank/Raum, Sortier- und Verpackungsziel. In Polyboard/OptiCut steht als Barcode der **CNC-Dateiname je Fläche** (f1/f2). Wegen der kurzen Barcodes wird eine Seriennummer statt eines Namens empfohlen.
- **Teilenummerierung in der Praxis:** Auftragsnummer plus fortlaufende Nummer aus der Zuschnittliste, damit gleiche Teile unterscheidbar bleiben. Kurze Codes fester Länge halten den **Code 128** klein; der Klartext steht daneben. Etiketten z. B. 100 × 100 mm, beim Druck passend zur Auslaufrichtung gedreht [belegt, Forum].
- **1D vs. 2D:** Code 128 ist verbreitet, weil Scanner an Maschinen ihn sicher lesen. QR (ISO/IEC 18004) fasst mehr Daten; **Data Matrix (ISO/IEC 16022)** ist kleiner und in der Industrie üblich [belegt]. Cabinet Vision xLabel unterstützt QR seit 2023 [belegt].
- **Druckersprache:** Zebra-Drucker wie der GK420D im HOMAG-Paket sprechen **ZPL II**: `^XA`…`^XZ` (Format), `^FO` (Position), `^FD`…`^FS` (Daten), `^BC` (Code 128), `^BQ` (QR), `^BX` (Data Matrix) [belegt]. Ob andere Druckerhersteller ZPL emulieren, ist [unsicher]. Microvellum nutzt Vorlagen im Format 3×3", 4×2" und 8×4" [belegt].
- **Normen:** Für die Benennung von Bauteilen und Baugruppen in der Tischlerei **wurde keine Norm gefunden** [unsicher]. Relevant sind **DIN 919-1:2014-08** „Technische Zeichnungen – Holzverarbeitung – Grundlagen“ (u. a. Kurzzeichen für Holz- und Holzwerkstoffe; **ein neuer Entwurf erschien 10/2026, Einspruchsfrist bis 11.11.2026**) und **EN 1116:2018** (Koordinationsmaße für Küchenmöbel und -geräte) [belegt].

Quellen: https://www.idprt.com/Blog/print-apply-labeling-panel-furniture-flexible-lines.html · https://www.woodworker.de/forum/threads/etikettendruck.121666/post-905049 · https://wooddesigner.org/polyboard-opticut-bar-codes/ · https://intercom.help/microvellum-knowledge-base/en/articles/13917970-cnc-auto-labeling-systems-label-requirements · https://www.weber-marking.com/blog/what-is-the-difference-between-qr-code-and-data-matrix-code/ · https://docs.zebra.com/us/en/printers/software/zpl-pg/c-zpl-zpl-commands.html · https://www.dinmedia.de/de/norm/din-919-1/206892969 · https://www.din.de/en/wdc-beuth:din21:405364762 · https://www.dinmedia.de/de/norm/din-en-1116/275325871

---

## 7 Lizenz- und Rechtsfragen (keine Rechtsberatung)

- **Dateiformate an sich** sind nach EU-Recht nicht urheberrechtlich geschützt. Der EuGH hat in SAS Institute v WPL (C-406/10, 2012) entschieden, dass Funktionalität, Programmiersprache und Datendateiformate als solche nicht geschützt sind [belegt]. **Wörtliches Übernehmen aus Handbüchern** kann dagegen eine Verletzung sein. Partner-Spezifikationen (HOMAG, Blum) unterliegen in der Regel NDA- oder Vertragsbedingungen [Einschätzung].
- **Haftung:** Fehlerhafte CNC-Programme können Maschine und Werkzeug beschädigen. Freigabe und Verantwortung liegen in der Tischlerei, und das muss im Vertrag stehen [Einschätzung].
- **Marken:** Namen wie woodWOP, Cut Rite, BXF, CLIP top, ZPL nur beschreibend verwenden.
- **CAD-Daten der Hersteller** (CADENAS, Hettich, Blum): Die Nutzungsbedingungen vor Weitergabe in einer SaaS-Bibliothek prüfen; Re-Distribution ist vermutlich nicht erlaubt [unsicher]. Der saubere Weg sind die **Softwarepartner-Programme** (Blum Produktdaten-Service, Hettich/Grass-Partnerlisten).

Quellen: https://en.wikipedia.org/wiki/SAS_Institute_Inc_v_World_Programming_Ltd · https://www.fieldfisher.com/en/insights/sas-institute-inc-v-world-programming-limited

---

## 8 Empfehlung für unsere Architektur

**Grundsatz:** Ein eigenes, neutrales **Fertigungsmodell (JSON)** ist die einzige Wahrheit: Projekt → Möbel/Schrank → Teil (Material, Dicke, Fertigmaß, Faserrichtung, Kanten je Seite, Fläche f1/f2) → Bearbeitungen (Bohrung, Nut, Tasche, Kontur in Teilkoordinaten mit Bezug) → Beschläge (Artikelnummer, Position, Bohrbild-Referenz). Fusion ist heute **ein** Erzeuger dieses Modells, die spätere App ein anderer. Alle Ausgaben sind „Exporter“, die aus diesem Modell ableiten.

**Zuerst unterstützen (Stufe 1, risikoarm, universell)**
1. **Teile- und Zuschnittliste CSV/XLSX** mit konfigurierbarer Spaltenzuordnung (Presets für Cut Rite, Ardis und intelliDivide). Dazu eine Plattenliste.
2. **PDF-Werkstattunterlagen** im Studio-Stil (Maßzeichnung, Drei-Seiten-Ansicht, Teilezeichnung mit Bohrbild, Kantenbild). Darstellung an DIN 919-1 anlehnen.
3. **Beschlag- und Bestellliste CSV** (Hersteller, Artikelnummer, Menge, Bezug Teil/Schrank) zum Übertragen in Händler-Shops. Optional zur Kontrolle das Gegenmodell in Blum- oder Hettich-Konfiguratoren.
4. **Etiketten:** PDF (A4/Rolle) und **ZPL** für Zebra; Code 128 mit kurzer ID `<Auftrag>-<Teil-Nr>`, optional Data Matrix/QR mit Link ins Projekt.

**Nur über Austauschdateien (Stufe 2, mit Tischlerei abstimmen)**
5. **DXF je Teil/Fläche** mit **konfigurierbarer Layer-Zuordnung**; Preset „woodWOP-DXF“ (`Werkstk_`, `V_Bohr…_<Tiefe>`, `T<Nr>`), weitere Presets nach Bedarf.
6. **STEP** je Teil/Baugruppe für Tischlereien mit eigenem CAD/CAM (imos, HOMAG iX, TopSolid, PaletteCAD); dort entstehen die CNC-Programme.
7. **MPR** nur als Pilot: mit echten Referenzdateien und der Werkzeugtabelle der Tischlerei, Freigabe durch den Maschinenbediener. Fusion bietet dafür bereits einen woodWOP-Post.
8. **PTX, BXF und MPRXE** erst mit offizieller Partnerdoku (HOMAG, Blum). Bis dahin nicht per Reverse Engineering „raten“.

**NICHT nachbauen**
- **Zuschnittoptimierung und Nesting:** Ausgereifte Produkte gibt es ab 45 €/Monat (intelliDivide), dazu Cut Rite und Ardis.
- **Maschinen-Postprozessoren, Werkzeugverwaltung, Maschinensimulation:** Sie liegen bei Maschinenhersteller und Tischlerei.
- **Beschlags-Konfiguratoren mit Kollisionsprüfung** (Blum, Hettich): stattdessen Herstellerdaten nutzen oder Ergebnisse importieren.
- **ERP, Bestell-EDI und IDM-Katalogerstellung:** Das ist der Bereich von Serienherstellern und Branchensoftware.
- **Ein Etiketten-Designer:** feste, gute Vorlagen reichen.

**Beobachten:** Die Übernahme von imos durch Cyncly (08/2026), denn Cyncly hält nun imos, Mozaik und Compusoft/Winner. Dazu MPRXE und HOMAG-Cloud-APIs (tapio).

---

## 9 Offene Fragen an den Nutzer

1. **Welche Tischlerei(en)** fertigen für das Studio? Gibt es dort **Plattensäge** (Hersteller, Modell, Steuerung), **BAZ/CNC** (z. B. HOMAG/Weeke, woodWOP-Version), **Nesting** und **Kantenanleimmaschine** mit Barcode-Programmwahl?
2. Welche **Software** läuft dort (Cut Rite, intelliDivide, Ardis; imos, HOMAG iX, PaletteCAD, TopSolid …)? Kannst du **Beispieldateien** besorgen (Teileliste, MPR, DXF, Etikett)?
3. **Will die Tischlerei überhaupt CNC-Daten von uns**, oder lieber Teileliste, Zeichnungen und STEP, damit sie selbst programmiert? Wer trägt die Haftung?
4. **Beschlagstandard:** Blum, Hettich oder Grass? Über welchen **Händler** wird bestellt, und gibt es dort OCI oder einen Shop-Import?
5. Gibt es **Konstruktionsregeln** der Tischlerei: System 32, Verbinder (Dübel/Exzenter/Clamex …), Rückwand-Nut, Kantenstärken, Plattenmaterialien und -formate?
6. Ist ein **Etikettendrucker** vorhanden (Typ, Etikettengröße), und welche Inhalte wünscht die Werkstatt?
7. Sollen **Küchengeräte** (Einbaumaße, EN 1116) aus Herstellerdaten kommen oder manuell gepflegt werden?
8. **SaaS-Perspektive:** Sollen Partnerschaften (Blum-Softwarepartner, HOMAG/tapio) angestrebt werden, und ab welchem Zeitpunkt?
9. **Volumen:** Wie viele Küchen bzw. Möbel pro Jahr? Das entscheidet, ob Stufe 2 (MPR/DXF-Presets) den Aufwand rechtfertigt.
