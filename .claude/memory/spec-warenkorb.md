---
name: spec-warenkorb
description: Warenkorb und Checkout mit EK-Schutz: Leitsätze von Johannes belegt (alle Wege können, EK einstellbar, zwei Körbe), Ziele und Rückweg offen, in ALFA nichts gebaut, im Master nicht gezeichnet.
metadata:
  type: project
---

# Warenkorb · Spec (Stand 21.10.)

Pfadkürzel: `fundus:` = `fundus/alpha/Sources/`; `labor:` = `~/Developer/mykilos-labor/Sources/` (Unterordner App, Kit, Services, Widgets tragen dort das Präfix des Altnamens). Bestand ist nur Herkunft der Fähigkeit, nie Vorlage für Aufbau, Zuschnitt oder Namen (J 20.10. 3f52450e).

## Ziel
Aus Katalogen, Positionen und Bündeln legt der Nutzer Körbe an und schickt sie über den Checkout an das Ziel, das er oder seine Firma wählt (Angebotsentwurf, Dokument, Liste, Bestellung, Projektablage). Einkaufspreise (EK) verlassen die App nur, wenn Firma oder Nutzer es eingestellt haben und ein Mensch auslöst. Der Bereich gehört zum Ziel Ende November (`AGENTS.md:9`). In ALFA gebaut ist nichts (`alfaos/App/Resources/apps.json` führt nur mail und settings); der Master zeichnet Warenkorb und Checkout nicht, nur Textlisten (`INHALT.json:1158-1205`).

## Richtung
- Die App kann zunächst alles (alle Wege, Ziele, Optionen, je Firma und je Artikelkatalog oder Bündel wählbar); Einschränken geschieht später in den Einstellungen.
- Checkout-Ziele hängen an Hub-Routen des Nutzers (sevDesk ist nicht der einzige Weg).
- Rückweg schließen: Entwurf, Mail an den Kunden, Ablage im Projektordner, bestätigte Auftragsbestätigung als tragender Stand.
- Papers-Korb für Medien (Texturen, Muster, Moodboards) und Artikelkorb bleiben getrennt.

