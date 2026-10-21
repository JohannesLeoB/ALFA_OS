---
name: spec-heute
description: Heute, die Dashboard- und Widget-Home-Ansicht mit frei konfigurierbarem Widgetboard: Wort von Johannes (20.10.) vorhanden, in ALFA nichts gebaut, im Master nicht gezeichnet.
metadata:
  type: project
---

# Heute · Spec (Stand 21.10.)

Pfadkürzel: `fundus:` = `fundus/alpha/Sources/`; `labor:` = `~/Developer/mykilos-labor/Sources/` (Unterordner App, Kit, Services, Widgets tragen dort das Präfix des Altnamens). Bestand ist nur Herkunft der Fähigkeit, nie Vorlage für Aufbau oder Namen (J 20.10. 3f52450e).

## Ziel
Heute ist die Home-Ansicht der App: ein Dashboard mit einem Widgetboard, das der Nutzer frei zusammenstellt. Widgets tragen Funktionen, hängen an Integrationen im Hub oder haben Ein- und Ausgänge zu anderen Modulen. Der Bereich gehört zum Ziel Ende November (`AGENTS.md:9`). In ALFA gebaut ist nichts (`alfaos/App/Resources/apps.json` führt nur mail und settings); der Master zeichnet Heute nicht, nur Textlisten (`INHALT.json:828,1038-1213`).

## Richtung
- „App-Store“ als Motiv: ALFA ist das Betriebssystem der Studios, Produkte, Teams, Projekte, Zeiten, Kommunikation und Verkauf; Widgets sind die Bausteine.
- Widgets aus weiteren Integrationen: Slack, Teams, Google Workspace, Geräte, API-Dienste und Syncs bedienen und zeigen.
- Widget-Galerie zum Hinzufügen (kommt, Gestaltung steht aus).
- Aktionen von Widgets quer durch die App (Ein- und Ausgänge zu anderen Modulen).
- Die 34 Widgetarten werden einzeln mit Johannes durchgegangen und Heute oder Projekten zugeteilt.

