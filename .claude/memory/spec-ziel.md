---
name: spec-ziel
description: Zweck, Stufen, Bereiche mit Rang, Plattform und Reichweite der ganzen App ALFA; Ist heute nur Hülle, Mail und Hub/Einstellungen, alles übrige fehlt.
metadata:
  type: project
---

# Ziel · Spec (Stand 21.10.)

Kürzel der Sitzungen: bc4854d7 (Lead 19./21.10.), 3f52450e (Produkt 18./20.10.), c2a04c8a (Lead 16.–18.10.), 97326b1d (16.10.), a9bb817c (12.10.), 055e95fd (08.10.). Ist = `Datei:Zeile` am 21.10. gelesen oder per grep gefunden. Alle Bereiche heute orange oder fehlend; Johannes hat keinen Bereich abgenommen.

## Ziel
ALFA ist eine native macOS-App für das Designstudio: ein Betriebssystem der Arbeit mit vielen Apps, das alles kann, was das Studio sonst in getrennten Diensten tut, und besser. Die Oberfläche (UI) ist das Hauptgut. Gebaut wird nach dem Design-Master und Johannes' Wort, funktionierend und sicher (AGENTS §1).

## Kern: der Vorgang
- **ZIEL-K01**: Die Daten bleiben in ihren Schubladen (Artikel, Medien, Aufgaben, Zeiten, Mails, Dateien, Belege); jede Schublade ist die Wahrheit für ihre Stücke, ALFA spiegelt sie höchstens als Zwischenspeicher. Quelle: J 21.10. bc4854d7 „Es liegt alles in verschiedenen Schubladen - ALFA macht was draus“.
- **ZIEL-K02**: Wert entsteht erst im Vorgang: Mail, Anfrage, Kontakt, Termin, Entwurf, Aufgaben, Zeit, Arbeit, Leistungen, Artikel, Material und Geld werden zu einem Vorgang verknüpft. ALFA führt selbst die Vorgänge und ihre Verknüpfungen (Verweise auf die Stücke in den Schubladen). Quelle: J 21.10. bc4854d7 (Vorgänge „aka Projekte, aka Tasks, aka Zeit, aka Geld …“).
- **ZIEL-K03**: Projekt, Aufgaben, Zeit und Geld sind Sichten auf den Vorgang, keine eigenen Inseln; der Hub ist der Stecker zu den Schubladen, der Vorgang der Knoten. Folgerung der Lead aus K01/K02, von Johannes noch zu bestätigen.
- **ZIEL-K04 Offen bei Johannes**: (a) Beginnt ein Vorgang vor dem Projekt (erste Anfrage), und ist Projekt ein Zustand des Vorgangs? (b) Wer knüpft: Nutzer, ALFA mit Vorschlag zum Bestätigen, oder beides? (c) Wo lebt der Vorgang, damit das Team ihn teilt (eigener Server oder eine Schublade wie Airtable)?
- Ist: Es gibt keinen Vorgang im Code; `HubRules.truth` hat keinen Aufrufer außerhalb des Hubs (`alfaos/Kit/Sources/Hub/HubCore.swift`, grep).

## Richtung
- Stufe 2 (bis Launch Ende 2026): alle übrigen Bereiche, Datan als Modul, 15 Integrationen in voller Tiefe (AGENTS §1).
- Assistent wird später ein eigener Bereich mit Menüeintrag; heute nur das Mini-Fenster im Blob (siehe spec-huelle).
- Distribution (Mac App Store, iOS, iPadOS, Web, Abo/SaaS) und andere Nutzerstrukturen: später, die Bauweise soll sie nur ermöglichen.
- Rollen als Einstellung statt im Code: später (siehe spec-arbeit ARBEIT-R19).

## Funktionen
Eine Funktion ist hier ein Bereich der App; die Inhalte trägt die jeweilige Spec.

