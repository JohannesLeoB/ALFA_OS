---
name: spec-hub
description: Hub und Einstellungen: Funktionen als Baum (was, wo, warum, Aussehen, Stand), Regeln, Lücken bei Design
metadata:
  type: project
---

# Hub · Spec

Einstellungen, Konten und Dienste in einem Knoten; verbindet Konten, Dienste und Speicherorte mit den Bereichen. Stufe 1, fertig Ende November 2026.

F01 = HUB-F01. AUSSEHEN: Zeile in `ALFA Mail.dc.html`; Dienste: = `ALFA Dienste.dc.html`. Dateien ohne Pfad: `alfaos/Kit/Sources/Hub/`; `S/` = `alfaos/App/Settings/`; `App/` = `alfaos/App/`; SS = `alfaos/Kit/Sources/ShellCore/SettingsSections.swift`; FU = `fundus/alpha/Sources/`. Berührt Mail: F12 = MAIL-F14, F41 = MAIL-F54, F42 = MAIL-F30. Brief v14.

## Regeln
- R01 Angemeldet heißt alles dürfen; sperren kann nur die Firma; keine Rollen im Code.
- R02 Nichts fest verdrahtet: Basen, Tabellen, Felder, Phasen, Kostenstellen, Modell kommen aus Einstellungen oder Einrichtung.
- R03 Keine Sandbox-Zugänge.
- R04 Schlüssel nur im Schlüsselbund; die Oberfläche zeigt nur Zustand.
- R05 Eine Verbindung je Konto; gleiches Konto erneuert statt doppelt.
- R06 Trennen entfernt alles der Verbindung, ganz oder gar nicht.
- R07 Rückfrage vor dem Schreiben ist Einstellung, keine Pflicht; nie mehrfach fragen.
- R08 Der Speicher für Vorgänge ist austauschbar.
- R09 Der Hub hält Systeme mit Rolle, Ströme mit Richtung, Protokoll je Lauf.
- R10 Jedes gelieferte Stück trägt System, Kennung, Zeit, Richtung, Bezüge.
- R11 Keine Zeile ohne Wirkung; keine erklärenden Sätze.

## Baum
**F01 Gruppen und Abschnitte**  
WAS: Ich, Firma, Verbindungen, Schutz und System; rechts Kartenstapel.  
WO: Einstellungen.  
WARUM: jede Einstellung an fester Stelle.  
AUSSEHEN: Mail:389, :403-410.  
STAND: teilweise; Kontakte zusätzlich, Integrationen leer (SS:24-46, S/SettingsSectionCards.swift:24).

**F02 Erweiterbar**  
WAS: neue Gruppen und Abschnitte ohne Umbau.  
WO: Einstellungen.  
WARUM: weitere Bereiche, Dienste.  
AUSSEHEN: nicht gezeichnet (Brief N26).  
STAND: fehlt; feste Aufzählung (SS:4-46).

**F03 Nach Zugehörigkeit**  
WAS: Besitzer, nutzender Bereich, tragender Dienst; Schalter je Knoten.  
WO: Einstellungen.  
WARUM: Verbindung steht, wo sie wirkt.  
AUSSEHEN: nicht gezeichnet (Brief N26).  
STAND: Lücke.

**F04 Tastenkürzel, Mitteilungen**  
WAS: zeigt, was es gibt; nichts ohne Wirkung.  
WO: Einstellungen.  
WARUM: Überblick.  
AUSSEHEN: Mail:406, :764-765; Mitteilungen Brief N29.  
STAND: fehlt (SS:24-35).

**F05 Speicherorte mit Vorlagen**  
WAS: Dateiordner, Arbeitsordner, Vorlagen in einem Abschnitt.  
WO: Einstellungen › Firma.  
WARUM: alle Ablagen an einer Stelle.  
AUSSEHEN: Mail:766, :772; Brief N26.  
STAND: teilweise; zwei Abschnitte, leer, Knöpfe aus (S/SettingsSectionCards.swift:203-230).