## Funktionen
- **HEUTE-F01 Home-Ansicht**: Soll: Heute ist die Dashboard-und-Widget-Home-Ansicht. Grundsätzlich dasselbe Layout wie die Hülle; linke und rechte Spalte sind ggf. entfernt oder verändert; die mittlere Bahn nimmt die volle Breite, gerastert und im Stil der Master-Hülle. Ist: fehlt in ALFA; Bestand `labor:App/Today/HomeBoardView.swift:7`, `labor:App/Today/TodayView.swift`. Status: offen. Quelle: J 20.10. 3f52450e · Master: keine Zeichnung (HEUTE-L01) · Bestand wie genannt.
- **HEUTE-F02 Widgetboard als Raster**: Soll: Die Mittelbahn ist ein Widgetboard, das vielfältig definierte Widgets in einem Raster aufnimmt, das der Nutzer konfiguriert, anordnet und zusammenstellt. Ist: fehlt; Bestand hat 2 bis 5 Spalten je Breite (`labor:App/Today/HomeBoardView.swift:23-30`), Umordnen durch Ziehen (`:178-189`), Größe am Griff (`:48-58`) mit den Größen 1x1 bis 3x2 (`fundus:AlfaKit/Domain/WidgetFoundation.swift:43-48`), lückenloses Packen (`labor:App/Today/BrettPacker.swift:10`), Speicher (`labor:Services/Database/WidgetBoardStore.swift:9`) und eine Standardanordnung (`WidgetFoundation.swift:118-125`). Raster, Größen und Seiten für ALFA: nicht gezeichnet. Status: offen. Quelle: J 20.10. 3f52450e · Master `entscheidungen.md:49-50` (J 11.10.: Bahnen können Widgets tragen, „wie ein Board“) · Bestand wie genannt.
- **HEUTE-F03 Widget entfernen und Auswahl**: Soll: Der Nutzer entfernt ein Widget vom Brett und wählt Widgets aus; beides kehrt zurück. Ist: fehlt; Bestand blendet Widgets ein und aus und setzt auf die Standardanordnung zurück (`labor:App/Detail/WidgetSelectorView.swift:9-60`, `labor:Services/Database/WidgetBoardStore.swift:147`). Master-Wortlaute ohne Zeichnung: „Widgets bearbeiten“, „Vom Brett nehmen“, „Größe ziehen“ (`INHALT.json:1143-1153`). Status: offen. Quelle: J 04.10. ee8f053d Klick „Ja, beides“ · Master wie genannt.
- **HEUTE-F04 Widget-Galerie**: Soll: Eine Galerie zum Suchen und Hinzufügen kommt, ihre Gestaltung steht aus. Ist: fehlt; Master-Wortlaute ohne Zeichnung: Widgets, Widget suchen, Seite, Fertig, Aufs Brett, Auf dem Brett, Noch nicht gezeichnet (`INHALT.json:1108-1138`). Bestand kennt nur die Auswahl aus F03. Status: offen. Quelle: J 06.10. ff9962d1 „Widget Galerie kommt, aber wird noch designed“.
- **HEUTE-F05 DHL-Widget**: Soll: DHL ist eine Integration mit einem Widget auf Heute (Sendungen verfolgen, Labels erstellen und drucken); Versand und Verfolgung sind ein Integrations-Eintrag, nicht zwei. Ist: fehlt; Bestand hat Widget `labor:Widgets/Kinds/SendungenWidget.swift`, Etikett-Dialog `labor:App/Today/DHLLabelErstellenView.swift`, Verfolgung `fundus:AlfaServices/Sendungen/DHLSendungsClient.swift`, Versand `fundus:AlfaServices/Sendungen/DHLVersandClient.swift`; der Sandbox-Zugang steht dort noch fest im Code (`DHLVersandClient.swift:54-55`). Master zeichnet zwei Dienstkarten (`ALFA Dienste.dc.html:102-103`). Status: offen. Quelle: J 20.10. bc4854d7 „SANDBOX Raus“, „DHL Versand und Sendungsverfolgung sind EIN Integrations Item“ · J 20.10. 3f52450e „DHL ist ein Widget“.
- **HEUTE-F06 Zeitbuchung und Aufgaben**: Soll: Clockodo-Zeitbuchung und „ClickUp Aufgaben“ sind Widgets, die die Integration bedienen und zeigen. Ist: fehlt; Bestand `labor:App/Today/ClockodoWidget.swift`, `labor:App/Today/ClickUpAlleAufgabenWidget.swift`, Client `fundus:AlfaServices/Clockodo/ClockodoClient.swift`, `fundus:AlfaServices/ClickUp/ClickUpClient.swift`; Hub-Ports `TimePort` und `TasksPort` haben keine Methoden (`alfaos/Kit/Sources/Hub/Ports.swift:12-13`). Master-Wortlaute ohne Zeichnung: Läuft, Pausiert, Wechseln (`INHALT.json:1088-1098`), „ClickUp Aufgaben“, „Clockodo Zeiterfassung“ (`:1043,1058`). Status: offen. Quelle: J 20.10. 3f52450e.
- **HEUTE-F07 Weitere Integrations-Widgets**: Soll: Slack, Teams, Google Workspace, Geräte und API-Dienste werden als Widgets bedient und gezeigt; welche zuerst: lücke. Ist: fehlt; Bestand hat für Slack und Teams keine Client-Datei (Dateinamensuche unter `fundus/alpha/Sources`, 21.10.), für Google Kalender und Kontakte `fundus:AlfaServices/Google/GoogleCalendarClient.swift`, `GoogleContactsClient.swift`. Status: lücke (Reihenfolge), offen (Wunsch). Quelle: J 20.10. 3f52450e.
- **HEUTE-F08 Kalender, Wochen- und Terminwidgets**: Soll: lücke (Inhalt und Aussehen). Ist: fehlt; Bestand `labor:App/Today/HeuteAnstehendView.swift`, `labor:Widgets/Kinds/TeamkalenderWidget.swift`. Master-Wortlaute ohne Zeichnung: „Keine Termine mehr heute.“, „Als Nächstes“, „KW“ (`INHALT.json:1078-1103`). Status: lücke. Quelle: Master wie genannt · J 04.10. ASSUMPTIONS.tsv:367 (Mini-Ansicht: nur „Kalender (nächster Termin)“ genannt, später).
- **HEUTE-F09 Widgetarten**: Soll: Jede der 34 Widgetarten wird einzeln mit Johannes entschieden: Heute, Projekte oder gestrichen. Ist: Bestand kennt 34 Arten (`fundus:AlfaKit/Domain/WidgetFoundation.swift:3-41`); Heute zeichnet 20 davon (`labor:App/Today/HomeBoardView.swift:191-224`), der Eintrag „werkzeuge“ passt zu keiner Art (die Art heißt `tools`, `WidgetFoundation.swift:40`). Zuteilung: keine. Status: lücke. Quelle: `~/ALPHA/ASSUMPTIONS.tsv:368` (J 04.10. ee8f053d „Ich gehe sie mit dir einzeln durch“).

