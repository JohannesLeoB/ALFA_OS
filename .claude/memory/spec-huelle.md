---
name: spec-huelle
description: Hülle (Blob, Bahnen, Stapel, Fenster, Sync, Look, Assistent im Blob): Funktionen als Baum mit Stand
metadata:
  type: project
---

# Hülle · Spec

Eingetragen: 23.10.2026 · Verfasser: Claude (Sonnet 5.5, Lead-Bau) für Johannes Leo Berger · Stand gegen Code-Commit e9893b1 · Quelle im Code: alfaos/App/Shell, alfaos/Kit/Sources/ShellCore

Die eine Schablone für jeden Bereich: Fenster, drei Bahnen mit Griffen, Blob mit Menü und Assistent, Sync-Knopf mit Avatar, Kartenstapel. Stufe 1, fertig Ende November 2026.

F01 = HUELLE-F01. AUSSEHEN: Shell = `ALFA Shell.dc.html`, js = `alfa-shell.js`, Huelle = `ALFA Huelle.dc.html`, Mail = `ALFA Mail.dc.html`, css = `alfa-theme.css`. Dateien ohne Pfad: `alfaos/App/Shell/`; `Comp/` = `alfaos/App/Components/`; `Core/` = `alfaos/Kit/Sources/ShellCore/`; `App/` = `alfaos/App/`. Brief v14.

## Regeln
- R01 Kein Dock, keine Kopfleiste; Bereiche wechselt man nur über den Blob.
- R02 Eine Hülle für alle Bereiche; Mail und Einstellungen gleich.
- R03 Das Blob-Menü ist die Hauptnavigation; es zeigt nur Bereiche.
- R04 Blob, Menü und Assistent liegen über allem.
- R05 Kein Langdruck am Blob, keine ⌘K-Suche.
- R06 Bahngrenzen gelten je Bereich; alles kann, nichts muss.
- R07 Maße wie der Master.
- R08 Karten wie der Kopf: oben 20, unten 0.
- R09 Ein ALFA-Look, keine Farbwelten.
- R10 Keine erklärenden Sätze, keine Tooltips an Blob und Griff.

## Fenster
**F01 Mindestgröße**  
WAS: Mindestbreite aus den Tokens (2 Ränder, 2 Rinnen, 3 Bahnen); Höhe im Seitenverhältnis des Bildschirms; Titel verborgen.  
WO: Fenster.  
WARUM: drei Bahnen passen immer.  
AUSSEHEN: Mindestgröße im Master offen (Huelle:77).  
STAND: gebaut, nicht abgenommen; der Master nennt keinen Wert (Core/ShellMetrics.swift:87-90, App/ALFA_OSApp.swift:36-48, :65-79).

**F02 Rand, Fuge, Leiste**  
WAS: Rand 16, Fuge 12, Blob-Leiste 40 plus 12; Bahnen bis 16 über der Unterkante.  
WO: Fenster.  
WARUM: feste Ordnung in jedem Bereich.  
AUSSEHEN: js:4, :14-16; Huelle:31-32.  
STAND: gebaut, nicht abgenommen (Core/ShellMetrics.swift:64-70, :97-99; ShellView.swift:69-83); oben bleibt der Systembereich (ShellView.swift:47).

## Bahnen
**F03 Drei Bahnen**  
WAS: Ruhe 280, Mitte Rest, 280; Mindestbreite je Bahn aus dem Token (Master nennt 280, Huelle:84 in der Code-Spalte 240); bei Platzmangel falten links, Mitte, rechts.  
WO: Fenster.  
WARUM: Liste, Inhalt, Stapel nebeneinander.  
AUSSEHEN: js:5-8, :19-44.  
STAND: gebaut, nicht abgenommen (Core/LaneLayout.swift:63-131).

**F04 Falten, Maximieren**  
WAS: unter 112 wird die Bahn 56 breit mit runden Zeichen; Klick öffnet; im Kopf Falten und Mitte groß.  
WO: Bahn, Kopf.  
WARUM: Platz für das Wichtige.  
AUSSEHEN: Shell:24-35; js:21.  
STAND: gebaut, nicht abgenommen (LaneView.swift:34-60, :90-102; App/Mail/MailListLane.swift:110-121; Core/ShellModel.swift:228-247).

**F05 Griff**  
WAS: Strich 1×64, aktiv 2×96; Ziehen rastet bei 12 ein, Hysterese 64; Doppelklick, Enter zurück; Pfeile ±56, mit Shift ±8; Wert in pt beim Ziehen; Fokusring nur per Tastatur.  
WO: Fuge.  
WARUM: Breiten frei einstellen.  
AUSSEHEN: Shell:39-42, :196-204.  
STAND: gebaut, nicht abgenommen (HandleView.swift:16-91, Core/LaneLayout.swift:133-190).

