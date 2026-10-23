---
name: spec-ziel
description: Ziel, Stufen, Plattform und Architektur der App: Regeln und Funktionsbaum mit Stand
metadata:
  type: project
---

# Ziel · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: alfaos/project.yml, alfaos/Kit/Sources, alfaos/App

Native macOS-App ALFA für Studios, Handwerk und Projektarbeit: ein Betriebssystem der Arbeit mit vielen Bereichen. Erste Nutzer: Designstudio in Hamburg, sechs Personen, Küchen, Interiors, Licht, Bäder; Händler vieler Marken; Google Workspace trägt Mail, Kontakte, Kalender, Dateien.

F01 = ZIEL-F01. AUSSEHEN: Zeile im Master (`ALFA Huelle.dc.html`, `ALFA Mail.dc.html`, `alfa-shell.js`). `App/` = `alfaos/App/`; `Kit/` = `alfaos/Kit/`. Brief v14.

## Regeln
- R01 Stufe 1, fertig Ende November 2026: Mail, Konten, Projekte (Akte, Fragebogen, Provisionierung), Heute, Kataloge, Warenkorb; ohne Kalkulation.
- R02 Stufe 2, bis Launch Ende 2026: alle übrigen Bereiche, Datan als Modul, 15 Integrationen in voller Tiefe.
- R03 Termine gleiten, Umfang und Qualität nicht.
- R04 Hub, Einstellungen und Mail zuerst; danach Projekte und Aufgaben, dann Kalender.
- R05 Mac zuerst; iOS, iPadOS, Web später und abgespeckt; die Bauweise sieht sie vor.
- R06 Vertrieb (App Store, Abo) wird ermöglicht, nicht gebaut.
- R07 Hub und Einstellungen in der Mitte; ringsum die Bausteine eines Vorgangs (Projekte, Aufgaben, Team, Zeit, Geld, Mail, Artikel, Daten); darunter die Schubladen; alles über den Hub verbunden.
- R08 Jede Schublade (Dienst, Speicher) ist die Wahrheit für ihre Stücke; ALFA spiegelt höchstens.
- R09 ALFA führt die Vorgänge und ihre Verknüpfungen; Mail, Anfrage, Termin, Entwurf, Aufgabe, Zeit, Artikel, Geld werden zu einem Vorgang.
- R10 Ein Vorgang entsteht in ALFA: vom Nutzer angelegt oder durch ein Ereignis ausgelöst.
- R11 Der Nutzer entscheidet, was zu einem Vorgang gehört; ALFA schlägt aus Kennung, Quelle, Zeit, Richtung und Bezug vor; ob automatisch, ist Einstellung.
- R12 Alles kann Vorgang werden; ab wie vielen Stücken, ist Einstellung.
- R13 Branchenwerte (Phasen, Ordner, Kostenstellen, Marken, Stufen) und Firmendaten sind Einstellungen oder Vorlagen je Firma, nie fest im Code.
- R14 Dateien kommen über neutrale Eingabe-Module herein und gehen über neutrale Ausgabe-Module hinaus (erzeugen, weitergeben); jeder Bereich nutzt sie über den Hub.
- R15 Angemeldet heißt alles dürfen; sperren kann nur die Firma.
- R16 Erwachsene Arbeits-App: keine Erklärsätze, Rückfragen nur wo üblich oder eingestellt, Rückgängig statt Frage.
- R17 Keine Farbwelten, kein ALFAcolor; nur das ALFA-Interface.

## Plattform
**F01 Native macOS-App**  
WAS: SwiftUI-App für macOS 26 mit Sandbox.  
WO: ganze App.  
WARUM: eine App auf dem Mac.  
AUSSEHEN: entfällt.  
STAND: gebaut, nicht abgenommen (`alfaos/project.yml:6`, `:67`, `:77`; App/ALFA_OSApp.swift:31).

**F02 Bereiche wie Apps**  
WAS: jeder Bereich ein Eintrag im Verzeichnis; der Blob führt zwischen ihnen.  
WO: Hülle › Blob.  
WARUM: neue Bereiche ohne Umbau.  
AUSSEHEN: alfa-shell.js:5-8 (nur Mail, Einstellungen).  
STAND: teilweise; Verzeichnis mit mail und settings (App/Resources/apps.json), Inhalt je Bereich fest verdrahtet (App/Shell/LaneView.swift:15-26).

**F03 Kern ohne Oberfläche**  
WAS: Logik im Paket Kit für macOS und iOS.  
WO: `Kit/Sources`.  
WARUM: später iPad, iPhone, Web.  
AUSSEHEN: entfällt.  
STAND: teilweise; Kit ohne SwiftUI (`Kit/Package.swift:8`), hängt am Fundus (`:15`), dort SwiftUI (`fundus/alpha/Sources/AlfaServices/Database/WorkBasketStore.swift:3`, `WidgetBoardStore.swift:3`).

**F04 Vorgang**  
WAS: Vorgang mit Stücken und Verknüpfungen (R09–R12).  
WO: Kern.  
WARUM: Wert entsteht im Vorgang.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt.

## Stufe 1
**F05 Hülle**  
WAS: gemeinsame Schablone jedes Bereichs.  
WO: ganze App.  
WARUM: ein Aussehen, ein Verhalten.  
AUSSEHEN: `ALFA Huelle.dc.html`, `ALFA Shell.dc.html`.  
STAND: gebaut, nicht abgenommen (spec-huelle).

**F06 Mail**  
WAS: Mail-Client für bis zu drei Postfächer.  
WO: Bereich Mail.  
WARUM: Rang 1.  
AUSSEHEN: `ALFA Mail.dc.html`.  
STAND: teilweise (spec-mail).

**F07 Hub, Einstellungen, Konten**  
WAS: Dienste verbinden, Einstellungen; Mail-Konten und Kontakte sind Integrationen.  
WO: Bereich Einstellungen.  
WARUM: Rang 1, Stecker zu den Schubladen.  
AUSSEHEN: `ALFA Mail.dc.html` (Einstellungen), `ALFA Dienste.dc.html`.  
STAND: teilweise (spec-hub; `Kit/Sources/Hub/`).

**F08 Projekte**  
WAS: Akte, Fragebogen, Provisionierung.  
WO: eigener Bereich.  
AUSSEHEN: nicht gezeichnet (Brief v14 Teil 6).  
STAND: fehlt (spec-projekte).

**F09 Heute**  
WAS: Startansicht mit Widgetbrett.  
WO: eigener Bereich.  
AUSSEHEN: nicht gezeichnet (Brief v14 Teil 6).  
STAND: fehlt (spec-heute).

**F10 Kataloge**  
WAS: Artikel, Positionen, Preise mit Beleg.  
WO: eigener Bereich.  
AUSSEHEN: nicht gezeichnet (Brief v14 Teil 6).  
STAND: fehlt (spec-kataloge).

**F11 Warenkorb**  
WAS: Körbe und Checkout mit EK-Schutz.  
WO: eigener Bereich.  
AUSSEHEN: nicht gezeichnet (Brief v14 Teil 6).  
STAND: fehlt (spec-warenkorb).

## Stufe 2
**F12 Übrige Bereiche, Datan, 15 Integrationen**  
WAS: Werkstatt, Assistent, Studio, Kalender, Kalkulation; Datan als Modul; 15 Integrationen.  
WO: eigene Bereiche, Hub.  
AUSSEHEN: nicht gezeichnet; Datan-Form Lücke.  
STAND: fehlt; Dienstkatalog hat 10 Einträge (`Kit/Sources/Hub/ServiceCatalog.swift:80-117`) (spec-spaeter).