## Funktionen
- **KORB-F01 Zwei getrennte Körbe**: Soll: Es gibt einen Artikelkorb (Katalog) und einen Korb für Medien (Papers), getrennt. Besitzer und Anzahl je Art: lücke. Ist: fehlt in ALFA; Bestand `labor:App/WarenkorbState.swift:7` (Positionen mit Menge, EK, VK, Rabatt, `:11-19`) und `labor:App/Papers/PapersWarenkorbState.swift:5`; gesicherte Körbe `fundus:AlfaServices/Airtable/WarenkorbListeStore.swift`. Status: offen. Quelle: J 04.10. ee8f053d Klick „Zwei getrennte Körbe“ · `~/ALPHA/ASSUMPTIONS.tsv:354`.
- **KORB-F02 Korb bearbeiten**: Soll: lücke (Positionen hinzufügen aus der Katalogliste, Menge, Rabatt, Position oder Korb leeren, Korb sichern). Ist: fehlt; Bestand `labor:App/WarenkorbPanel.swift` (1025 Zeilen), Rückfrage beim Leeren. Master-Wortlaute ohne Zeichnung: „Leer — + in der Liste legt hierher.“, „Kein gesicherter Warenkorb.“, Rückfrage „Korb leeren“ (`INHALT.json:1163-1205`). Status: lücke. Quelle: Master wie genannt (Design-Wortlaut, nicht sein Wort) · Bestand.
- **KORB-F03 Checkout an gewählte Ziele**: Soll: Der Nutzer wählt je Weg, Ziel und Option, wohin der Korb geht; Auswahl ist firmenspezifisch und gilt für verschiedene Artikelkataloge und Bündel; zunächst kann die App alles, Zudrehen später als Einstellung. Ist: fehlt; Bestand hat einen Checkout-Dialog „Ein Warenkorb, viele Ziele.“ (`labor:App/Papers/PapersWarenkorbPanel.swift:244`), ein Ziele-Blatt (`labor:App/CheckoutZieleSheet.swift`) und eine Port-Abstraktion mit Vorschau und Ausführung (`fundus:AlfaKit/Domain/Wirbelsaeule/WirbelsaeuleFoundation.swift:214,247`). Hub-Port für Dokumente ist leer (`alfaos/Kit/Sources/Hub/Ports.swift:14`). Status: offen. Quelle: J 20.10. 3f52450e „Nicht nur Entwürfe, je Weg/ziel/Options“, „DIE APP KANN ERSTMAL "ALLES"“ · Master: keine Zeichnung (KORB-L01).
- **KORB-F04 Ziel sevDesk**: Soll: sevDesk ist ein Ziel unter mehreren; Positionen aus Katalog, Dienstleistungen und herausgelösten Positionen eingehender Angebote gehen als Entwurf nach sevDesk. Ist: fehlt; Bestand legt ein Datenpaket „Angebotsentwurf“ in eine sevDesk-Postbox (Airtable) und zeigt vorher Vorschau und Warnungen (`fundus:AlfaServices/Wirbelsaeule/SevdeskPostboxCheckoutPort.swift:46-66,208-210`), mit Doppelschutz durch Objekt-Hash (`:68-77`) und Hauptbuch-Eintrag (`fundus:AlfaServices/Wirbelsaeule/CheckoutLedgerPort.swift:5,24`). Status: offen. Quelle: J 20.10. 3f52450e (Hub-Route, sevDesk nicht allein) · J 29.08. 6a6a9365 (Beschreibung des Weges; Wortlaut aus Auszug).
- **KORB-F05 Weitere Ziele**: Soll: lücke (welche Ziele bleiben, in welcher Reihenfolge). Ist: fehlt; Bestand kennt zehn Ziele: sevDesk-Angebot, Kostenschätzung ins Projekt, Paper-Dokument, CSV, Geräteliste für den Tischler (ohne Preise), Muster-Entwurf ins Projekt, Bestellung ins Projekt, Vectorworks-Plankopf, Moodboard (nicht verfügbar), ZIP (`fundus:AlfaKit/Domain/CheckoutZiel.swift:29-70`) und im Papers-Korb Adobe Creative Suite („geplant“), Moodboard, Plankopf (`labor:App/Papers/PapersCheckoutZiel.swift:38,48,58`). Status: lücke. Quelle: Bestand · J 20.10. 3f52450e (ob einzelne Ziele bleiben, nicht gesagt).
- **KORB-F06 EK-Schutz in Exporten**: Soll: Ob der EK in einem Export steht, wählen Firma oder Nutzer in den Einstellungen, passend zum jeweiligen System; ZIP und CSV sind für interne Verwendung; ein Mailentwurf mit PDF vom Assistenten mit EK gilt als Ausschluss-Fall. Ist: fehlt; Bestand hartcodiert: PDF nur mit VK (`labor:App/WarenkorbPDFExporter.swift:7-10`, Kopfzeile „Kalkulations-Vorschau — kein offizielles Angebot“ `:5`), CSV mit Spalte „EK-Einzel“ (`labor:App/WarenkorbCSVExporter.swift:46`), sevDesk-Paket ohne EK (`SevdeskPostboxCheckoutPort.swift:57`), Geräteliste ohne Preise (`CheckoutZiel.swift:48`). Einstellung und Standardwert: nicht gezeichnet. Status: offen. Quelle: J 20.10. 3f52450e Klick Q-A · J 27.08. 6a6a9365 · J 08.10. 476f45d7 (beide Wortlaut aus Auszug).
- **KORB-F07 Rückweg**: Soll: Aus dem Korb geht ein Entwurf nach sevDesk, von dort per Mail an den Kunden; das Papierangebot wird in den Projektordner zurückgespielt; erst eine im Dateiort oder per sevDesk-API bestätigte Auftragsbestätigung ist tragend und unveränderlich. Der Rückweg gilt von ihm als nicht vollständig geschlossen. Ist: fehlt; Bestand schreibt beim Checkout parallel in eine Airtable-Tabelle „Checkouts“ (`CheckoutLedgerPort.swift:24`) und beobachtet Angebote im Drive (`fundus:AlfaServices/Google/DriveOfferWatcher.swift`). Status: offen. Quelle: J 29.08. 6a6a9365 (Wortlaut aus Auszug) · Bestand wie genannt.

