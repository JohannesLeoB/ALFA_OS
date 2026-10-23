---
name: spec-spaeter
description: Später (Werkstatt, Assistent, Studio, Kalkulation): Funktionsbaum, nicht im ersten Ziel
metadata:
  type: project
---

# Später · Spec

Bereiche nach Stufe 1, bis Launch Ende 2026: Werkstatt mit den Editoren, Assistent als Bereich, Studio, Kalender, Kalkulation.

F01 = SPAET-F01. AUSSEHEN: Master zeichnet keinen dieser Bereiche, nur Namen (INHALT.json:828). Bestand = `fundus/alpha/Sources/`; Hub = `alfaos/Kit/Sources/Hub/`.

## Regeln
- R01 Jedes Werkstatt-Werkzeug ist ein eigener Bereich.
- R02 Die Editoren bauen auf den neutralen Ein- und Ausgabe-Modulen auf.
- R03 Assistent in drei Formen: schneller Helfer per Doppelklick auf den Blob; eigener Bereich mit Menüeintrag; Draws als Editor.
- R04 Bis zum eigenen Bereich erscheint der Assistent nur im Blob.
- R05 Notizen und Aufgaben des Assistenten gehören dem Studio.
- R06 Kalkulation ist nicht in Stufe 1.
- R07 Nach Projekten und Aufgaben kommt der Kalender.

## Werkstatt
**F01 Aufmaß**  
WAS: Maße und Details in Fotos der Situation; Laser per Bluetooth.  
WO: eigener Bereich.  
WARUM: Aufmaß im Projekt.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/AufmassModell.swift, AlfaServices/Aufmass/LeicaDistoBluetoothAdapter.swift, AlfaKit/Domain/GefuehrterAblauf.swift:123-147.

**F02 Atelier**  
WAS: perspektivisch skizzieren, auf Fotos und PDF; Renderprompt ausgeben.  
WO: eigener Bereich.  
WARUM: Entwurf schnell zeigen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/Skizze/SkizzenModell.swift, Skizze/PromptKompilierer.swift, Skizze/RenderCheckout.swift.

**F03 Moodboard**  
WAS: Bilder und Medien zu Tafeln für den Pitch, aus Vorlage zu PDF.  
WO: eigener Bereich.  
WARUM: Pitch.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand im Fundus nicht gefunden.

**F04 Konfigurator**  
WAS: Küche schnell aufziehen, zeigen, kalkulieren.  
WO: eigener Bereich.  
WARUM: erstes Angebot ohne CAD.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/Konfigurator/KonfigModell.swift, Konfigurator/KonfigRegeln.swift.

**F05 Plan, Planvergleich**  
WAS: Plan bearbeiten; Zeichnungen und Elektro-, Sanitärpläne auf Änderungen vergleichen.  
WO: eigener Bereich.  
WARUM: Änderungen nicht übersehen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: Plan AlfaKit/Domain/PlanDokument.swift:70; Planvergleich im Fundus nicht gefunden.

## Assistent
**F06 Assistent als Bereich**  
WAS: voller Bereich: Dokumente ausgeben, Dateien suchen, Termine, Notizen, erklären, kalkulieren.  
WO: eigener Bereich; Blob.  
WARUM: Hilfe bei jeder Arbeit.  
AUSSEHEN: nicht gezeichnet; Blob-Fenster Shell:86-93, Eingabe Brief N37.  
STAND: teilweise; Karte im Blob ohne Antwort (`alfaos/App/Shell/BlobMenuView.swift:240-264`), AssistantPort leer (Ports.swift:15); Bestand: AlfaServices/ConversationEngine.swift:252-290 (Freigaben je Datenart).

## Studio
**F07 Studio**  
WAS: Notizen, Aufgaben, Kontakte, Auslastung, Termine, Zeiten des Teams.  
WO: eigener Bereich.  
WARUM: Team im Blick.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaKit/Domain/StudioContact.swift, AlfaServices/Brain/StudioBrain.swift.

## Kalender
**F08 Kalender**  
WAS: Termine aus den Kalendern am Hub.  
WO: eigener Bereich.  
WARUM: Termine zum Vorgang.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Google/GoogleCalendarClient.swift; CalendarPort leer (Ports.swift:4).

## Kalkulation
**F09 Kalkulation**  
WAS: Schätzen aus Preisankern, Lernen aus Angeboten, Werkstattfaktoren.  
WO: offen.  
WARUM: Preise ohne Rechnen von Hand.  
AUSSEHEN: nicht gezeichnet; Werkstattfaktoren INHALT.json:626-629 (Text).  
STAND: fehlt; Bestand: AlfaCalculation/Estimation.swift, AlfaServices/Kalkulation/KalkulationsEngine.swift, Kalkulation/LearningStore.swift, AlfaCalculation/WorkshopFactors.swift.
