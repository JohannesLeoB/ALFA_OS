# Handoff · Session „ALFA OS Editoren Sketches 1610" · Stand 18.10.2026, 21:18

Für eine frische Session. Alles hier stammt aus den Nachrichten des Nutzers (Johannes) in dieser Session oder aus Dateien, die ich ganz oder teilweise gelesen habe. Wo ich etwas nicht weiß, steht **[unbekannt]**.

**Lücke zuerst:** Mir wurden aus dem Verlauf mehrere Nachrichten entfernt (die ersten Rückfragen, Antworten von mir, einzelne Nutzer-Nachrichten dazwischen). Was der Nutzer dort sagte, ist hier nur dann enthalten, wenn eine spätere Nachricht darauf Bezug nimmt. Wer sicher gehen will: den Nutzer fragen, nicht raten.

Nicht in `/tmp` abgelegt, weil ich nur in das Projekt schreiben kann. Datei: `HANDOFF_Editoren_1810.md` im Projektstamm.

## 1 · Verbindliche Regeln des Nutzers

**Aus seinen Nachrichten (Nr. = Nachrichten-ID):**
- m0001: Die HTML-Bögen sind die Messlatte, „einzig und alleine was ich selber auf den fullscreen dargestellten Design Bögen gesehen habe, zählt". Er hat selbst nie ein Dokument, Protokoll, TSV oder JSON verfasst. Nicht auf MD-Dateien, UI-Metatexte oder beschreibende Aussagen achten. Keine Erinnerungen oder Kontextreste aus anderen Projekten. Das System ist ausdrücklich nicht sauber (teils brechend, doppelt, uneinheitlich).
- m0029: **„Nicht liefern!!! Das ist alles noch nicht ansatzweise fertig!"** Kein Export, kein ZIP, keine Karte.
- m0041: **„KEINE STAPELKARTEN, NUTZE ANDERE UI BLOCKS"**
- m0074 / m0080 / m0082 / m0091 / m0093: **Lesen vor Behaupten.** Sinngemäß: Wer nicht liest, lügt. Er droht wiederholt, das gesamte Projekt samt Dateien zu löschen, wenn ich Leseaufgaben verweigere, Fragen stelle, die sich aus Quellen beantworten ließen, oder lange Rechtfertigungen schreibe. Verlangt: lesen, arbeiten, **kurz berichten, mit Quellen und Belegen**, jede Antwort mit **real gelesenen Zeilen gegen nicht gelesene Zeilen**, und **alle Dateien der Projektakte jederzeit nachführen**.
- m0084: Ich hatte behauptet, Blattwerk und Zeichenfläche seien die „Referenz für die UI". Das hat er nie gesagt. Der Altcode gilt nur für Funktion und Verhalten („nicht alles gut, aber er erklärt dir ein paar Dinge", m0069).
- m0085: **Die Moodboard-Toolleiste ist „die bislang am besten designte". Alle anderen Editoren auf deren Layout umbauen („das Layout kanonisieren"), NICHT die jeweiligen Werkzeuge.** Danach im Altcode gründlich lesen, was Nutzer real mit den Ansichten **machen**.
- m0067: Radien müssen denselben Gesetzmäßigkeiten folgen. Umgesetzt (Palette 12 px, Menüs 12 px).
- m0063: Politur: Abstände, Radien, Schriften, Icons, Werkzeugsatz, Erreichbarkeit, Arbeitsabläufe, Ansichten.

