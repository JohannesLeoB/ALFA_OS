---
name: spec-heute
description: Heute (Widget-Brett): Funktionsbaum, Bestand im Fundus, kein Code in alfaos
metadata:
  type: project
---

# Heute · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: fundus/alpha/Sources (Bestand, nicht in alfaos)

Startansicht der App: ein Widgetbrett, das der Nutzer frei zusammenstellt. Stufe 1, fertig Ende November 2026.

F01 = HEUTE-F01. AUSSEHEN: Master zeichnet Heute nicht (Brief v14 Teil 6); Texte ohne Zeichnung in `INHALT.json`. Bestand = `fundus/alpha/Sources/`; Hub = `alfaos/Kit/Sources/Hub/`.

## Regeln
- R01 Layout der Hülle; die Mittelbahn nimmt die volle Breite als Raster.
- R02 Widgets sind Karten mit Info, Aktion, Reaktion, Navigation.
- R03 Ein Widget an einem Dienst bezieht ihn über den Hub, ohne eigenen Zugang.
- R04 Widgets haben Ein- und Ausgänge zu anderen Bereichen.
- R05 DHL Versand und Sendungsverfolgung sind eine Integration; kein Sandbox-Zugang.

## Brett
**F01 Startansicht**  
WAS: Heute als Bereich; Startwahl beim Öffnen.  
WO: Blob; Einstellungen › Beim Öffnen.  
WARUM: Tag auf einen Blick.  
AUSSEHEN: nicht gezeichnet; Heute fehlt in Beim Öffnen (Mail:762).  
STAND: fehlt (`alfaos/App/Resources/apps.json`).

**F02 Raster**  
WAS: Widgets anordnen, ziehen, Größe ändern.  
WO: Mittelbahn.  
WARUM: eigenes Brett.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: Größen AlfaKit/Domain/WidgetFoundation.swift:43-48, Vorgabe :118-125, Speicher AlfaServices/Database/WidgetBoardStore.swift:120, :150.

**F03 Entfernen, Auswahl**  
WAS: Widget vom Brett nehmen, ein- und ausblenden, auf Vorgabe zurück.  
WO: Brett, Bearbeiten.  
WARUM: Brett pflegen.  
AUSSEHEN: INHALT.json:1143 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: WidgetBoardStore.swift:126, :138, :144.

**F04 Widget-Galerie**  
WAS: Widgets suchen und aufs Brett legen.  
WO: Brett, Bearbeiten.  
WARUM: neue Widgets finden.  
AUSSEHEN: INHALT.json:1108 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: WidgetBoardStore.swift:132.

**F05 Widgetarten**  
WAS: Arten des Bestands, je Heute oder Projekte zugeteilt.  
WO: Brett.  
WARUM: Umfang festlegen.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: 34 Arten (WidgetFoundation.swift:3-41).

## Widgets mit Diensten
**F06 DHL**  
WAS: Sendungen verfolgen, Etiketten erstellen und drucken.  
WO: Brett; Hub › DHL.  
WARUM: Versand ohne zweite App.  
AUSSEHEN: Dienste:102-103 (zwei Karten); eine Karte Brief N1.  
STAND: fehlt; Bestand: AlfaServices/Sendungen/DHLSendungsClient.swift, DHLVersandClient.swift; Hub: ShippingPort leer (Ports.swift:16).

**F07 Zeit, Aufgaben**  
WAS: Clockodo buchen und zeigen; ClickUp-Aufgaben zeigen.  
WO: Brett.  
WARUM: Zeit und Aufgaben im Blick.  
AUSSEHEN: INHALT.json:1043, :1058, :1088 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Clockodo/ClockodoClient.swift:42-50, AlfaServices/ClickUp/ClickUpClient.swift; Hub: TimePort, TasksPort leer (Ports.swift:12-13).

**F08 Kalender**  
WAS: nächste Termine, Woche.  
WO: Brett.  
WARUM: Tag planen.  
AUSSEHEN: INHALT.json:1078 (Text); nicht gezeichnet.  
STAND: fehlt; Bestand: AlfaServices/Google/GoogleCalendarClient.swift; Hub: CalendarPort leer (Ports.swift:4).

**F09 Weitere Dienste**  
WAS: Slack, Teams, Google Workspace, Geräte, API-Dienste als Widgets.  
WO: Brett.  
WARUM: Dienste bedienen, ohne zu wechseln.  
AUSSEHEN: nicht gezeichnet.  
STAND: fehlt; Bestand: kein Slack- oder Teams-Client im Fundus.
