---
name: spec-kataloge
description: Kataloge (Artikel, Datan): Funktionsbaum, Bestand im Fundus, kein Code in alfaos
metadata:
  type: project
---

# Kataloge · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: fundus/alpha/Sources (Bestand, nicht in alfaos)

Artikel, Dienstleistungen und Positionen für Angebote und Warenkörbe: durchsuchbar, mit Preisen und Beleg der Herkunft. Stufe 1, fertig Ende November 2026; Datan als Modul in Stufe 2.

F01 = KAT-F01. AUSSEHEN: Master zeichnet Kataloge nicht (Brief v14 Teil 6); Texte ohne Zeichnung in `INHALT.json`. Bestand = `fundus/alpha/Sources/`.

## Regeln
- R01 Ein fehlender Wert bleibt leer; nie abgeleitet, gerundet oder erfunden.
- R02 Katalogdaten liegen in eigenen, sichtbaren Datenbanken; Airtable ist eine Hub-Route unter mehreren.
- R03 Kontakte, Zeichnungen, Aufgaben und Notizen gehören nicht in Kataloge.
- R04 Ob EK sichtbar ist, ist Einstellung je Firma und Nutzer.
- R05 Keine Firmen-IDs (Basis, Tabelle, Feld) fest im Code.
- R06 Datan beginnt erst nach dem Design-Nachzug.
- R07 Wird ein Preis einer Liste beanstandet, sinkt die Konfidenz aller Werte dieser Liste; umgekehrt steigt sie.

## Artikel
**F01 Artikel durchsuchen**  
WAS: Suche, Oberkategorien, Positionen in den Korb.  
WO: Kataloge.  
WARUM: Artikel für Angebote finden.  
AUSSEHEN: INHALT.json:1158, :1173, :1178 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/ArticleSearch.swift, AlfaKit/Domain/ArtikelItem.swift, AlfaServices/Airtable/ArtikelKatalogStore.swift, AlfaServices/Database/ArtikelKatalogGRDBCache.swift.

**F02 Eigene Positionen**  
WAS: eigene Positionen und Kataloge anlegen.  
WO: Kataloge.  
WARUM: Leistungen ohne Herstellerliste.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Airtable/EigenkatalogPort.swift.

**F03 Lager**  
WAS: Artikel auf Lager.  
WO: Kataloge.  
WARUM: Vorhandenes zuerst.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/LagerItem.swift, AlfaServices/Airtable/LagerlisteStore.swift.

**F04 Produktbilder**  
WAS: Bilder aus dem Dateiort am Artikel.  
WO: Kataloge.  
WARUM: Artikel erkennen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Airtable/MediathekAssetIndex.swift, AlfaKit/Domain/ProduktbildDateiname.swift.

## Preise
**F05 Preis prüfen**  
WAS: ungeprüft, verifiziert, beanstandet; Konfidenz, Quell-Beleg (R07).  
WO: Kataloge, Artikel.  
WARUM: Preisen trauen.  
AUSSEHEN: INHALT.json:1193 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/ArtikelReview.swift:3-30, AlfaServices/Airtable/ArtikelReviewVerdiktPort.swift.

**F06 Datan als Modul**  
WAS: Preislisten (CSV, PDF u. a.) einlesen, belegen, prüfen; Ergebnis im eigenen Datenspeicher.  
WO: Kataloge.  
WARUM: Preise aus Lieferantenlisten.  
AUSSEHEN: nicht gezeichnet; Form Lücke.  
STAND: fehlt; Bestand: AlfaCalculation/OfferPositionExtractor.swift, AlfaServices/Kalkulation/OfferPositionPDFReader.swift.

## Medien
**F07 Papers**  
WAS: Medien der Firma (Bilder, Texturen, Muster, Vorlagen) mit Metadaten, verknüpft mit Artikeln.  
WO: offen.  
WARUM: Quelle für Moodboard, Atelier, Konfigurator.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Airtable/PapersKatalogStore.swift, AlfaKit/Domain/PapersAssetAbgleich.swift.