- **ZIEL-F01 Native macOS-App**: Soll: ALFA ist eine SwiftUI-App für macOS 26 mit Sandbox. Ist: `alfaos/project.yml:6-9` (Ziel macOS 26.0), `:64-78` (Sandbox an), `alfaos/App/ALFA_OSApp.swift:5-43` (WindowGroup). Status: orange. Quelle: AGENTS §1; J 12.10. a9bb817c.
- **ZIEL-F02 Modular wie ein Betriebssystem**: Soll: jeder Bereich ist eine App im Bereichsverzeichnis; das Blob-Menü führt zwischen ihnen. Ist: Verzeichnis `alfaos/App/Resources/apps.json` mit 2 Einträgen (mail, settings); Bereichsinhalt ist je Bereich fest verdrahtet (`alfaos/App/Shell/LaneView.swift:104-113`, `ShellView.swift:50-56`), also noch nicht allein über das Verzeichnis erweiterbar. Status: orange. Quelle: AGENTS §1; Master `alfa-shell.js:5-8` (AREA nur Mail, Einstellungen).
- **ZIEL-F03 Plattformneutraler Kern**: Soll: Logik liegt im Paket Kit ohne Oberflächenbindung, die Oberfläche bleibt dünn. Ist: `alfaos/Kit/Package.swift:8` (macOS 26 und iOS 26), Pakete ShellCore, Hub, Mail (`Kit/Package.swift:10-12`); grep nach `import AppKit|SwiftUI|UIKit` in `Kit/Sources` ohne Treffer; aber Hub und Mail hängen über `Kit/Package.swift:15, :23, :33-34` von `fundus/alpha` (AlfaServices, AlfaKit) ab, und dort importieren `fundus/alpha/Sources/AlfaServices/Database/WorkBasketStore.swift:3` und `WidgetBoardStore.swift:3` SwiftUI, `Google/GoogleAuthService.swift:5, :7` AppKit bzw. UIKit (hinter `#if canImport`). Der Kern ist also nur im eigenen Code, nicht über seine Abhängigkeit frei von Oberflächenbindung. Status: orange. Quelle: AGENTS §6; J 12.10. a9bb817c; J 08.10. 055e95fd (nach Gedächtnis `spec-arbeit.md`, nicht im Transkript gegengelesen).
- **ZIEL-F04 Hülle**: Soll: die gemeinsame Schablone für jeden Bereich. Ist: siehe spec-huelle. Status: orange. Quelle: Master `ALFA Huelle.dc.html`; J 13.10. (Master `entscheidungen.md:144`).
- **ZIEL-F05 Mail**: Soll: Stufe 1, Rang 1. Ist: siehe spec-mail. Status: orange. Quelle: J 20.10. 3f52450e.
- **ZIEL-F06 Hub und Einstellungen (mit Konten)**: Soll: Stufe 1, Rang 1; Mail-Konten und Kontakte sind Integrationen. Ist: siehe spec-hub; `alfaos/App/Settings/`, `alfaos/Kit/Sources/Hub/`. Status: orange. Quelle: J 20.10. 3f52450e; J 15.10. (Master `INHALT.json` Hinweis „Mail Konten … EINE Integration“).
- **ZIEL-F07 Projekte (Akte, Fragebogen, Provisionierung)**: Soll: Stufe 1. Ist: fehlt (`alfaos/App` hat nur Components, Host, Mail, Resources, Settings, Shell, Theme; `apps.json` ohne Eintrag). Siehe `spec-projekte.md`. Status: offen. Quelle: AGENTS §1; J 18.10. c2a04c8a.
- **ZIEL-F08 Heute**: Soll: Stufe 1; Dashboard- und Widget-Startansicht, Mittelbahn als Widgetbrett. Ist: fehlt (`apps.json`). Siehe spec-heute. Status: offen. Quelle: J 20.10. 3f52450e; AGENTS §1.
- **ZIEL-F09 Kataloge**: Soll: Stufe 1. Ist: fehlt (grep `datan` und `kalkul` in `App`, `Kit/Sources`: kein Treffer). Siehe `spec-kataloge.md`. Status: offen. Quelle: AGENTS §1.
- **ZIEL-F10 Warenkorb**: Soll: Stufe 1. Ist: fehlt. Siehe `spec-warenkorb.md`. Status: offen. Quelle: AGENTS §1.
- **ZIEL-F11 Übrige Bereiche, Datan als Modul, 15 Integrationen**: Soll: Stufe 2 bis Launch Ende 2026. Ist: Dienstkatalog hat 10 Einträge (`alfaos/Kit/Sources/Hub/ServiceCatalog.swift:82-120`, 10 × `ServiceInfo(id:`), kein Datan-Code. Siehe `spec-spaeter.md`, `spec-hub.md`. Status: offen. Quelle: AGENTS §1; J 16.10. 97326b1d (Datan als Modul, Klickantwort, Wortlaut in `spec-kataloge.md`).