## Ich
**F06 Identität**  
WAS: Name, Rolle, Kürzel, Telefon, Geburtstage.  
WO: Ich › Identität.  
WARUM: Name und Kürzel im Team.  
AUSSEHEN: Mail:758.  
STAND: teilweise; nur Name, Kürzel wirken (App/Mail/MailComposeView.swift:138, App/Components/SyncButton.swift:8-9).

**F07 Darstellung**  
WAS: Hell, Dunkel, Automatisch; fremde Inhalte hell.  
WO: Ich › Darstellung.  
WARUM: lesbar bei jedem Licht.  
AUSSEHEN: Mail:761.  
STAND: teilweise; Fremde Inhalte nur Anzeige (App/ALFA_OSApp.swift:35, S/SettingsSectionCards.swift:149-151).

**F08 Startansicht**  
WAS: Mail, Einstellungen, Zuletzt offen.  
WO: Ich › Darstellung.  
WARUM: App öffnet, wo man arbeitet.  
AUSSEHEN: Mail:762.  
STAND: gebaut, nicht abgenommen (SS:77-93, App/ALFA_OSApp.swift:22).

**F09 App-Sperre**  
WAS: Touch ID oder Passwort nach Pause.  
WO: Ich › Darstellung.  
WARUM: Schutz am offenen Mac.  
AUSSEHEN: Mail:763; Sperre Brief N9.  
STAND: teilweise; gespeichert, nichts sperrt (S/SettingsSectionCards.swift:155-160).

**F15 Abmelden**  
WAS: alle verbundenen Dienste, aufgezählt und gezählt; einzeln auf der Dienstkarte.  
WO: Ich › Identität.  
WARUM: Mac sauber freigeben.  
AUSSEHEN: Mail:758; Brief N2, N41.  
STAND: teilweise; trennt alle mit Halten, ohne Aufzählung, startet neu (S/SettingsSectionCards.swift:104-126); Google-Zugang nicht widerrufen (GoogleSignIn.swift:61).

## Firma
**F10 Firmendaten**  
WAS: Firma, Anschrift, Telefon, Web, Mail; Nutzer trägt ein.  
WO: Firma.  
WARUM: Angaben für Dokumente.  
AUSSEHEN: Mail:771.  
STAND: teilweise; gespeichert, nirgends genutzt (S/SettingsSectionCards.swift:165-173).

**F11 Impressum**  
WAS: Urheber, Rechte, Signatur.  
WO: Schutz und System.  
WARUM: Rechte festhalten.  
AUSSEHEN: Mail:773.  
STAND: teilweise; wie F10 (S/SettingsSectionCards.swift:175-183).

## Schutz und System
**F12 Bilder in Mails**  
WAS: Schalter je Mail-Konto, Hauptschalter je Nutzer; Vorgabe aus.  
WO: Dienstkarte; Datenschutz.  
WARUM: Schutz vor Zählpixeln.  
AUSSEHEN: Mail:760; Brief N21.  
STAND: teilweise; ein Schalter (S/SettingsSectionCards.swift:317-319, App/Mail/MailReadingView.swift:141).

**F13 Datenschutz, übrige**  
WAS: Assistent ganz aus, Dateien im Chat, Daten exportieren.  
WO: Datenschutz.  
WARUM: Kontrolle über Daten.  
AUSSEHEN: Mail:760.  
STAND: teilweise; ohne Wirkung, Export aus (S/SettingsSectionCards.swift:320-328).

**F14 System**  
WAS: Version, Zweig, Datenbank, Diagnose kopieren.  
WO: System.  
WARUM: Fehler melden.  
AUSSEHEN: Mail:767.  
STAND: gebaut, nicht abgenommen (S/SettingsSectionCards.swift:333-377).