## Regeln
- **KORB-R01**: Einkaufspreise in Exporten sind Einstellung je Firma und Nutzer und je System oder Integration; nicht fest im Code. Quelle: J 20.10. 3f52450e Q-A „nicht hardcodet“.
- **KORB-R02**: Mailentwurf mit PDF durch den Assistenten enthält keinen EK. Quelle: J 20.10. 3f52450e Q-A („eher no go“).
- **KORB-R03**: EK, Margen und Einkaufskosten gehen nicht versehentlich aus der App; die App löst keinen Versand mit EK von selbst aus, ein Mensch entscheidet zuletzt. Quelle: J 27.08. 6a6a9365 „STRIKT und GLOBAL verhindern“ · J 08.10. 476f45d7 „Nie automatisch“ (beide Auszug) · J 20.10. 3f52450e („immer ein mensch der letzte“).
- **KORB-R04**: Die App kann erstmal alle Wege; Einschränkungen sind spätere Einstellungen. Quelle: J 20.10. 3f52450e.
- **KORB-R05**: Zwei getrennte Körbe: Artikelkorb und Papers-Korb. Quelle: J 04.10. ee8f053d.
- **KORB-R06**: Bestand wird in Funktion übernommen, nicht in Form, Namen, Texten oder Zuschnitt. Quelle: J 20.10. 3f52450e „ES soll NICHTS wieder genau das gleiche gebaut werden“.
- **KORB-R07**: Eine Auftragsbestätigung gilt erst als tragend, wenn sie im Dateiort oder per sevDesk-API bestätigt ist. Quelle: J 29.08. 6a6a9365 (Auszug).
- **KORB-R08**: Ein fehlender Preis bleibt leer und wird nicht abgeleitet (siehe spec-kataloge KAT-R01). Quelle: J 14.10. 476f45d7 (Auszug) · Bestand `SevdeskPostboxCheckoutPort.swift:57` überträgt bei fehlendem Verkaufspreis keinen Preis.

## Lücken
- **KORB-L01**: Keine Zeichnung für Warenkorb und Checkout: Korb-Leiste, Positionsliste, Ziele-Wahl, Vorschau, Bestätigung, Fehler- und Leerzustände. Liefert: Design. Beleg: Master hat 10 `*.dc.html` ohne Korb; nur Textliste `INHALT.json:1158-1205`; `~/ALPHA/Design/BOGEN-KATALOG.json:857-865` führt `catalog.checkoutTargets` mit `"drawn": false`.
- **KORB-L02**: Vorschau vor Bestätigung im Checkout. Liefert: Johannes. Beleg: sein Wort 20.10. Q9 gilt dem Anlegen von Projekten; die Zeile „Erst Vorschau, dann Bestätigung · nie automatisch“ steht nur im Bestand (`labor:App/CheckoutZieleSheet.swift:93`; die Bilder vom 20.10. zeigen laut `spec-warenkorb.md` einen ähnlichen Fußsatz); ausdrücklich bestätigt hat er sie nicht.
- **KORB-L03**: Einstellungsmodell für EK: Granularität (Firma, Nutzer, System, Weg) und Standardwert vor der Wahl. Liefert: Johannes mit Design. Beleg: Q-A nennt „Firma/User“ und „Systeme/Integrationen“, keinen Standard.
- **KORB-L04**: Welche der zehn Bestandsziele und welche weiteren (Shopify, Lexware u. a.) in ALFA kommen. Liefert: Johannes. Beleg: `CheckoutZiel.swift:29-70`; sein Wort 20.10. nennt nur „je Weg/Ziel/Optionen“.
- **KORB-L05**: Hub-Ports für Dokumente und Bestellungen sind leer; Ziel-Adapter fehlen. Liefert: Code (nach Zeichnung). Beleg: `alfaos/Kit/Sources/Hub/Ports.swift:14`.
- **KORB-L06**: Rückweg im Einzelnen (Mailversand durch wen, Ablageort des Papierangebots, Zustand „bestätigt“). Liefert: Johannes. Beleg: J 29.08. beschreibt Ist und „nicht geschlossen“, keine Zielfassung.

## Offen bei Johannes
- Gilt „entwirft nur“ (29.08., belegführende Dokumente) weiter, oder darf ALFA sie nach „Nicht nur Entwürfe“ (20.10.) selbst ausstellen?
- Welcher Standard gilt für EK in Exporten, bevor Firma oder Nutzer wählt?
- Bleiben beide Körbe, und welche Ziele hat jeder?