**F06 Kopf der Bahn**  
WAS: 44 hoch; Innenrand rechts 8, links 16 oder 8 im Stapel; Abstand 8 oder 4; Knopf 28 rund; Linie erst beim Scrollen.  
WO: Bahn, oben.  
WARUM: gleiche Köpfe überall.  
AUSSEHEN: js:4; Huelle:80, :92-94.  
STAND: gebaut, nicht abgenommen (Comp/LaneHead.swift:13-24, Core/LaneLayout.swift:16-20).

**F07 Ebbe**  
WAS: leerer Stapel faltet rechts nach 420 ms, langsam in 720 ms; neue Karte öffnet.  
WO: rechte Bahn.  
WARUM: kein leerer Platz.  
AUSSEHEN: js:67-74; Shell:223; Mail:506.  
STAND: gebaut, nicht abgenommen (Core/ShellModel.swift:249-270, ShellView.swift:46-61).

**F08 Zustand merken**  
WAS: Breiten, Falten, Maximieren je Bereich und Blob-Ort, auch nach Neustart.  
WO: Hintergrund.  
WARUM: Arbeitsplatz bleibt.  
AUSSEHEN: Mail:540.  
STAND: gebaut, nicht abgenommen (Core/ShellModel.swift:14-19, :101-105; App/ALFA_OSApp.swift:51-63).

**F09 Grenzen je Bereich**  
WAS: Mail: Links nicht über 280; Mitte und Rechts frei.  
WO: Bahnen.  
WARUM: jede Ansicht passend.  
AUSSEHEN: nicht gezeichnet (Brief N36).  
STAND: Lücke; eine Regel für alle (Core/LaneLayout.swift:32-34).

## Blob
**F10 Ruhe und wach**  
WAS: Ruhe 56×40 mit Augen; nah am Zeiger wach: 124 breit, sonst 280, mit Bereichsname; Augen folgen, blinzeln.  
WO: oben links.  
WARUM: Navigation immer greifbar.  
AUSSEHEN: Shell:52-59, :158-163, :228-229; Huelle:96-97.  
STAND: gebaut, nicht abgenommen (BlobView.swift:83-119, :186-214; Core/BlobPlacement.swift:97-100).

**F11 Ziehen, Andocken**  
WAS: Ziehen ab 3 pt mit Dehnung; fliegt mit Schwung; nahe Heim oder über den Bahnen kehrt er heim, sonst dockt er links oder rechts an, 36 breit.  
WO: ganzes Fenster.  
WARUM: Blob aus dem Weg.  
AUSSEHEN: Shell:143-175, :206-211.  
STAND: gebaut, nicht abgenommen (BlobView.swift:130-174; Core/BlobPlacement.swift:55-78; Core/ShellModel.swift:190-202).

**F12 Menü**  
WAS: Klick öffnet, 280 breit, in der unteren Hälfte nach oben; Finden; Gruppen; aktueller Bereich fett; Zahl rechts; Pfeile, Enter, Esc, Klick daneben; Nichts gefunden.  
WO: Blob.  
WARUM: Bereich wechseln.  
AUSSEHEN: Shell:60-85, :176-182, :212-217, :231-234.  
STAND: gebaut, nicht abgenommen (BlobMenuView.swift:4-217; Core/ShellModel.swift:119-188; ShellView.swift:32, :42); nur Mail, Einstellungen (App/Resources/apps.json).

**F13 Hinweispunkt**  
WAS: pulsierender Punkt bei Ungelesenem oder Abgleichfehler.  
WO: Blob, oben rechts.  
WARUM: Neues fällt auf.  
AUSSEHEN: Shell:67, :124; Mail:1074.  
STAND: gebaut, nicht abgenommen (BlobView.swift:86, :110-112, :392-424; App/Host/AppHost.swift:36, :48-53).

## Assistent im Blob
**F14 Mini-Fenster**  
WAS: Doppelklick öffnet; Augen zwinkern; Orb mit Titel; Text bei Dienstausfall oder leerem Mailstapel; Feld.  
WO: Blob.  
WARUM: schneller Helfer.  
AUSSEHEN: Shell:86-93, :178, :229-230.  
STAND: gebaut, nicht abgenommen (BlobView.swift:176-180, :426-473; BlobMenuView.swift:240-278).

**F15 Eingabe**  
WAS: Frage senden, Antwort, Verlauf, Anhänge.  
WO: Mini-Fenster.  
WARUM: mit dem Assistenten arbeiten.  
AUSSEHEN: nicht gezeichnet (Brief N37).  
STAND: Lücke; Feld ohne Eingabe (BlobMenuView.swift:261-266).

**F16 Assistent aus**  
WAS: Blob bei ausgeschaltetem Assistenten.  
WO: Blob.  
WARUM: Einstellung sichtbar wirksam.  
AUSSEHEN: Mail:760; Zustand nicht gezeichnet (Brief N38).  
STAND: Lücke; nur der Schalter liest ihn (App/Settings/SettingsSectionCards.swift:312-321).