## Dienste
**F16 Kachel und Karte**  
WAS: Kachel mit Logo, Name, Zustand; Karte mit Zustand, Anmeldung, Feldern, Abgleich, Extras.  
WO: Verbindungen.  
WARUM: jeder Dienst gleich bedient.  
AUSSEHEN: Mail:391-401, :727-747; Logos Brief L-011.  
STAND: gebaut, nicht abgenommen (S/SettingsLaneView.swift:188-242, S/SettingsServiceCard.swift:71-106); Logos nur Clockodo, DHL (ServiceCatalog.swift:96, :112).

**F17 Zustandswörter**  
WAS: acht Wörter von Verbunden bis Verwaist.  
WO: Kachel, Karte.  
WARUM: Lage auf einen Blick.  
AUSSEHEN: Mail:704-716; Brief N32.  
STAND: teilweise; Schlüssel gespeichert, Verwaist nie (HubCore.swift:367-368).

**F18 Verbinden, Prüfen, Trennen**  
WAS: Anmeldung, Prüfung beim Anbieter, Erneuern, Trennen mit Halten.  
WO: Karte.  
WARUM: Zugang verlässlich.  
AUSSEHEN: Mail:733-737.  
STAND: gebaut, nicht abgenommen (HubCore.swift:346-534, S/SettingsStack.swift:192-211); ganz oder gar nicht nur für Schlüssel (:504-522).

**F19 Drei Zeichen, Bericht**  
WAS: online, eingeschränkt, Fehler; Bericht mit Anbieter, Status, Code, Servertext, Anfragekennung.  
WO: Karte.  
WARUM: Fehler genau benennen.  
AUSSEHEN: nicht gezeichnet (Brief N31).  
STAND: teilweise; berechnet, nie gezeigt (HubCore.swift:149-168); Karte zeigt Grund, Status (S/SettingsServiceCard.swift:155-180).

**F46 Fehlerpunkt**  
WAS: fehlerhafte Dienste außerhalb der Karte.  
WO: Hülle › Blob; Gruppe Verbindungen.  
WARUM: Fehler fällt auf.  
AUSSEHEN: Mail:711.  
STAND: gebaut, nicht abgenommen (App/Host/AppHost.swift:38-46, App/Shell/BlobMenuView.swift:198).

## Je Dienst
**F20 Google Mail**  
WAS: Anmeldung im Browser, persönlich.  
WO: Karte Google.  
WARUM: Gmail-Postfach.  
AUSSEHEN: Mail:392.  
STAND: teilweise; nur mit Datei google-client.json (ProviderCatalog.swift:6-8).

**F21 Google Kontakte, Dateien, Kalender**  
WAS: Bereiche mit Takt; Drive-Ordner der Projekte.  
WO: Karte Google.  
WARUM: eine Anmeldung für alles.  
AUSSEHEN: Mail:392; Drive Brief N30.  
STAND: teilweise; Angebot nur Mail (alfaos/Kit/Sources/Mail/Setup/MailSetup.swift:78), Kalender, Kontakte ohne Adapter (GoogleProvider.swift:36-44), Drive ohne Projektwurzel (ProviderCatalog.swift:7); 403 gilt als Anmeldefehler (GoogleFailure.swift:9-10).

**F22 Mail-Konten**  
WAS: IMAP, SMTP mit Anbietervorlagen; bis drei; prüfen, entfernen.  
WO: Karte Mail-Konten.  
WARUM: weitere Postfächer.  
AUSSEHEN: Mail:393, :737; Brief L-008, L-013.  
STAND: gebaut, nicht abgenommen (IMAPProvider.swift:24-57, S/SettingsServiceCard.swift:182-216, HubConfiguration.swift:8).

**F23 ClickUp Zugang**  
WAS: Schlüssel, Prüfung.  
WO: Karte ClickUp.  
WARUM: Aufgaben.  
AUSSEHEN: Mail:394.  
STAND: gebaut, nicht abgenommen (KeyProviders.swift:12-16).

