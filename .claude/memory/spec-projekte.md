---
name: spec-projekte
description: Projekte (Akte, Fragebogen, Provisionierung): Funktionsbaum, Bestand im Fundus, kein Code in alfaos
metadata:
  type: project
---

# Projekte · Spec

Projekt als Akte: alles im Dateiort zum Projekt plus Aufgaben, Zeiten, Geld. Anlegen mit Fragebogen und Provisionierung. Stufe 1, fertig Ende November 2026.

F01 = PROJ-F01. AUSSEHEN: Master zeichnet Projekte nicht (Brief v14 Teil 6). Bestand = `fundus/alpha/Sources/`; Hub = `alfaos/Kit/Sources/Hub/`.

## Regeln
- R01 Neues Projekt legt Ordnerbaum, Datensatz und Aufgabenliste zusammen an.
- R02 Ziele des Anlegens (Dateiort, Datensatz, Aufgaben, Kontakte) wählen Firma oder Nutzer im Hub; Drive ist ein Ort unter mehreren (Mac, Dropbox, Server, iCloud).
- R03 Aufgabenliste nur, wenn eine Aufgaben-Integration aktiv ist.
- R04 Echt schreiben, kein Probemodus; Vorschau und Bestätigung sind Einstellung mit dieser Vorgabe.
- R05 Lead anlegen läuft über dieselben Hub-Routen wie Projekt.
- R06 Projektnummern werden nicht an Mails geschrieben.
- R07 Immer mindestens ein lokaler Speicherordner, beim ersten Einrichten genannt.
- R08 Cash, Service und Akte sind Teil von Projekte, keine eigenen Bereiche.
- R09 Die Akte hat nicht die vielen Reiter des Bestands.

## Anlegen
**F01 Projekt anlegen**  
WAS: zeigt, was angelegt wird, schreibt nach Bestätigung.  
WO: Projekte.  
WARUM: Projekt mit einem Griff.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/ProjektProvisioningService.swift:57 (nur Probemodus), AlfaServices/ProvisioningMode.swift:43.

**F02 Ordner, Datensatz, Liste**  
WAS: drei Schritte mit Wiederaufnahme.  
WO: Hintergrund.  
WARUM: nichts halb angelegt.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: ProjektProvisioningService.swift:65-85, AlfaServices/ProvisioningLedger.swift, AlfaKit/Domain/Provisioning.swift; Hub: nur FilesPort mit Methoden, TasksPort leer (Ports.swift:6-12).

**F03 Lead anlegen**  
WAS: Lead als Vorstufe, später zum Projekt beleben.  
WO: Projekte; aus Mail.  
WARUM: Anfrage früh festhalten.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/GefuehrterAblauf.swift:62-64, AlfaServices/Google/ProjektLeadBeleber.swift, AlfaKit/Domain/ClickUpListenPflicht.swift.

**F04 Fragebogen**  
WAS: Fragen zum Projekt; Antworten in Dateiort und Datensatz.  
WO: Anlegen.  
WARUM: Eckdaten des Kunden.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: Ordner „07 Fragebogen“ (AlfaKit/Domain/FolderSchema.swift:41), Ablauf GefuehrterAblauf.swift:55-59; Fragebogen-Ansicht im Fundus nicht gefunden.

**F05 Projektnummer**  
WAS: Nummer je Jahr, fortlaufend.  
WO: Anlegen.  
WARUM: eindeutige Ablage.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/Projektnummer.swift:24-36, AlfaServices/LocalSequentialAuthority.swift.

**F06 Ordnerbaum**  
WAS: Baum für jedes Projekt; Erst-Setup fragt Orte für Daten, Datenbanken, Bilder, Vorlagen.  
WO: Einstellungen › Dateiordner.  
WARUM: gleiche Ablage überall.  
AUSSEHEN: Mail:766 (Projektordner); Wahl der Orte nicht gezeichnet (Brief N30).  
STAND: fehlt; Bestand: FolderSchema.swift:30, :58 (fest, R13 in spec-ziel).

## Akte
**F07 Projektgalerie**  
WAS: alle Projekte als Karten, Pipeline, Tabelle.  
WO: Projekte.  
WARUM: Überblick.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand im Fundus nicht gefunden.

**F08 Akte**  
WAS: Dateien, Dokumente, Infos des Projekts; Aufgaben, Zeiten, Geld; Cash, Service.  
WO: Projekte.  
WARUM: alles zum Projekt an einer Stelle.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand im Fundus nicht gefunden.

**F09 Projektübersicht**  
WAS: Übersicht als Dashboard in drei Bahnen.  
WO: Projekte.  
WARUM: Stand auf einen Blick.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand im Fundus nicht gefunden.

**F10 Phasen, Aufgabenfelder**  
WAS: Phasen des Projekts, Abgleich mit der Aufgaben-Integration.  
WO: Akte; Hub › ClickUp.  
WARUM: Fortschritt sehen.  
AUSSEHEN: Mail:394 (nur Abgleichzeilen).  
STAND: fehlt; Bestand: AlfaKit/Domain/ProjectLifecycle.swift:3-10, AlfaKit/Domain/ClickUpProjectTemplate.swift:4-13.

## Mail und Projekt
**F11 Ablage aus Mail**  
WAS: Mail und Anhang in den Projektordner, Datei aus ihm anhängen, Lead aus Mail.  
WO: Mail.  
WARUM: Anfrage gehört zum Projekt.  
AUSSEHEN: Mail:699, :998, :1033; nicht gezeichnet (Brief N15, N16, N17).  
STAND: teilweise (spec-mail F28, F48, F51).