## Sync und Avatar
**F17 Sync-Knopf**  
WAS: Klick gleicht ab; Ring dreht 720°; gesperrt während des Abgleichs; Fehler: Ring 25 % rot, roter Punkt.  
WO: oben rechts.  
WARUM: Daten aktuell.  
AUSSEHEN: Shell:46-50, :183-187, :236; Mail:1077; Umfang und Zeit nicht gezeichnet (Brief N38).  
STAND: teilweise; nur Mail (App/Host/AppHost.swift:55-61; Comp/SyncButton.swift:11-59).

**F18 Avatar-Kürzel**  
WAS: eigenes Kürzel, sonst Initialen aus Vor- und Nachname ohne Zusätze.  
WO: Sync-Knopf.  
WARUM: eigene Person erkennbar.  
AUSSEHEN: Shell:47; Mail:577.  
STAND: gebaut, nicht abgenommen (Core/Initials.swift:3-36, Comp/SyncButton.swift:8-13).

## Stapel
**F19 Kartenstapel**  
WAS: gestaffelte Karten, Köpfe sichtbar; Grautreppe; Hover hebt, Klick holt nach vorn; höchstens 6; leere Karte.  
WO: rechte Bahn.  
WARUM: mehrere Vorgänge zugleich.  
AUSSEHEN: Mail:919-951; Huelle:102, :104.  
STAND: teilweise; Turm und Wahl dazu fehlen (Mail:921), Lack nie gesetzt (App/Theme/DesignStyle.swift:28-30); Comp/CardPile.swift:4-153, Core/CardStack.swift:1-15, Core/DesignTokens.swift:213.

**F20 Übersicht**  
WAS: Kacheln in drei Größen statt Stapel.  
WO: rechte Bahn.  
WARUM: schnell springen.  
AUSSEHEN: Mail:952.  
STAND: gebaut, nicht abgenommen (Comp/CardPile.swift:210-363, Core/CardStack.swift:17-45).

## Look
**F21 Startansicht**  
WAS: Mail, Einstellungen oder zuletzt offen; Vorgabe Mail.  
WO: Einstellungen › Darstellung.  
WARUM: App öffnet, wo man arbeitet.  
AUSSEHEN: Mail:762.  
STAND: gebaut, nicht abgenommen (Core/SettingsSections.swift:77-92; App/Settings/SettingsSectionCards.swift:151-153; App/ALFA_OSApp.swift:17-23).

**F22 Farben, Erscheinung**  
WAS: Grund weiß, Bahn weiß mit Haarlinie, Blob invertiert; dunkel; Hell, Dunkel, System.  
WO: ganze App.  
WARUM: ein Look.  
AUSSEHEN: css:3-5.  
STAND: gebaut, nicht abgenommen (Core/DesignTokens.swift:318-319; App/ALFA_OSApp.swift:10, :35).

**F23 Schrift**  
WAS: Geist, lokal.  
WO: ganze App.  
WARUM: ein Look.  
AUSSEHEN: Shell:221; Wahl offen (Brief N13).  
STAND: teilweise; Geist mit Ersatz System (App/Theme/Theme.swift:45-63).

**F24 Bewegung reduzieren**  
WAS: keine Animation, keine Dehnung.  
WO: ganze Hülle.  
WARUM: Systemeinstellung gilt.  
AUSSEHEN: Shell:103.  
STAND: gebaut, nicht abgenommen (App/Theme/Theme.swift:32-34, ShellView.swift:10, :16).

**F25 Werte**  
WAS: Maße, Dauern, Farben aus Tokens; Sonderwerte mit Fundstelle.  
WO: Code.  
WARUM: Master ist das Soll.  
AUSSEHEN: Fundstellen nicht gezeichnet (Brief N43).  
STAND: teilweise; geladene Werte unbenutzt (Core/ShellMetrics.swift:93-95), Sonderwerte ohne Fundstelle (Core/SheetValues.swift).

**F26 Ebenen**  
WAS: feste Reihenfolge von Bahn bis Menü; Toast über dem Blob.  
WO: Fenster.  
WARUM: nichts verdeckt Falsches.  
AUSSEHEN: nur im Markup (Brief N35).  
STAND: Lücke; Toast unter dem Blob (Comp/CardPile.swift:37-42).

**F27 Fokusring**  
WAS: Ring bei Tastatur.  
WO: Griff, Knöpfe.  
WARUM: Bedienung ohne Maus sichtbar.  
AUSSEHEN: Abstand 2 (css:6) oder 1 (`ALFA Bestaetigen.dc.html`:20); Brief N39.  
STAND: Lücke; Code nimmt 2 (HandleView.swift:44-51, Core/DesignTokens.swift:99).

## Icon
**F28 App-Icon**  
WAS: vorläufig A-Monogramm in 16–1024.  
WO: Dock.  
WARUM: App erkennbar.  
AUSSEHEN: `material/icons/app/B_A-Monogramm-komplett.svg`; endgültig Brief N8.  
STAND: teilweise; vorläufig (App/Resources/Assets.xcassets/AppIcon.appiconset/, alfaos/project.yml:78).

## Später
- Assistent als eigener Bereich mit Menüeintrag: fehlt.
- Weitere Bereiche in der Hülle: fehlt (App/Resources/apps.json).
