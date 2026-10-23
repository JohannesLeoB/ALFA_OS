---
name: spec-warenkorb
description: Warenkorb (Checkout, EK-Schutz): Funktionsbaum, Bestand im Fundus, kein Code in alfaos
metadata:
  type: project
---

# Warenkorb · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: fundus/alpha/Sources (Bestand, nicht in alfaos)

Körbe aus Katalogen, Positionen und Bündeln; Checkout an das Ziel, das Nutzer oder Firma wählen. Stufe 1, fertig Ende November 2026.

F01 = KORB-F01. AUSSEHEN: Master zeichnet Warenkorb nicht (Brief v14 Teil 6); Texte ohne Zeichnung in `INHALT.json`. Bestand = `fundus/alpha/Sources/`; Hub = `alfaos/Kit/Sources/Hub/`.

## Regeln
- R01 Zwei getrennte Körbe: Artikel und Medien (Papers).
- R02 Die App kann zuerst alle Wege, Ziele und Optionen; einschränken später in den Einstellungen.
- R03 Checkout-Ziele hängen an Hub-Routen; sevDesk ist ein Ziel unter mehreren.
- R04 EK in Exporten ist Einstellung je Firma, Nutzer und System; nie fest im Code.
- R05 EK, Margen und Einkaufskosten gehen nie von selbst aus der App; ein Mensch löst aus.
- R06 Mailentwurf mit PDF durch den Assistenten enthält keinen EK.
- R07 ZIP und CSV sind für interne Verwendung.
- R08 Eine Auftragsbestätigung ist erst tragend, wenn sie im Dateiort oder per sevDesk bestätigt ist.
- R09 Ein fehlender Preis bleibt leer.

## Korb
**F01 Zwei Körbe**  
WAS: Artikelkorb und Papers-Korb.  
WO: Kataloge, Papers.  
WARUM: Ware und Medien getrennt.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/Warenkorb.swift:4, :60; AlfaServices/Database/WorkBasketStore.swift.

**F02 Korb bearbeiten**  
WAS: Position hinzufügen, Menge, Rabatt, leeren, sichern.  
WO: Korb.  
WARUM: Angebot zusammenstellen.  
AUSSEHEN: INHALT.json:1163 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: Warenkorb.swift:77-89 (Summen EK, VK), AlfaServices/Airtable/WarenkorbListeStore.swift, AlfaKit/Domain/WarenkorbEintrag.swift.

## Checkout
**F03 Ziel wählen**  
WAS: je Weg, Ziel und Option, wohin der Korb geht.  
WO: Korb, Checkout.  
WARUM: ein Korb, viele Ziele.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/Wirbelsaeule/WirbelsaeuleFoundation.swift:214, :247; Hub: DocumentsPort leer (Ports.swift:14).

**F04 sevDesk**  
WAS: Positionen als Angebotsentwurf nach sevDesk, ohne Doppel.  
WO: Checkout.  
WARUM: Angebot ohne Abtippen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Wirbelsaeule/SevdeskPostboxCheckoutPort.swift:46-77, AlfaServices/Wirbelsaeule/CheckoutLedgerPort.swift.

**F05 Weitere Ziele**  
WAS: Kostenschätzung, Dokument, CSV, Geräteliste ohne Preise, Muster-Entwurf, Bestellung, Plankopf, Moodboard, ZIP.  
WO: Checkout.  
WARUM: jeder Weg aus einem Korb.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/CheckoutZiel.swift:29-70.

**F06 EK-Schutz**  
WAS: EK im Export nur nach Einstellung (R04–R07).  
WO: Checkout; Einstellungen.  
WARUM: Einkaufspreise bleiben intern.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: SevdeskPostboxCheckoutPort.swift:57, CheckoutZiel.swift:47 (fest).

**F07 Rückweg**  
WAS: Entwurf, Mail an den Kunden, Angebot in den Projektordner, Auftragsbestätigung (R08).  
WO: Checkout, Projekte.  
WARUM: Vorgang geschlossen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: CheckoutLedgerPort.swift, AlfaServices/Google/DriveOfferWatcher.swift.
