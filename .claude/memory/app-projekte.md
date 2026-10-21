---
name: app-projekte
description: "Funktionskarte Projekte (Akte, Fragebogen, Provisionierung): Ist, Soll, Offen, Stand 21.10."
metadata:
  type: project
---

Funktionskarte (Stand 21.10.; Ist = Code, Soll = sein Wort, Offen = belegte Frage)
Projekte (Akte, Fragebogen, Provisionierung)
- Ist: nur ALPHA-Altbestand (`fundus/alpha`, Labor): Galerie, Pipeline, Tabelle, Akte; der Fragebogen legt Drive-Ordnerbaum, Airtable-Eintrag und ClickUp-Liste an; Provisionierung steht auf „test“ (ALPHA-Inventur Lauf 2, 25.09.). In ALFA_OS kein Code (`alfaos/App` hat nur Mail, Settings, Shell).
- Soll: Akte „…an Dateien, Sammlungen, Dokumenten, Infos etc in drive liegt…“ und „…Daten wie Aufgaben, Zeiten, Moneys etc“ (04.10. 16:31 ee8f053d); „Die App Legt ihn immer zusammen mit airtable und clickup Liste an, wenn in der App ein "neues Projekt" angelegt wird...“ (04.10. 16:45 ee8f053d); Cash, Service, Akte „Teil von Projekte (Empfohlen)“ (04.10. 17:47 ee8f053d); „Projektübersichten als Dashboard im 3 Spalten blob menu button layout.“ (07.10. 23:40 055e95fd); „die projektakten von ihren 14 taps befreien“ (30.08. 00:05 6a6a9365); „Projekte und Aufgaben, dann Kalender (Empfehlung)“ (16.10. 20:52 97326b1d).
- Soll (Johannes 20.10. 22:17 Berlin, Produkt-Sitzung 3f52450e): „projekt anlegen/Lead udn Kontakte sind auch über den Hub gelegt - Firmen/user können diverse routen vorgeben- Kontakte Lokal, oder Tabellen, oder Apple Contacts, Google Workspace, Airtable - je nachdem was bei "projekt anlegen" oder kontakt anlegen oder oder oder im Hub je Firma / User so initial oder auch noch als spätere Einstellungen...“
- Projekt anlegen, echt schreiben (Johannes 20.10. 23:00 Berlin, Produkt-Sitzung 3f52450e, Klickfrage Q9): „Ja, echt, mit Vorschau und Bestätigung (Empfohlen)“. Gemeint: Vor dem Schreiben zeigt die App, was angelegt wird (Projektnummer, Ordner, Datensatz, Liste); geschrieben wird erst nach Bestätigung, jeder Schritt höchstens einmal, an die Ziele, die Firma oder Nutzer im Hub gewählt haben. Ist: `fundus/alpha/Sources/AlfaServices/ProjektProvisioningService.swift:57` schreibt nur im Probemodus (`guard mode == .test`, sonst `writeGateGesperrt`); Schritte Drive-Ordnerbaum, Airtable-Satz, ClickUp-Struktur mit Ledger. Vorschau und Bestätigung sind nicht gezeichnet (Lücke an Design).
- Offen: keine Zeichnung im bekannten Bestand; Prüfung am Design-Master.