**F24 ClickUp Abgleich**  
WAS: Phasen, Aufgabenfelder.  
WO: Karte ClickUp.  
WARUM: Aufgaben im Vorgang.  
AUSSEHEN: Mail:394.  
STAND: fehlt; keine Fähigkeit (KeyProvider.swift:87, ServiceReader.swift:79).

**F25 Clockodo Zugang**  
WAS: E-Mail, Schlüssel, Nutzer; nur persönlich.  
WO: Karte Clockodo.  
WARUM: Zeiten.  
AUSSEHEN: Mail:395; Nutzer-ID Brief N28.  
STAND: teilweise; nur persönlich ohne Wirkung (KeyProviders.swift:17-26, ServiceCatalog.swift:92).

**F26 Clockodo Zuordnungen**  
WAS: Leistung je Kostenstelle, Kunde, abrechenbar.  
WO: Karte Clockodo.  
WARUM: Zeiten richtig gebucht.  
AUSSEHEN: nicht gezeichnet (Brief N28).  
STAND: fehlt; Kostenstellen fest im Bestand (FU/AlfaKit/Domain/TimeTracking.swift:15-25).

**F27 Claude**  
WAS: Schlüssel, Modell, Prüfung; Hub einzige Quelle des Schlüssels.  
WO: Karte Claude.  
WARUM: Assistent.  
AUSSEHEN: Mail:396; Modell Brief N6.  
STAND: teilweise; Standardmodell fest (KeyProviders.swift:27-33, FU/AlfaServices/Claude/ClaudeAuthService.swift:61).

**F28 Airtable Zugang**  
WAS: Base, Schlüssel, Prüfung, Zwischenspeicher leeren.  
WO: Karte Airtable.  
WARUM: Projekte, Kunden.  
AUSSEHEN: Mail:397.  
STAND: gebaut, nicht abgenommen (KeyProviders.swift:34-41, S/SettingsServiceCard.swift:289-290); Format der Base fest (KeyProviders.swift:36).

**F29 Airtable Abgleich**  
WAS: Projekte mit Takt; Basen, Tabellen, Felder.  
WO: Karte Airtable.  
WARUM: Projektdaten im Vorgang.  
AUSSEHEN: Mail:397; Zuordnung Brief N28.  
STAND: fehlt; Bereich ohne Fähigkeit (ServiceCatalog.swift:103), Werte nur in Datei (alfaos/Config/company.example.json).

**F30 sevDesk**  
WAS: Schlüssel, Prüfung.  
WO: Karte sevDesk.  
WARUM: Belege, Angebote.  
AUSSEHEN: Mail:398.  
STAND: gebaut, nicht abgenommen (KeyProviders.swift:42-46).

**F31 DHL**  
WAS: eine Karte für Verfolgen und Versand.  
WO: Verbindungen.  
WARUM: Sendungen.  
AUSSEHEN: Mail:399-400; Brief N1.  
STAND: teilweise; zwei Einträge, Versand nicht verbindbar (ServiceCatalog.swift:109-116, :132-134).

**F32 Happa Happa**  
WAS: Karte mit Zugang.  
WO: Verbindungen.  
WARUM: Speiseplan.  
AUSSEHEN: Mail:401.  
STAND: fehlt; nicht verbindbar (ServiceCatalog.swift:117-119).

## Mechanik
**F33 Besitz**  
WAS: Verbindung gehört Person oder Firma.  
WO: Karte, Anmeldung.  
WARUM: Firmendienste für alle.  
AUSSEHEN: Mail:738.  
STAND: teilweise; Person fest (App/Host/AppHost.swift:67), Firmenschlüssel nur auf diesem Mac (KeychainAdapter.swift:14-16).

**F35 Fähigkeiten, Ports**  
WAS: Dienst nennt Fähigkeiten; Bereiche holen Daten über Ports.  
WO: Hintergrund.  
WARUM: Bereiche ohne Wissen über Dienste.  
AUSSEHEN: ohne Oberfläche.  
STAND: teilweise; Mail, Dateien gebaut, sieben Ports leer (Ports.swift:4-16).