## Regeln
- **HEUTE-R01**: Heute gehört zum Ziel Ende November; „Widgets sind JETZT kein thema“ (J 11.10., `entscheidungen.md:48`) ist durch sein jüngeres Wort vom 20.10. überholt. Quelle: J 20.10. 3f52450e · AGENTS.md:9.
- **HEUTE-R02**: Widgets sind Karten und UI-Blöcke mit Info, Aktion, Reaktion und Navigation; die Bahnen können dafür waagerecht geteilt werden. Quelle: J 11.10. Master `entscheidungen.md:49-50`.
- **HEUTE-R03**: Ein Widget, das an einem Dienst hängt, bezieht ihn über den Hub; es hat keinen eigenen Zugang. Quelle: J 20.10. 3f52450e „Widgets … mit Integrationen am Hub“.
- **HEUTE-R04**: Zeichnung und Gestaltung der Widgets macht Design; Code legt das Wurzelwerk im Hub (IDs, Integrationen, Ein- und Ausgänge). Quelle: J 20.10. bc4854d7 „Macht design. DU musst nur das Wurzelwerk dafür legen“.
- **HEUTE-R05**: Eine Widget-Art ohne Zeichnung wird nicht gebaut (Lücke). Quelle: AGENTS.md:55.
- **HEUTE-R06**: Bestand wird in Funktion übernommen, nicht in Form oder Namen; kein Altcode-Kommentar, Token oder Name zieht um. Quelle: J 20.10. 3f52450e „ES soll NICHTS wieder genau das gleiche gebaut werden“.

## Lücken
- **HEUTE-L01**: Keine Zeichnung für Heute: Rastermaße, Bahnaufteilung, Widget-Hüllen, Galerie, Bearbeiten-Zustand, leere und gestörte Zustände. Liefert: Design. Beleg: Master enthält 10 `*.dc.html` ohne Heute; Heute nur als Textliste `INHALT.json:828,1038-1213` (`vertrag_abdeckung.fehlen_im_entwurf`); Bestand-Bogen `~/ALPHA/Design/BOGEN-HEUTE.json:3-4` ist Version 1.6.2 „proposal“ mit Kopf und Dock (`:119`, `:138`) und gilt nicht.
- **HEUTE-L02**: „Heute“ fehlt in der Auswahl „Beim Öffnen“ der Startansicht (Mail, Einstellungen, Zuletzt offen). Liefert: Design. Beleg: `ALFA Mail.dc.html:762`.
- **HEUTE-L03**: Zuteilung der 34 Widgetarten und Reihenfolge der ersten Widgets. Liefert: Johannes. Beleg: `ASSUMPTIONS.tsv:368`; kein Wort dazu in `spec-heute.md`.
- **HEUTE-L04**: Welche Teile der linken und rechten Spalte auf Heute bleiben. Liefert: Johannes mit Design. Beleg: J 20.10. „ggf. aus dem Ansichtsbereich entfernt /modifiziert“, keine Entscheidung.
- **HEUTE-L05**: Hub-Ports für Aufgaben, Zeit und Versand sind leer. Liefert: Code (nach Zeichnung). Beleg: `alfaos/Kit/Sources/Hub/Ports.swift:12,13,16`.

## Offen bei Johannes
- Welche Widgets zuerst, und welche der 34 Arten entfallen?
- Was bleibt von linker und rechter Spalte auf Heute?
- Ist die Widget-Auswahl (Bestand) schon die Galerie, oder wird beides gebraucht?