**Aus der angehängten `CLAUDE.md` des Export-Projekts „ALFA OS Interface CHEF 1610"** (ganz gelesen, 11 Zeilen). Ob sie auch für dieses Projekt gilt, hat der Nutzer nicht gesagt **[unbekannt]**; sie ist aber gleichlautend mit seinen Aussagen oben:
- „Hülle nur einmal": Mail und Einstellungen teilen die übergreifende UI exakt (Hülle, Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände, Radien). Jeder Token, Wert, jede Bewegung, jeder Mouseover muss unaufgefordert in alle Bögen nachgezogen werden.
- Belegpflicht, Halluzinationsverbot, Erfindungssperre: nichts nennen oder umsetzen ohne Quellenbeleg, Zitat und Codezeile im Chat.
- Keine ZIPs und keine Downloads ohne ausdrückliche Freigabe („100 % sauber").

## 2 · Was der Nutzer in dieser Session beauftragt hat (Reihenfolge, soweit sichtbar)

1. m0001: ZIP-Vollexport der anderen Designsession lesen. Fokus: Mail, Einstellungen, Shell. Mail am weitesten.
2. m0015: Im 3-Spalten-Blob-Menü (Standard-Bogenlayout) mit vorhandenen oder neuen Components einen neuen Cluster Ansichtsbereiche für die ALFA-OS-App in Swift.
3. m0017: Die Familie „Editoren" (Creative Cloud in der App) mit Dateien, Vorlagendateien, Quellen/Ablagen und Workflows entwerfen.
4. m0021: Ein Dateimanager kommt auch, ist aber „erstmal Peripherie"; „ICH sage dir wie er was warum kann". Editoren: kreativer Bereich mit mehreren Editoren, Apps oder Toolsets (Moodboard, „InDesign", Skizzen, Konfiguration).
5. m0022: „Baue erstmal Moodboard."
6. m0031: Fehlgriff `ALFA Editoren.dc.html` löschen. Erledigt, dazu der `Editoren`-Eintrag in `alfa-shell.js`.
7. m0033: Editor Moodboard, Aufmaß, Skizzen/Atelier mit Render-Pipeline entwerfen.
8. m0038 / m0039: Er lieferte eine Vergleichstabelle (Bluebeam, Photo Measures, Milanote, Morpholio, 2020 Design Live, Concepts, Sketchbook u. a.). Danach „45 Minuten volle Freiheit inkl. Websuche, UI-Blöcke, Tools- und Funktionsrecherche".
9. m0043: Er lud shadcn-studio-Blöcke hoch (Dashboard-Shell, Kalender, Statistik, Account-Settings, Timeline, Empty-State u. a.) als UI-Block-Material, nach dem Verbot der Stapelkarten.
10. m0050 / m0052: „Wo habe ich Werkzeugpaletten?" Sechs Bildschirmfotos (17.10. 04:58–05:09) hochgeladen. Inhalt der Fotos habe ich in dieser Sitzung nicht festgehalten **[unbekannt]**.
11. m0056 / m0057: „Schon nicht schlecht." Werkzeugleiste noch nicht optimal. Er will recherchierte, coole, funktionale Lösungen. Frage von ihm: Ist die Leiste eine Drag-Drop-Bar, frei im Canvas platzierbar? Oder verschiedene Paletten? „Mach mal!" Ergebnis: schwebende, ziehbare Palette mit Griff, Doppelklick dockt an, Position in `localStorage`.
12. m0069–m0080: Altcode lesen, wie Aufmaß und die anderen Editoren funktionierten. „Suche genauer." „IMMER LESEN." Er warf mir vor, ich hätte es nicht finden wollen, weil ich zu faul gewesen sei, obwohl „es alles bereits fertig gebaut" sei.
13. m0076 / m0078: Er fügte eine Recherche zu 60 Werkzeugen in 8 Gruppen ein (Auswahl, Transform, Ebenen, Zeichnen, Farbe, Präzision, Bildanpassung, Text/Export) und verlangte: prüfen, was wir haben, was wir brauchen, wie einsetzen, wo platzieren, wie umsetzen.
14. m0088: Skill `/ideenwerkstatt-werkzeuge` durchgehen und prüfen, ob er hilft. Danach ein Briefing-MD für eine fremde Claude-Session schreiben, für Moodboard, Atelier/Skizze, Aufmaß, Konfigurator, Planvergleich (ELT). Ergebnis: `BRIEFING_Editoren.md`. Wie der Skill ausgefallen ist, steht nicht in den mir vorliegenden Nachrichten **[unbekannt]**.
15. m0090: Dringend: Planvergleich lesen (Entwürfe, Vision) und einen neuen Entwurf im ALFA-Shell-Design bauen. Ergebnis: `ALFA Planvergleich.dc.html`.
16. m0096: Dieser Handoff, dazu der Upload des Export-Ordners „ALFA OS Interface CHEF 1610-handoff 1810".

## 3 · Dateistand im Projekt (per `list_files` und `grep` heute geprüft)

- `ALFA Moodboard.dc.html` (752 Z.): Seiten-Editor. Referenz für das Palettenlayout.
- `ALFA Moodboard v1.dc.html`: ältere Fassung, nicht angefasst.
- `ALFA Atelier.dc.html` (478 Z.), `ALFA Aufmass.dc.html` (451 Z.), `ALFA Planvergleich.dc.html` (391 Z.): alle drei haben dieselbe Palettenmechanik wie das Moodboard (`tool-palette`, `palRef`, `palDown`, `palDock`, `palUp`, `localStorage`-Schlüssel `alfa.{mood|atelier|aufmass|planvergleich}.pal`).
- **Das 3×3-Gehäuse mit neun Stiften, das ich in m0083 in Atelier und Aufmaß eingebaut hatte, ist nicht mehr im Code** (kein Treffer für `stiftkasten` und `stiftGo(`). Es war ein Fehlgriff und widersprach m0085. Wann ich es entfernt habe, ist in den mir vorliegenden Nachrichten nicht sichtbar **[unbekannt]**.
- `ALFA Shell.dc.html`, `ALFA Bestaetigen.dc.html`, `alfa-theme.css`, `alfa-shell.js`, `image-slot.js`, `support.js`: aus der ersten Übernahme, von mir nicht gelesen bis auf Treffer. `alfa-shell.js` führt Spaltenbreiten für Mail, Einstellungen (min 224/280/280), Moodboard, Aufmaß, Planvergleich, Atelier (je L 280, R 280, min 224/392/280, yield 2/0/1).
- `BRIEFING_Editoren.md` (303 Z.): das Briefing für die fremde Session, **nicht hier duplizieren, dort lesen**. Es enthält Gelesen- und Nicht-gelesen-Listen (Abschnitt 10) und den Nachtrag aus den Tests (Abschnitt 11).
- Offen: Das Ergebnis des Verifiers für `ALFA Planvergleich` ist nicht bei mir angekommen **[unbekannt]**. Die Seite lud ohne Konsolenfehler, ein Bild habe ich nicht gesehen.

## 4 · Was gebaut ist und wo es nicht passt

- **Palette (alle vier Bögen):** 12-px-Radius, 8 px Innenabstand, 28-px-Knöpfe, Griff oben, Doppelklick dockt an, Menüs ebenfalls 12 px.
- **Stapelkarten:** Die Methoden `stackCards`/`stackCards0` stehen noch in Moodboard, Atelier und Aufmaß (Z. 271–275, 277–281, 244–248). Sie geben nur die vordere Karte zurück und setzen Reiter darüber. Ob der Nutzer das als „Stapelkarte" ansieht, ist nicht geklärt. Planvergleich nutzt sie nicht.
- **Aufmaß:** Unser Entwurf ist ein Raummodell aus Wänden. Im Altcode ist der Kern ein Foto-Aufmaß mit Kalibrierung, Ebenen, Marken und Perspektive (Details in `BRIEFING` Abschnitt 11.2). Nicht angeglichen.
- **Atelier:** Layerarten (Bestand/Neu/Entfernen/Notiz), drei Strichstufen und Foto mit Filter aus dem Altcode sind nicht abgebildet.
- **Moodboard:** Unser Entwurf ist eine Seitenmontage (A3 quer, 16:9, A4 hoch, Musterseite). Der Altcode kennt das Modeblatt (A4 quer, Collage oder Raster) und sechs Material-Slots.
- **Planvergleich:** Alles Attrappe mit Toast. Kein Dateivergleich, kein DXF/PDF-Import.
- **Konfigurator:** Kein ALFA-Bogen vorhanden. Der Altcode (`KonfigModell` ganz gelesen) ist im Briefing beschrieben.
- **Werkzeug-Vereinheitlichung:** Der Altcode hat ein „Werkzeug" mit fünf Modi (Aufmaß, Skizze, Moodboard, Konfigurator, Plan) und einem Kasten. Ob ALFA drei getrennte Bögen bleibt oder das übernimmt, hat der Nutzer nicht entschieden (Briefing 11.8, Frage 2).
- **Render-Pipeline** (m0033, Atelier): Der Altcode hat Kompilierer, Rezept, Auftrag, einen Master und die Engine `fireflyManuell`. Ob mein Atelier das zeigt, habe ich nicht geprüft **[unbekannt]**.
- **Dateimanager** (m0021): nicht begonnen. Der Nutzer sagte, er erkläre ihn selbst.
- **Moodboard „InDesign"-Linie:** nur als seine Nennung bekannt.

## 5 · Was ich nicht gelesen habe (Zeilen gelesen / Gesamt), Stand `BRIEFING` Abschnitt 10 und heute

- Altentwurf-Blätter `paket/design/`: Aufmass 381–780/780, Atelier 1–600 und 1051–1380/1419, Blattwerk 1–400/1183, Zeichenflaeche 1–400/499, Papers 1–400/576, Konfigurator 381–680/816. Null Zeilen: Perspektive, Perspektivraster, Kreativwerkzeuge, Werkzeuge, Planwerk, Vorlagen, Material, Katalog.
- Kit: AufmassModell 1–300/335, AufmassLayer 1–200/249, AufmassPerspektive 1–120/263, SkizzenModell 1–250/265, KonfigRegeln 1–160/278, KonfigArchetypen 1–120/214. Null Zeilen: MaterialSlot, PerspektivRaster, PlatziertesBild, PromptKompilierer, PromptVorlagen, RenderCheckout, SkizzenGeometrie, AufmassAutoBemassung, AufmassDokument, AufmassDateiname, PlanProjektion, PlanTransform, KonfigAnfrageText, KonfigKuerzel, KonfigMaterial, KonfigRenderPrompt. (Zu einem Teil dieser Dateien habe ich die **Tests** ganz gelesen, nicht den Code.)
- `MykilosDesign`: alles außer MykWerkzeugkasten (984/984) und MykKontextpalette (106/106). `MykilosWidgets` (Ansichten): null Zeilen. Das ist die Quelle dafür, wie der Altcode **real benutzt** wird.
- ELT: `elt-plan-editor.md` 1–200/327, `elt-editor/index.html` 1–300/925, `eltplan/index.html` 21–190/354. Null: `elt-modul.md`, `PLANWESEN_VORLAGEN.md`, `elektrosymbole.js`, ELT-Lastenhefte.
- Unsere Bögen `ALFA Moodboard`, `ALFA Atelier`, `ALFA Aufmass`: nur Gerüst (Methodennamen, Konstanten, Zeilen auf 230 Zeichen gekürzt), nicht ihre Spalten-Templates.
- **Export-Ordner „CHEF 1610-handoff 1810":** nur `CLAUDE.md` (11/11) und `README.md` (23/23) gelesen. Alle übrigen Dateien, darunter `ALFA Mail`, `ALFA Einstellungen`, `ALFA Shell`, `ALFA Huelle`, `ALFA Tokenbogen`, `ALFA Farbsystem`, `ALFA Entscheidungen`, `ALFA Dienste`, `ABNAHME.md`, `AUDIT.md`, `entscheidungen.md`, `RUECKGABE-AN-CODE.md`, `UEBERGABE-NAECHSTER-CHAT.md`, `TOKENBOGEN.json`, `lieferung-an-code/*.json`: **null Zeilen**. Die `README.md` verlangt, `ALFA Tokenbogen.dc.html` vollständig und danach alle Imports zu lesen. Das ist offen.
- Die ersten Aufgaben der Session (Lesen von Grammatik, Musterbuch, Entscheidungsblatt, Shell, Mail-Vollbild in Teilen, Mail Workflow v4/v5/Ist-Stand 435, Einstellungen plus Bedienelemente, Befund zusammenfassen) stehen noch als **offene Todos**. Ob sie vollständig erledigt wurden, ist mir nicht bekannt **[unbekannt]**.

## 6 · Was auf den Bildschirmfotos der letzten Nachricht zu sehen ist (nur Gesehenes, ohne Deutung)

- Google-Bildersuche und Logos als Dateien: `clockodo.png`, `monday.svg`, `dhl.svg` (SVGs ließen sich nicht dekodieren), Lexware-Treffer. Sie liegen im Export unter `material/icons/`. Wofür der Nutzer sie braucht, hat er nicht geschrieben. Die Einstellungs-Liste im Screenshot der anderen Session zeigt Airtable, Claude, Google, sevDesk, DHL Sendungen.
- Zwei Screenshots der `CLAUDE.md` (Inhalt wie oben).
- Eine Inline-Bestätigung „Google trennen? Nein / Trennen" als Pille mit rotem Rahmen, in der Zeile „Frage". Drei Ausschnitte davon.
- Ein Ausschnitt aus dem Entscheidungsblatt der anderen Session: „1 · Blob wach: Maus näher als 212 px am Blob (ALFA Shell.dc.html:157) … Entschieden 17.10.: 124 … in einem Schritt 280 … Keine Zwischenbreiten". Darunter „2 · Von Design gesetzt · vorläufig freigegeben 17.10." mit Halten 1000 ms („dein Wort: in 1sek"), Kante 20 % weich, Unschärfe bis 0,6 px, Zittern ab 70 % bis 1,5 px, Loslassen 180 ms, onSignal dunkel #0d0d0d (Weiß hatte 2,61:1), Signal hell #b3412e, dunkel #e08a74. **Der Nutzer hat im HELL-Feld mit Rot eine große Schleife um die rechte Spalte „Trennen / Verwerfen / Fehler" gezogen.** Was er damit meint, schrieb er nicht **[unbekannt]**.
- Chat der anderen Session, sichtbar als Textausschnitt: „Offen, steht so in der Akte: 1. Wach-Breite des Blobs: 124 hast du ‚FALSCH!' genannt. Dein Wert fehlt. 2. Einstellungen-Zielliste: Fünf Gruppen, Kacheln als Start … gebaut ist sie nicht. 3. Mehrfachauswahl: nicht entworfen. 4. Farbsystem: noch nicht entschieden. 5. Feinwerte Bestätigen: Radierkante 20 %, Unschärfe 0,6, Zittern ab 70 % / 1,5 px habe ich gesetzt. Entschieden hast du sie nicht." Nicht geprüft laut dieser Session: Dunkel in Einstellungen, echte Maus und echtes Halten, ob `github.md` noch zum Repo passt. Der Nutzer schrieb dort: „AUDIT durch Fremd-KI vorbereiten. Ich werde alle Projektdateien runterladen …"
- Ein Assistent-Popover mit „Claude antwortet gerade nicht. In den Einstellungen neu verbinden."

## 7 · Nicht umgesetzt oder nicht entschieden

- Ob das vereinte „Werkzeug" mit fünf Modi (Altcode) übernommen wird.
- Ob die Stapelkarten-Methoden entfernt werden müssen.
- Aufmaß auf Foto-Aufmaß umstellen, Atelier-Layerarten und Strichstufen, Konfigurator-Bogen, Planvergleich-Funktion (echter Vergleich), Dateimanager.
- Planvergleich: Konzeptfragen offen (Herkunft der Fassungen, Ausrichtung, Schwelle, Ausgabeformat), siehe `BRIEFING` Abschnitt 7.
- Die in m0063 verlangte Politur (Abstände, Radien, Schriften, Icons, Erreichbarkeit) ist für die Palette erfolgt, für den Rest **[unbekannt]**.
- Weitere Lesestellen in der Reihenfolge der Dringlichkeit: (1) `ALFA Tokenbogen.dc.html` und seine Imports im Export (verlangt vom dortigen README), (2) die eigenen drei Bögen vollständig, (3) `MykilosWidgets`-Ansichten für reale Nutzung, (4) Rest der ELT-Dokumente.

## 8 · Empfohlene Skills für die nächste Session

- `ideenwerkstatt-werkzeuge` (vom Nutzer genannt, Nutzen offen).
- `Hi-fi design` und `Interactive prototype` für weitere Bögen.
- `Frontend design` nur, wenn der Nutzer ausdrücklich eine neue Richtung will. Bisher gilt ALFA-Shell und `alfa-theme.css`.
- Die nächste Session soll mit **Lesen** beginnen und jede Antwort mit Gelesen/Nicht-gelesen in Zeilen belegen. Nichts liefern, kein ZIP.

## 8a · Stand 19.10.2026, Übernahme ALFA-Mastersystem (Export „CHEF 1610-handoff 1810")

Johannes: „Nicht die Bögen übernehmen, aber deine eigenen Entwürfe und Token updaten … GLOBAL in allen deinen Files."
- Ersetzt durch Export-Fassung (Export-Dateien mit und ohne Hash-Suffix sind byteweise gleich, geprüft): `ALFA Shell.dc.html` (Export 18.10.: lokale Schrift `lieferung-an-code/fonts/geist.css`, Sync-Punkt 8 px, Prop `assistentGesicht` = „Orb", Blob-Wachbreite: 124 oder, wenn der Name nicht passt, 280 `K.rest`), `alfa-shell.js` (Minima 280/280/280, Kommentar „Johannes 15.10.: Bitte vereinheitlichen auf 280"), `alfa-theme.css` (Fokusring 2 px/Abstand 2, Bahn-Container für Streifen/Inhalt, reduzierte Bewegung).
- Neu im Projekt: `TOKENBOGEN.json` (Master), `lieferung-an-code/fonts/*`, `lieferung-an-code/motion-springs.json`.
- Editor-Bögen (Moodboard, Atelier, Aufmaß, Planvergleich): `reg()` Minima 224/392/280 → 280/280/280 (Master); Kontextmenü-Radius 12 → 16 (`radius.contextMenu` 16; Master Mail `anchored-menu` border-radius:16px, ALFA Mail.dc.html:346). Palette bleibt 12 (kein Token, Moodboard-Palette ist Johannes' Maßstab).
- Nicht übernommen (Bögen): Mail, Einstellungen, Huelle, Farbsystem, Designsystem, Dienste, Entscheidungen, Tokenbogen.
- `ALFA Bestaetigen.dc.html` im Projekt (13665 Z.-Zeichen) weicht vom Export (10432) ab; nicht angefasst, weil Bogen. Entscheidung offen.
- `CLAUDE.md` des Exports nicht kopiert: Schreiben nach CLAUDE.md ist hier gesperrt.
- Altcode (`MykilosWidgets`, `mykilos-alles/…`) ist in diesem Projekt nicht vorhanden; Lesereihenfolge Punkt 6 nicht ausführbar, bis Johannes ihn einspielt.
- Gelesen in dieser Session: Moodboard 752/752, Atelier 478/478, Aufmass 451/451 und Planvergleich 391/391 (je mit Vergleich gegen schon gelesene Zeilen), BRIEFING 303/303, Export-Tokenbogen 57/57, Export-`alfa-shell.js` 77/77, `alfa-theme.css` 14/14, `geist.css` 3/3, TOKENBOGEN.json Z. 1–2000 roh, Rest als Pfad=Wert-Liste.
- Antworten Johannes 19.10.: (1) Getrennte Ansichten, jede standalone (wie Illustrator, InDesign, Photoshop), mit gemeinsamem „Hub“; alle Editoren beziehen und synchronisieren aus gemeinsamen Creative-/Materials-Dateien und -Datenbanken. (2) Planvergleich: Pläne aus Fremdapps, zu verschiedenen Zeiten erstellt, vom Nutzer gewählt; Überlagerung per OCR bzw. Datei-/Scanner-/Reader-Werkzeugen so gut wie möglich, nur bei gleicher Grundlage (z. B. Planstand Januar gegen März derselben Grundrissplanung). Ausgabe: Änderungsliste als PDF oder Excel, mit Bearbeitungen des Nutzers; Architektur ist Code-Sache. Ausrichtung im Detail und Schwelle: unbekannt, nicht entschieden.
- Umgesetzt dazu: Planvergleich Fuß „Pläne wählen“ (zwei Pläne), Ausgabe „Als Excel“ / „Als PDF“ (Attrappen). Hub-Entwurf noch nicht gebaut.

## 8b · Kommentare Johannes 19.10. (Planvergleich), Anforderungen, noch nicht gebaut
- Linke Spalte: Toolkarten oder kleine Grid-Galerien mit Dateien als Paletten (wie Photoshop, AutoCAD, Blender): Baudokumentation, Kommentare, Filtern von Ebenen, Elemente, Zeichentools. Umgesetzt nur: Kachelraster „Pläne“ (4 Planstände, Klick öffnet den Vergleich).
- Kopf: Werkzeuge prüfen (was real wofür, wann): Maße eintragen; Fotos als Canvas importieren, platzieren, transformieren auf Blattuntergrund/Vorlagendatei (ausblendbar, Druckausgabe, Maßstab); Import/Ausgabe DWG, HTML, DXF, SVG; Wiederbearbeitbarkeit; Laser-Sync; Symbole für Bauzeichen (Steckdosen, Installation nach DIN, Wasser, Elektro, Architektur). Offen: „In Kopf bitte“ nicht eindeutig (Kontextleiste oder Merken?). Nichts davon gebaut.
- Scroll/Zoom zu schnell: behoben. Rad scrollt jetzt (Pan), Strg/Cmd+Rad oder Pinch zoomt weich (exp, Schritt je Ereignis auf 40 begrenzt).

## 8c · Altcode-Befunde (GitHub JohannesLeoB/ALFA_OS@main, 19.10.2026) und Abweichungen der Entwürfe
Quelle: nur Domain- und Service-Code unter fundus/alpha/Sources; SwiftUI-Views liegen nicht im Repo (unbekannt: reale Bedienabläufe, Layout der Werkzeuge). Gelesen ganz: 42 Dateien (Aufmaß 7+1, Skizze 11, Konfigurator 7, CADProjektStart, Plan-Sammler 2, Entwurf-Stores 3, WidgetBoardStore, WidgetSignal, AssetNotiz, kein-mykilos-Memo). Nicht gelesen: LeicaDistoBluetoothAdapter, LaserDiagnoseScanner, Moodboard-/Papers-Typen, Feature-Verzeichnis alfaos/Kit (84 Dateien), Rest von Domain (98 Dateien).

**Aufmaß = Foto-Aufmaß, nicht Raumaufmaß.** Modell: `Aufmass` hat Fotos, Positionen, Layers, Symbole, Pins (AufmassModell.swift). Position = Bezeichnung, Meter, Quelle (manuell/Laser/auto), Bildlinie 0–1 auf dem Foto, Layer, Stil (dünn/normal/gestrichelt/punktiert). Kalibrierung pro Foto: Referenzlinie + realer Meter (isotrop) oder getrennt X/Y. Einheiten mm/cm/m, Fläche m², Volumen m³. Standard-Layer: Gesamtmaße, Wasser/Installation, Details; max. 10 Layer mit Farbpalette; Layer pro Layer Schriftgröße. Installationssymbole (11): Wasser, Abwasser, Gas, Strom, Steckdose, Netzwerk, Heizung, Lüftung, Lautsprecher, Gerät, Anschluss. Pins mit Text. Auto-Bemaßung: Hauptkanten aus gesetzten Punkten (Achsen-Bänder, Mindestspanne 0,12, bis 8 je Achse). Perspektive: Fluchtpunkte aus Linien (1–3), Horizont, Leitstrahlen, Snap auf Fluchtpunkt ≤ 7°. Viewport: Zoom 1–12, Pan an Zoom geklemmt. Laser: Leica Disto D110 über Bluetooth-Profil. Dateiname: Projekt_Aufmaß_Titel_Datum. Speicher: Entwurf mit Foto, max. 10 je Projekt (Skizze) bzw. Datenbank-Eintrag (Aufmaß).
**Entwurf ALFA Aufmass weicht ab:** Räume mit Wänden und Öffnungen (ALFA Aufmass.dc.html:306ff.), kein Foto als Grund, keine Kalibrierung, keine Installationssymbole/Pins. Umbau nötig.

**Atelier = Skizze auf Foto + Render-Rezept.** Modell: `SkizzenDokument` = Foto + Layer + 6 Material-Slots (Ultramarin, Terrakotta, Salbei, Ocker, Graphit, Taube) + Maßanker. Layerarten: Bestand, Neu, Entfernen, Notiz (Notiz wird nicht exportiert). Objekte: Polylinie, Rechteck, Freihand; Strich schwarz/weiß/Slot, dünn/mittel/dick; Füllung = Slot; Deckkraft. Platzierte Bilder: Position, Breite, Rotation, Spiegeln, Deckkraft, Sperre, z-Index. Foto-Filter: keiner/Schwarzweiß/abgedunkelt. Perspektivraster 1/2/3-Punkt mit Snap, Winkelraster 45°/7°, Magnet. Undo-Stapel (500). Substrat grün = gefülltes Volumen vorhanden und alle benutzten Slots haben Material. Pipeline: Skizze → Prompt (Szene, Geometrie, Materialien, Stil, Verbote) → Rezept (Substrat, Referenzen, Prompt, Engine, Stil) → Version (Entwurf, Freigegeben, Master, Verworfen; Eltern-Version) → Auftrag. Engines: Firefly manuell (heute einzige), Nano Banana 2, Nano Banana Pro. Stile: fotorealistisch, Architektur editorial, Innenarchitektur weiches Licht, skizzenhaft. Materialquellen: Material, Gerät, Stil-Anker, eigenes Bild.
**Entwurf ALFA Atelier weicht ab:** Pipeline-Stufen (Skizze prüfen … Render) sind erfunden (Atelier:334); Parameter Stil/Licht/Auflösung/Perspektive/Material (Atelier:333) existieren im Altcode nicht (Licht, Auflösung: unbekannt); Layerarten und Slots fehlen; Werkzeuge Stift/Linie/Rechteck/Radierer decken nur Teil ab (Polylinie, Freihand, Füllung fehlen); Versionsstatus fehlt.

**Konfigurator (Bogen fehlt).** Modell `KonfigEntwurf`: Variante (Entwurf A, B …), Status Vorplanung/Vorabzug/Final (Stempel), Raumbezug (Aufmaß, Skizze, Foto, freie Maße, keiner), Materialdeklaration (Front, Korpus, Sockel, Schubkästen, Griff, Arbeitsplatte) mit Paletteneinträgen, Zonen (Zeile, Wandschränke, Hochschränke, Insel, frei) → Segmente (Breitenraster 300/400/450/600/800/1200) → Fächer (Tür, Schubkästen n × Legrabox/Holz, offenes Regal, Fachböden, Blende, Gerät, Spüle, Müllauszug, leer). 8 Archetypen. Kürzel-Eingabe (z. B. 600t, 3s, sp, gs). 7 Regeln (davon 2 belegt, 5 Annahme; Durchgang Insel ≥ 1000 mm, hart 850). Ausgaben: Anfrage-Text Tischler/Steinmetz, Render-Prompt, Kompilate mit Quellenstand (Aufmaß, Artikelpreise, Moodboard). Gewerk-Umfang: Tischler Korpusse, Steinmetz Arbeitsplatte, Studio Geräte. Konfigurator hängt an Aufmaß, Skizze, Moodboard, Artikelkatalog.

**Planvergleich.** Im Altcode kein Planvergleich gefunden (grep Dateinamen). Vorhanden: Plan-Sammler pro Projekt aus Drive, Kategorien Pläne, Werkszeichnung, Renderings, Vorplanung & Screenshots, Layouts, Präsentation; erlaubte Typen pdf, jpg, jpeg, png, heic, heif, tiff, tif, webp (nicht dwg/dxf); Sortierung Datum/Projekt/Kategorie/Name. Signal `drawingDetected`. Für den Vergleich: Fassungen = Dateien aus diesen Kategorien, vom Nutzer gewählt (passt zu Johannes' Antwort); OCR, Ausrichtung, Schwelle: unbekannt, nicht im Altcode.

**Hub.** Gemeinsame Quellen im Altcode: Projektnummer als Schlüssel in allen Entwurf-Stores, Drive-Projektordner, Artikelkatalog, Mediathek-Index, WidgetSignal. Ein Hub-Bogen ist damit abbildbar; Bedienung: unbekannt.

**Streichliste (Repo-Regel, .claude/memory):** "myk" in Code, Tokens, Dateiendungen verboten. Betroffen im Altcode: Endungen `mykaufmass.json`, `mykcad.json`, Gewerk `mykilos`. In Entwürfen nicht verwenden; Ersatzname für Endungen: unbekannt, Johannes entscheidet.

**Plan, nicht begonnen (Reihenfolge Vorschlag):** (1) Aufmaß auf Foto-Aufmaß umbauen; (2) Atelier: Layerarten, Slots, Versionsstatus, echte Pipeline; (3) Konfigurator-Bogen neu; (4) Planvergleich-Palettenkarten; (5) Hub.

## 8d · Aufmaß als Foto-Aufmaß, Entwurf v2 (19.10.2026)
Alter Raum-Entwurf gesichert als `ALFA Aufmass v1.dc.html`. Neu: `ALFA Aufmass.dc.html`. Belegt durch Altcode (8c); alles andere ist Entwurf.
- **Aufbau (Adobe-Muster, ALFA-Hülle):** links Fotos (nach Projekt) + Ebenen des Fotos (unten, Auge/Schloss, Rechtsklick, Taste 1–9); Mitte Kopf (Foto|Blatt, Zoom, Undo/Redo), Kontextleiste (wechselt je Werkzeug, wie Optionsleiste), schwebende Werkzeugpalette, Arbeitsfläche; rechts Reiter Maße | Auswahl | Foto, Fuß mit Foto-Check / Maßliste, Kopf mit Laser, Ausgabe, Kurzbefehle.
- **Werkzeuge:** V Auswahl, H Hand, K Kalibrieren, M Maß, A Auto-Bemaßung (Punkte setzen, dann „Hauptkanten bemaßen", Mindestspanne 12 %), P Perspektive (FP 1–3, Einrasten ≤ 7°), S Symbol (Galerie Wasser/Elektro/Technik mit den 11 Altcode-Symbolen), T Pin, L Laser.
- **Maus:** Rad scrollt, ⌥+Rad zoomt (umschaltbar in Kurzbefehle), ⌘/Strg+Rad und Pinch zoomen (Schritt begrenzt), Leertaste oder Mitteltaste = Hand, Doppelklick Fläche = Einpassen, Doppelklick Maß = Wert editieren, Rechtsklick = Menü, ⇧ = 0/45/90°, ⌥-Ziehen = Duplikat, Pfeile = Schieben, ⌘Z / ⇧⌘Z. Zoom 1–12× (Altcode).
- **Blatt:** Foto auf A3-Quer-Vorlage mit Schriftfeld, per Schalter ausblendbar. Maßstab = nach Referenz (Foto ist perspektivisch, Maße gelten nur in der Wandebene der Referenz).
- **Foto-Check:** Laser-/Handmaß gegen Kalibrierung, Abweichung > 2 % oder 10 mm rot (Beispiel Fensterbank 1,48 m statt 1,40 m).
- **Attrappen:** Foto selbst (Platzhalter), Ausgabe PDF/SVG/DXF/DWG/HTML, Projektdatei, Vorlage laden, Laser-Bluetooth, Hub-Quellen beim Foto hinzufügen, Maßliste.
- **Unbekannt:** Layerfarben und DIN-Zuordnung der Symbole (Altcode nur Namen), Format A4/A3/A2 ändert nur das Schriftfeld, Blattmaße real, Zeichenstifte/Freihand fehlen (kein Beleg im Aufmaß-Altcode).
- Nicht getestet im Browser: Echtzeit-Verhalten von Ziehen, Pinch, Rechtsklick (nur Code gelesen).

## 8e · Atelier v2 (19.10.2026), gleiche Hülle wie Aufmaß
Alter Entwurf: `ALFA Atelier v1.dc.html`. Belegt durch Altcode 8c (Skizze/Render), Rest Entwurf.
- **Links:** Skizzen nach Projekt (Zähler = Renderfassungen); darunter feste Ebenenarten Bestand, Neu, Entfernen, Notiz (Auge, Schloss, Taste 1–4; Notiz nicht im Export). „+“ = Bild einsetzen.
- **Werkzeuge:** V Auswahl, H Hand, P Stift, L Polylinie (Doppelklick/Enter beendet, Klick auf Startpunkt schließt), R Rechteck, F Füllung (⌥ löscht), E Radierer, I Bild, T Notiz, G Perspektivraster (aus/1/2/3, Einrasten ≤ 7°, ⇧ 45°). Kontextleiste: Strichfarbe (Schwarz, Weiß, 6 Slots), Stärke, Ebene, Füllung, Deckkraft.
- **Rechts:** Objekt (ohne Auswahl: Foto-Filter keiner/Schwarzweiß/abgedunkelt, Raster) | Slots (6 Material-Slots, Substrat-Status) | Rezept (Ablauf Skizze, Prompt, Rezept, Substrat, Auftrag; Stil, Engine; Prompt in 5 Abschnitten) | Versionen (Status Entwurf/Freigegeben/Master/Verworfen, Elternversion, offener Auftrag).
- **Pipeline-Regel:** „Auftrag senden“ erst, wenn Substrat grün (gefüllte Form + alle genutzten Slots belegt). Beispiel Küche: Terrakotta genutzt, ohne Material, daher rot.
- **Alt entfernt (Erfindung im v1):** Stufen „Licht setzen / Nachbearbeiten“, Parameter Licht und Auflösung.
- **Attrappen:** Foto, Bildquellen, Render selbst (Platzhalter), Ausgabe, Engines außer Firefly manuell.
- **Unbekannt:** Wortlaut der Verbote; ob nur ein Master je Skizze (im Entwurf ja, Annahme); Ebenenfarben; Slot-Farbwerte (aus Namen abgeleitet).
- Außerdem Aufmaß: Hand-Cursor blieb nach Ziehen hängen, behoben.

## 8f · Konfigurator (neu), 19.10.2026
Neu: `ALFA Konfigurator.dc.html`, gleiche Hülle. Navigation „Konfigurator“ in allen fünf Editoren ergänzt. Belegt durch Altcode 8c (KonfigEntwurf), Maße und Regeln teils Annahme.
- **Mitte:** Frontansicht in mm mit Maßkette je Zone (Hochschränke, Zeile, Wandschränke, Insel, frei), Boden, Sockel und Platte. Tasten: V, H, S Segment setzen, F Fach-Typ (Galerie mit 9 Typen), K Kürzel (Zahl ≥ 100 = Breite, Zahl < 10 = Anzahl: 600t, 3s, sp, gs, 3s800). Ziehen sortiert Segmente, ← → verschieben, ↑ ↓ Breite im Raster 300/400/450/600/800/1200.
- **Links:** Varianten (Projekt → Entwurf), darunter Zonen mit Auge, Schloss, Rechtsklick.
- **Rechts:** Segment (Breite, Fächer mit Typ, Schubkästen Anzahl/System, Gerät Bezeichnung; ohne Auswahl: Variante mit Stempel Vorplanung/Vorabzug/Final, Raumbezug) | Material (6 Deklarationen) | Regeln | Ausgabe (Quellenstand, Anfragetext Tischler und Steinmetz, Render-Prompt).
- **Unbekannt/Annahme:** Höhen (Hoch 2200, Sockel 100, Korpus 720, Platte 40, Wand ab 1450); Archetypen (8 im Altcode, Namen hier nicht gelesen, daher nicht abgebildet); Regeln: nur Durchgang Insel (Soll 1000, hart 850) belegt, „Zeile gegen Wand“ Annahme, 5 weitere unbekannt; Materialnamen Platzhalter; Wand 4,43 m aus Aufmaß-Entwurf.
- Fehler behoben: Atelier hatte `inp()` nicht (Notiz bearbeiten hätte abgestürzt).

## 8g · Konfigurator Ausbau (19.10.2026)
Gelernt aus Recherche (kitchen-plan-studio, cabinet-studio, H2, furniconfig): ein Modell, daraus Ansicht, Prüfung, Teile, Anfrage abgeleitet; Geräte als Objekte mit Nische; Live-Prüfung.
- **Ansichten:** Front | Grundriss (Taste 1/2). Grundriss zeigt Wand, Zeile mit Platte, Hoch, Wand (gestrichelt), Insel, Spülbecken, Durchgangsmaß live (rot unter Soll 1000).
- **Material sichtbar:** Fronten, Korpus, Sockel, Platte, Griffe in der Farbe der Materialdeklaration (Farben = Darstellung).
- **Geräte:** Backofen, Mikrowelle, Kühlschrank, Geschirrspüler mit Nische B×H×T (Richtwerte, Herstellerdaten unbekannt) und Modulbreite 600; Fachhöhen folgen der Nische.
- **Prüfung (Reiter + Kopf, Segment wird rot):** Wandlücke/Überlänge, Passblende bis 150 mm (abschaltbar), Wandschränke über Zeile, Gerät passt nicht in Segment, Fächer zu hoch, Durchgang. Belegt nur Durchgang 1000/850, Rest Annahme.
- **Teile:** Zuschnittliste je Material mit m², Beschläge (Auszüge, Griffe), Kopie als Tabelle. Annahmen: Korpus 19, Rückwand 8, Sockel 16, Tiefe 560/320, Platte 600/900.
- **Einstieg:** Neue Variante mit Layout (Einzeilig, mit Insel, Komplett, Leer) oder Kopie.
- **Preise:** nicht angezeigt (Katalog unbekannt).
- **Nicht gebaut:** 3D, DXF/SVG real, Archetypen, Moodboard-Anbindung.

## 8h · Sync mit GitHub, 19.10.2026 (Korrekturen aus erneutem Lesen)
Repo-Pfade jetzt AlfaKit/AlfaServices (vorher Mykilos…), 33 Dateien gleich. Gelesen ganz: AufmassLayer, SkizzenLayer, MaterialSlot, KonfigRegeln, KonfigArchetypen. Nicht gelesen: Rest.
- **Korrektur 8c/8f/8g:** Durchgang Insel ist im Altcode Annahme (nicht belegt). Belegt sind nur „Wärmeschublade unter Backofen“ und „Zone passt in den Raum“ (nur bei freien Maßen). Weitere Regeln, alle Annahme, Hinweis: GS neben Spüle, Müll in Spülen-Nähe, Kochfeld braucht Dunstabzug, Spülen-Korpus ≥ 450. StudioMasse: Durchgang Soll 1000, hart 850, Nischenhöhe 560–600, Arbeitshöhe 850–950 mm.
- **Zonenmaße (Altcode), im Konfigurator übernommen:** Hochschrank Tiefe 650, Korpus 2620, Sockel 80; Zeile 635/780/80; Wand 350/800/0; Insel 950 bzw. 1160 (+300 Überstand) bzw. 1200; Sideboard 450/700/60. Segmentbreiten frei (759, 825, 725 kommen vor), das Raster 300–1200 ist nur Auswahl. Plattenstärke 40 und Plattenüberstand 20 bleiben Annahme.
- **8 Vorlagen** (Namen aus Altcode) über Zonen-Plus „Vorlage einsetzen“. Fachhöhen des Altcodes (800/1260/560) sind im Entwurf nicht abgebildet, Höhen werden verteilt.
- **Regeln im Entwurf** zeigen Quelle belegt/Annahme/Entwurfsidee. Entwurfsideen (nicht im Altcode): Zeile gegen Wand, Passblende, Fächerhöhe, Gerät-Modulbreite, Wandschränke über Zeile.
- **Atelier:** Slots heißen „Slot A–F“ mit Farbe Ultramarin, Terracotta, Salbei, Ocker, Graphit, Taube. Offen: Der Altcode erlaubt mehrere Ebenen je Art (Name + Art, Deckkraft je Ebene; Standard Neu, Bestand, Entfernen, Notizen). Der Entwurf hat vier feste Ebenen. Nicht umgebaut.
- **Aufmaß:** Ebenenfarben im Altcode sind Token-Namen (critical, cash, positive, drive, tasks, personal, team1–3, brand), Schriftgröße je Ebene Standard 9. Entwurf nutzt eigene Farben. Nicht angepasst.
- Nischenmaße unbekannt: Wärmeschublade, Kaffeevollautomat, Kochfeld, Dunstabzug.
- Kein Commit-Stand bekannt, daher kein Diff gegen den ersten Sync.

## 8i · Atelier-Ebenen nach Altcode (19.10.2026)
Ebenen haben Art (Bestand, Neu, Entfernen, Notiz), Name, Auge, Schloss und Deckkraft (100/60/30, wirkt auf Striche und Bilder der Ebene). Standardsatz in Altcode-Reihenfolge: Neu, Bestand, Entfernen, Notizen. Beliebig viele je Art über „+“ im Ebenenfeld (Menü „Neue Ebene“); Rechtsklick: Umbenennen, Sperren, Deckkraft, Löschen (Inhalt wandert auf die erste andere Ebene); Doppelklick benennt um; Tasten 1–9. Notiz-Art zählt weder zum Substrat noch zum Prompt (Altcode: wirdExportiert = nein). Bestehende 8e-Aussage „vier feste Ebenen“ gilt nicht mehr. Unbekannt: Obergrenze der Ebenenzahl bei Skizzen; Ebenenfarben (Entwurf: eigene je Art).

## 8j · Moodboard und Planvergleich (19.10.2026)
Geprüft: Moodboard und Planvergleich haben bereits dieselbe Hülle (Kontextleiste, schwebende Palette, Arbeitsfläche, Stapel rechts); das Muster von Aufmaß, Atelier, Konfigurator stammt von dort. Kein Umbau nötig. Geändert: Planvergleich fängt Strg/Cmd+Rad jetzt am Dokument ab (vorher konnte der Browser mitzoomen), Zoom und Scrollen wie in Atelier/Aufmaß. Offen aus Kommentaren Johannes: Palettenkarten (Baudokumentation, Kommentare, Ebenen filtern, Zeichentools) und Werkzeugkopf (Maße, Foto-Canvas, Import/Ausgabe DWG/DXF/SVG, Laser, DIN-Symbole) im Planvergleich nicht gebaut.

## 8k · Master-Abgleich 19.10.2026
Geprüft gegen ALFA_OS/DESIGN/MANIFEST.json: Rang „latest“ = „ALFA OS Interface CHEF 1610-handoff 1810“ (18.10.2026, zipSha256 d0ed5abb…); design.stamp.json im Repo: TOKENBOGEN Stand 18.10.2026 21:18, Inhalt-Hash 658ae363…. Projektdateien ALFA Shell.dc.html, alfa-shell.js, alfa-theme.css, TOKENBOGEN.json sind byteweise gleich mit dem Export 18.10. Nichts zu ersetzen. Nicht geprüft: ob die Editoren-Bögen jeden Wert des Tokenbogens nutzen (nur Minima 280 und Menüradius 16 belegt, 8a).

## 8l · Echter Abgleich gegen Master 18.10. (19.10.2026)
Gelesen ganz: TOKENBOGEN.json (alle Nicht-Farb-Werte, alle Farben, Schatten), alfa-shell.js 77/77, alfa-theme.css 14/14, ALFA Shell.dc.html 243/243. ALFA Mail.dc.html (190 KB) nicht ganz: nur Bauteil-Kopfzeilen aller 52 data-parts und die Stapel-Logik (Z. 920–951, 411). Nicht gelesen: Huelle, Farbsystem, Designsystem, Dienste, Entscheidungen, Einstellungen, Tokenbogen-Bogen, ABNAHME.md, RUECKGABE-AN-CODE.md.
**Gleiche Dateien heißt nicht gleiche Nutzung.** Die Editoren wichen an diesen Stellen vom Master ab, jetzt korrigiert (Moodboard, Atelier, Aufmaß, Konfigurator; Planvergleich teils):
- Karten im Stapel: fehlte Radius 20/20/0/0 (radius.card, cardBottom 0) und der Lack-Schatten (box-shadow war none); Kartenkopf ohne Linie; Köpfe tiefer als die dritte Karte müssen 8 statt 44 hoch sein (count.stackHeads 3); nur 3 statt 5 Farbstufen (stack.light/dark); Flach-Schatten der hinteren Karten fehlte eine Lage; Übergang ohne left/right 520 ms.
- Oberfläche Standard: Master „flach“ (Mail data-props), Editoren hatten „Lack“. Jetzt „flach“.
- Symbolknopf: Hover zeigt Ring ink-3 (Master), vorher nur Farbe.
- Textknopf: 24 hoch, Schrift ink-2, Hover-Fläche (Master Mail Z. 41), vorher 28 hoch, ink.
- Eingaben: Zeilenwert ohne Rahmen, rechtsbündig, Innenrand 12 (size.trailingTextInset); Kontextleiste Unterstrich statt Rahmen mit Radius 8 (Master input-field); Fokus Unterstrich ink. radius.field ist 4, die 8 stammte nicht aus dem Master.
- Blatt-Schatten: var(--sh-float) statt eigener Wert; Linien var(--c-sheet-line).
**Noch abweichend / unbelegt:**
- Planvergleich: rechte Bahn ist eine Reiterleiste ohne Karten (Master: Kartenstapel). Nicht umgebaut.
- Kontextleiste 40 hoch, schwebende Palette (Radius 12), Ebenenfeld unten links, Kachelraster: kein Bauteil im Master, Entwurfswerte. Bitte entscheiden, ob sie in den Tokenbogen sollen.
- Menü-Zeilenradius: Master Mail nutzt 8, der Tokenbogen schreibt 12 + Rand 4 (radius.contextMenu-Kommentar). Widerspruch im Master. Editoren folgen Mail (8).
- Feldzeile (field-row) in Karten: Höhe min 44, Abstand 4/12, Master hat feste Zeilen (36/44). Nicht angeglichen.
- Moodboard: eigene Listenzeilen (44 hoch), Raster-Overlay mit fest #b3412e/rgba(179,65,46,…) statt Token (Blattfläche immer hell, daher gleich Signal hell); Palette #ebebeb u. a. sind Inhaltsfarben.
- Domänenfarben (Slots, Ebenen, Materialien, Zonen) sind keine Tokens.
- Schriftgrößen 15/24 px im Schriftfeld des Blatts sind Zeichnungsinhalt (skaliert).
- Nicht geprüft: Dunkelmodus der Editoren, Zeitwerte außer Hover/Stapel, Fokusring, reduzierte Bewegung (kommen aus alfa-theme.css, Editoren setzen nichts dagegen).
- Wach-Blob und Orb: kommen aus der Shell, die identisch ist; Editoren übergeben assistentGesicht nicht (Master-Standard Augen).

## 8m · Korrektur zu 8l (19.10.2026)
Fehler in 8l: Die rechte Bahn der Editoren ist absichtlich KEIN Kartenstapel (Regel 5, NACHFOLGE_PROMPT.md: „Keine Stapelkarten. Andere UI-Blöcke.“). Alle fünf Editoren zeigen eine Karte mit Reiterleiste (stackCards() reduziert auf die vordere Karte, Hintergrund transparent, Schatten none). Daher:
- Planvergleich bleibt bei der Reiterleiste. Kein Umbau. Die Zeile „Planvergleich weicht vom Kartenstapel ab“ in 8l entfällt.
- Die Korrekturen an stackCards0 (Köpfe 8, 5 Stufen, Lack/Flach-Schatten, Oberfläche flach, left/right) wirken in den Editoren nicht sichtbar, weil stackCards() sie überschreibt. Harmlos, aber ohne Nutzen; nicht zurückgebaut.
- Sichtbar wirken: Linie unter dem Reiterkopf (hLine), Knöpfe, Eingaben, Blatt-Schatten.
- Offen für Johannes (ask_user gestellt): Kontextleiste, schwebende Palette, Ebenenfeld, Kachelraster, Menüzeilenradius 8 oder 12.

## 8n · Master-Lesung und Angleichung (19.10.2026, nach Rüge)
Johannes 19.10.: „du hast den Master doch noch nicht voll gelesen!!!! Das darf NIE passieren!“ und: „Bitte übernimm die aktuellsten Master und Shell Werte, trage deine Bauten da aber noch nicht ein.“
- Leseprotokoll mit Zeilen gelesen / Gesamt je Datei: `MASTER_LESEPROTOKOLL.md`. Ganz gelesen: alle zehn Bögen (Mail 1093/1093, Shell, Huelle, Designsystem, Dienste, Entscheidungen, Farbsystem, Bestaetigen, Einstellungen, Tokenbogen), alle MD-Dateien, akte.json, decisions.json, settings-sections.json, motion-springs.json, alfa-shell.js, alfa-theme.css, CATALOG.md, AN-DESIGN-LIEFERUNG-15.md.
- NICHT gelesen: TOKENBOGEN.json Rohtext Z. 2001–5838 (Werte, Beschreibungen, Status, Farben und Schatten per Skript geparst, vollständig aufgelistet, aber nicht als Rohtext gelesen), INHALT.json, werte-abgleich.json (23960 Z., maschinell), design-system/*, uploads/SKILL.md. Einzelne überlange Zeilen in Mail zeigt das Werkzeug gekürzt (Z. 74, 231, 358).
- **Nicht in den Master eingetragen:** Kontextleiste, schwebende Palette, Ebenenfeld, Kachelraster, Perspektive/Substrat, Zonen usw. bleiben Entwürfe der Editoren. TOKENBOGEN.json, alfa-shell.js, alfa-theme.css, ALFA Shell.dc.html im Projekt sind unverändert gleich dem Master 18.10.
- **Angeglichen heute (sichtbar):** Symbolknopf-Hover mit Ring, Textknopf 24/ink-2/Hover-Fläche, Eingaben ohne Rahmen (Zeile) bzw. Unterstrich (Kontextleiste), Blatt-Schatten = var(--sh-float), Sheet-Linien = var(--c-sheet-line), Linie unter Reiterkopf. ⌘-Beschriftungen aus Tooltips und Kontextmenüs der Editoren entfernt (Regel Johannes 13.10.); sie stehen nur noch in der Hilfeliste „Kurzbefehle“ (Master zeigt Kürzel ebenfalls nur als Liste in den Einstellungen).
- **Offene Fragen an Johannes:** (a) Warnhinweise in Editoren (Konfigurator „Prüfung“, Aufmaß „nicht kalibriert“, Planvergleich-Funde) sind Signalrot. Master: kind „warning“ = ink-2, Signalrot nur für Fehler und Destruktives (Mail Z. 1043, AUDIT.md §2.5). Angleichen oder Planvergleich als gesehene Messlatte lassen? (b) erledigt: Moodboard-Menü „Alles wählen“ ohne ⌘A. (c) Menüzeilenradius 8 oder 12 (Master widerspricht sich).

## 8o · Rest des Masters gelesen (19.10.2026)
TOKENBOGEN.json: alle 349 Werte und alle 321 Tokens mit Beschreibung, Beleg, Status, where gelesen (Skriptausgabe). Noch nicht gelesen: INHALT.json, werte-abgleich.json, design-system/*, uploads/SKILL.md; stack/surface-Tokens nur gekürzt. Neu aus dem Tokenbogen: Menübreiten sind Tokens (size.menuWidthNarrow 200, Compact 220, Row 232, Default 240, Wide 260, Attach 280, Person 300). Editoren angeglichen: Aufmaß 140 und 160 → 200, Konfigurator 320 → 300. Weitere Menübreiten der Editoren liegen bereits auf Token-Werten.

## 8p · Neuerer Stand als Export 18.10. (19.10.2026)
Johannes hat „6 · Von Design gesetzt · offen“ aus einem NEUEREN Master eingefügt (Status „designSet“, Brief v9 19.10., ALFA_OS/DESIGN/brief/BRIEF.txt). Dieser Master liegt weder im Projekt noch in ALFA_OS/DESIGN (dort nur Export 18.10.). Unterschiede zum 18.10.: size.menuWidth* (200…300) fehlen; stattdessen size.menuMinWidth 168 und size.menuMaxWidth 280 (ALFA Mail menuW()); size.focusRingOffset 1 (Entscheidung von Design 19.10.); settingsTileHeight 112, settingsTileMinWidth 112; layer.* (lane 1, handle 2, syncButton 3, toast 4, menu 5, safeArea 7, inLane.overview 2, inLane.toast 3); scale.pressTile 0,98; opacity.cardMeta 0,72 und cardMetaDeep 0,95; typography.textStyle.* und tracking.*; shadow.*.stackFront/stackBack; motion.duration.scrollLine*; size.reelTopOffset 8.
- Heute übernommen (aus dem eingefügten Text): Menübreite in allen Editoren auf 168 bis 280 begrenzt (openMenu, openMenuAt). Die 8o-Aussage zu den sieben Menübreiten gilt nur für den 18.10.
- Nicht übernommen, weil Dateien fehlen: alfa-theme.css (Fokusabstand 1), Shell, TOKENBOGEN.json des neuen Stands. Bitte neuen Export (19.10.) hochladen.
- Brief v9 verlangt vom Design: contract/ mit Tokens (DTCG), components.json, views.json, texts.json, changes.json; Status approved / approved-provisional / set-by-design; offen L-008 bis L-016, W-03 bis W-10.

## 8q · Werteprüfung Editoren (19.10.2026)
Skript-Abgleich aller px- und ms-Angaben in den fünf Editoren gegen alle Tokenwerte aus TOKENBOGEN.json (18.10.) plus 168/112/308 aus dem eingefügten neueren Stand. Ergebnis: alle ms-Werte haben einen Token. px ohne Token blieben nur: Zeichnungsinhalt im Blatt (Schriftfeld 15/24, Maße 50/90/850/1300), Moodboard-Drehgriff 11 und −26 (nicht geändert), Kontextleisten-Eingabefelder mit fester Breite (nicht geändert).
Geändert: Ebenenpunkt 10 → 8 (spacing.statusDot), Statuspille Innenrand 10 → 8, Zeilenlabel min 72 → 96 (size.composeColumnMinWidth, Mail Z. 288-Muster), Zeileneingaben ohne feste Breite (flex 1, max 60 %, wie Mail Z. 288), Kachel-Mindestbreite 104 → 112 (settingsTileMinWidth neuer Stand), Auswahlring 3,5 → 3 (selectionRingWidth 2 + hairline 1).
NICHT geprüft: Rollen (Wert gleich ≠ Bedeutung gleich), Farbwerte der Inhaltsebenen, Dunkelmodus, rgba-Werte außer Karten-/Blattschatten, Zeitwert-Rolle. Kontextleiste 40 hoch, Palette, Ebenenfeld, Kachelraster: kein Master-Token (Entwurf).

## 9 · Geheimnisse

Keine Zugangsdaten gesehen. Die Einstellungs-Zeilen im Screenshot zeigen nur Status („Schlüssel gespeichert"), keine Werte.

## Regel Mastersystem (Johannes, 19.10.2026)
Mastertoken, Hülle/Shell, Theme und Bauteile immer nach dem neuesten Design-Master richten. Aktuell: „ALFA OS Interface CHEF 1610-handoff 1810“ (18.10.2026, TOKENBOGEN Stand 21:18). Quelle der Wahrheit für „neuester“: ALFA_OS/DESIGN/MANIFEST.json, Rang „latest“. Vor jeder Sitzung: Master-Datum prüfen; bei neuerem Master ALFA Shell.dc.html, alfa-shell.js, alfa-theme.css, TOKENBOGEN.json ersetzen und Editoren auf die neuen Werte stellen. Bögen des Masters (Mail, Einstellungen usw.) nicht übernehmen.