**F36 Takt**  
WAS: Aus, Manuell, 30 s bis 1 h; Jetzt abgleichen mit Rückmeldung.  
WO: Karte, Abgleich.  
WARUM: Daten aktuell.  
AUSSEHEN: Mail:744; Brief L-012, N5.  
STAND: teilweise; Rückmeldung nur Drive (CadenceChoice.swift:3-26, S/SettingsServiceCard.swift:279-288).

**F37 Einstellungen je Dienst**  
WAS: Schalter, Auswahl, Text, Zahl, Zuordnung; Person, Firma, Gerät.  
WO: Karte.  
WARUM: Dienste je Firma einstellen.  
AUSSEHEN: Zuordnungen Brief N28.  
STAND: teilweise; Mechanik da, kein Dienst nutzt sie (ServiceSetting.swift, HubCore.swift:574-595).

**F38 Mitteilungen**  
WAS: je Dienst Art, Takt, stumm; global stumm für Stunden.  
WO: Einstellungen.  
WARUM: Ruhe nach Wahl.  
AUSSEHEN: Mail:764; Brief N29.  
STAND: fehlt.

**F39 Dateiorte**  
WAS: Mac, Google Drive, Dropbox, Server; Ordnerrollen nach Wahl.  
WO: Einstellungen, Hub.  
WARUM: Ablage je Firma.  
AUSSEHEN: Mail:766; Brief N30.  
STAND: fehlt; nur Drive-Port, aus (F21).

**F40 Katalog**  
WAS: Kategorien, Hinzufügen, Verwalten, versorgte Bereiche, Filter.  
WO: Verbindungen.  
WARUM: viele Dienste überschaubar.  
AUSSEHEN: Mail:391-401, Dienste:94-116; Brief N27.  
STAND: Lücke.

**F41 Kontakte am Hub**  
WAS: mehrere Quellen zugleich, auch eigene lokale Datenbank.  
WO: Verbindungen.  
WARUM: eine Adressquelle.  
AUSSEHEN: Mail:752-757; Brief N33.  
STAND: teilweise; lokale Liste in UserDefaults (SS:32, :43, alfaos/Kit/Sources/Mail/Model/MailContacts.swift:16-18).

**F42 Signatur je Postfach**  
WAS: je Mail-Konto anlegen.  
WO: Einstellungen.  
WARUM: einheitlicher Auftritt.  
AUSSEHEN: Mail:759; Brief L-010.  
STAND: Lücke.

**F43 Schlüssel-Inventar**  
WAS: Zustand je Dienst, Entfernen; Waisen erkennen.  
WO: Verbindungen.  
WARUM: Ordnung im Schlüsselbund.  
AUSSEHEN: Mail:408, :774.  
STAND: teilweise; Waisen nie erkannt (S/SettingsSectionCards.swift:232-251).

**F44 Einrichtung**  
WAS: geführt statt Dateien von Hand.  
WO: erster Start.  
WARUM: neue Firma ohne Technik.  
AUSSEHEN: Mail:440, :766; Ablauf nicht gezeichnet.  
STAND: fehlt; Dateien von Hand (GoogleClientConfig.swift:12-21, KeyProviders.swift:38).

**F45 Kosten**  
WAS: Aufrufe, Daten, Token je Dienst; KI als Schätzwert in 0,50-Schritten.  
WO: Karte.  
WARUM: Kosten sehen.  
AUSSEHEN: nicht gezeichnet (Brief N6).  
STAND: teilweise; gezählt, nie gezeigt (Adapters/CountingCost.swift, HubCore.swift:565).

## Später
- Firma sperrt einen Dienst: fehlt (Model.swift:198).
- Rollen als Einstellung: fehlt.
- 15 Integrationen in voller Tiefe, Datan als Modul.
- ClickUp über den Zugang hinaus: nicht beauftragt.