## Regeln
- **ZIEL-R01 Zwei Stufen**: Ende November 2026 sind Mail, Konten, Projekte (Akte, Fragebogen, Provisionierung), Heute, Kataloge und Warenkorb fertig, ohne Kalkulation; Launch Ende 2026 mit dem Rest. Auf die Frage „Zwei Ziele stehen gegeneinander“ antwortete Johannes mit der Klickantwort „Beides, gestuft“. Quelle: J 18.10. c2a04c8a; J 16.10. 97326b1d („Abgabe Ende November“, Klick).
- **ZIEL-R02 Kalkulation ist nicht in Stufe 1**: Quelle: J 18.10. c2a04c8a „c - aber noch ohne Kalkulation“ (Freitext auf Claudes Liste A/B/C; „c“ = Auslegung, nicht sein Wortlaut). In `alfaos` gibt es keinen Kalkulationscode (grep).
- **ZIEL-R03 Reihenfolge**: Hub/Einstellungen und Mail zuerst und weiter heben, alle Funktionen beleben; der Code liefert das Lastenheft der Funktionen. Die Reihenfolge der übrigen Stufe-1-Bereiche hat Johannes nicht genannt. Quelle: J 20.10. 3f52450e.
- **ZIEL-R04 Termine gleiten, Umfang und Qualität nicht**: Quelle: J 16.10. 97326b1d (Klick auf Claudes Empfehlung „Termin gleitet, Umfang und Qualität bleiben“; Wortlaut ist Claudes).
- **ZIEL-R05 Mac zuerst, mobil später und abgespeckt**: iOS, iPadOS und Web folgen später; die Struktur der App muss sie vorsehen; die Mac-App wird nicht 1:1 auf das iPhone gepresst. Quelle: J 12.10. a9bb817c.
- **ZIEL-R06 Distribution ermöglichen, nicht erzwingen**: Die App soll in Distribution gehen (App Store, iOS, iPadOS, evtl. Web, Abo); heute wird nichts davon gebaut, nur nichts verbaut. Quelle: J 12.10. a9bb817c „Sondern in Distribution gehen“; J 08.10. 055e95fd (Gedächtnis `spec-arbeit.md`).
- **ZIEL-R07 Funktion übernehmen, Form neu**: ALFA entsteht aus dem Bestand (ALPHA, Alphabet, Datan); der Bestand liefert Funktion, nicht Oberfläche. Quelle: J 11.10. 7cc894d9 („es muss nur richtig ALFA werden“); AGENTS §6 Bestand.
- **ZIEL-R08 Nur gezeichnete Bereiche werden gebaut**: Der Master 1810 zeichnet nur Mail und Einstellungen (mit Hülle); für Projekte, Heute, Kataloge, Warenkorb gibt es keine Zeichnung, bis Design liefert. Quelle: Master `alfa-shell.js:5-8`, `INHALT.json` `gruppen`; AGENTS §7.
- **ZIEL-R09 Überholte Zielworte**: „Widgets sind JETZT kein thema.“ (J 11.10.) ist durch J 20.10. 3f52450e (Heute als Widgetbrett) überholt; „Projekte etc definiere ICH später“ (19.10., bc4854d7) steht nur als eingereihte Nachricht, nicht als Nutzerzeile, und ist durch seine Definition von Heute, Projekten, Kontakten am 20.10. überholt. Quelle: Transkriptsuche 21.10.

## Lücken
- **ZIEL-L01 Zeichnungen für Projekte, Heute, Kataloge, Warenkorb**: fehlen; liefert Design. Beleg: `alfa-shell.js:5-8` (AREA hat Mail und Einstellungen), `INHALT.json` `gruppen` (Kommunikation: Mail; Kern: Einstellungen), `ALFA Mail.dc.html:386` (GROUPS nur zwei Bereiche).
- **ZIEL-L02 Welche 15 Integrationen**: der Master zeichnet 10 Dienste, DHL als zwei Karten (`ALFA Dienste.dc.html:102-103`); die Liste der 15 steht in keiner Lieferung. Wer liefert: Johannes. Beleg: Suche in `ALFA Dienste.dc.html`, `INHALT.json`, AGENTS §1; Ist 10 in `ServiceCatalog.swift`.
- **ZIEL-L03 Verbindliche Form von „Datan als Modul“**: Merge-Form und Umfang für Stufe 2 nicht gezeichnet, nicht entschieden. Wer liefert: Design nach Johannes. Beleg: grep `datan` in `alfaos` ohne Treffer; Gedächtnis `spec-kataloge.md` nennt nur das Wort vom 16.10.

## Offen bei Johannes
- Fällt Kalkulation unter „alle übrigen Bereiche“ bis Launch Ende 2026 oder darüber hinaus?
- In welcher Reihenfolge folgen Heute, Projekte, Kataloge, Warenkorb nach Mail und Hub?
- Vertriebsweg und Sandbox: Mac App Store, Developer ID oder beides (heute: Sandbox an, `alfaos/project.yml:77`, `alfaos/Config/ExportOptions-DeveloperID.plist` vorhanden)?
