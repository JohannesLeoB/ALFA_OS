# Spec-Nachtrag Design · 23.10.2026
Arbeitsstand, nicht freigegeben. Form wie .claude/memory/spec-*.md: ID · Spec · Fundstelle im Bogen · Herkunft. Werte stehen in der Fundstelle, nicht hier.

## MAIL-P · Postfächer (linke Bahn)
MAIL-P01 Postfach-Stapel unten in der linken Bahn; Karten überlappen nach unten; oberste Karte = offenes Postfach. · ALFA Mail.dc.html:32 (account-deck) · entscheidungen.md:391, :406
MAIL-P02 Postfachkarte: Material 1:1 wie Karte rechter Stapel, voll gespiegelt (Fläche LEVELS.grau; Glanzkante, Naht, Schatten und Radien unten statt oben; Tokens color.stackGlossFront|Light|Dark, stackSeamFront|Back, stackDrop, size.stackDropOffset|Blur|Spread, siehe components.json account-card.measures); Ring, Abstände, Radien wie Kartenkopf rechter Stapel; nur Ring + Name, keine Adresse. · :33 (account-card.pick), :34 (ghost) · :407–:409
MAIL-P03 Anzeige je Postfach: eigener Name | Teil vor @ | Teil nach @; ohne eigenen Namen Teil vor @. Wahl in Einstellungen und per Sekundärklick auf Kopf und Karte. · Mail :17, :33; Einstellungen :292–:293 · :410
MAIL-P04 Kopf der Bahn ist Knopf, zeigt das offene Postfach. · :17 (account-title) · :414
MAIL-P05 Schalter Postfächer am Fuß: Plus öffnet/schließt den Stapel; zugedeckte Postfächer mit Ungelesenem → Hinweis am Plus. · :35–:36 (account-alert.deck) · :411
MAIL-P06 Neue Mail geht immer vom obersten Postfach. · :35 (compose-button.new-go) · :414
MAIL-P07 Wechsel des Postfachs wechselt alles, was ihm gehört: Ordner, Labels, Liste Mitte, Stapel rechts, Zähler, Entwürfe. · :491 (glassSwap) · :421, :422, :425
MAIL-P08 Gefaltet: Ringe des Stapels mittig auf der Achse des Streifens, unten. · :32–:36 · :417, :418
MAIL-P09 Umschlag-Zeichen für den Postfach-Stapel. · :36 (envelope-stack, envelope)

## MAIL-W · Wechsel und Bewegung
MAIL-W01 Postfachwechsel: Ansicht kurz getrübt, Inhalte tauschen darunter; Trübung statt Bewegung, ohne aufblitzende Haarlinien. · :14 (switch-glass), :491 · entscheidungen.md:421; Tokens motion.duration.switchIn/switchOut
MAIL-W02 Zwei Gesten (Vorschlag, nicht freigegeben): Gleiten = Ort/Größe, Tauschen = Inhalt. Vier Zustände je Ding (Fläche, Marke, Zeile). Tokens motion.glide, motion.swap, state.*, axis.* fehlen im Tokenbogen. · — · Chat 23.10., Freigabe offen

## MAIL-O · Postausgang
MAIL-O01 Ordner Postausgang nur solange Mails darin; Zeile „An <Name>“; Klick wählt nur. · :426 · :436–:438
MAIL-O02 Gescheiterte Prüfung: Rückfrage „Ungeprüft senden?“ als eigene Zeile unter dem Status; Zahl am Ordner Signal. · :116 · :436–:438

## MAIL-G · Bahngrenzen (nur Bereich Mail, nicht Hülle)
MAIL-G01 Linke Bahn höchstens 280 beim Ziehen; Falten, Öffnen, Zurücksetzen bleiben. Gilt nur für Mail: Grenzen sind je Ansichtsbereich festgelegt, die Hülle liefert nur das Werkzeug (AREA.<Bereich>.max, leer = ohne Grenze). Einstellungen und andere Bereiche ohne Grenze, bis Johannes je Bereich festlegt. · alfa-shell.js:6 (AREA.Mail.max), :50 (grow) · v14 Teil 2; Johannes 23.10.

## MAIL-K · Kacheln
MAIL-K01 Mitte als Kacheln: Schalter erst ab 320 px Spaltenbreite. · :757 · Prüfer 23.10.

## HUB-A · Postfächer in Einstellungen
HUB-A01 Je Postfach: Name in Mail, Angezeigt als, Bilder in Mails laden, Entfernen; Signatur je Postfach. · ALFA Einstellungen.dc.html:265–:269, :251 · :410, :443
HUB-A02 Reihenfolge der Postfächer, Postfach hinzufügen: im Bogen nicht gefunden. Offen.

## HUB-D · Dateiordner
HUB-D01 Kategorie „Dateiordner“ in der linken Spalte (Ebene wie Ich, Firma, Verbindungen). · :231 · Kommentar Johannes 22.10.
HUB-D02 Darunter Ordnerschema und Vorlagen. · :239 · Kommentar Johannes 22.10.
HUB-D03 Projektordner wählen am Google-Drive-Dienst. · :321
HUB-D04 Werte der Kachel (z. B. „4 von 7“, „Einrichtung im geteilten Drive“) nur aus der realen Anbindung; sonst leer. · :236, :335 · Johannes 23.10., N40

## HUB-S · Untertitel der Dienst-Kacheln (Verbindungen)
HUB-S01 Untertitel = Feld use je Dienst (alfa-bausteine.js:36–:44) = Kategorie dessen, was ALFA vom Dienst liest; erlaubt nach Johannes 23.10. (entscheidungen.md:446). Zeilen der Bereiche (zuletzt, Takt) = Status nur aus echtem Abgleich, sonst „Noch nicht abgeglichen“.
HUB-S02 Gegen offizielle API zu prüfen (Code, beim Anbinden): Google Mail/Dateien/Kalender/Kontakte, ClickUp Aufgaben, Clockodo Zeiten, sevDesk Belege, DHL Sendungen, Airtable Projekte (Airtable liefert Bases/Tabellen; „Projekte“ ist die ALFA-Nutzung). Design hat nicht an der API-Doku geprüft.
HUB-S03 Happa Happa „Speiseplan“ ist belegt: Kantinen-Speiseplan über die Konkaapps-API (Bilder und Daten, Fotos ab ca. 11 Uhr; Johannes 17.09. und 20.10., SPEC.md:42, entscheidungen.md 20.10.; Inventur S4-dienste.md §9: Client KonkaappsClient.swift nur im Archiv, alfaos nur Katalogeintrag ServiceCatalog.swift:118 ohne Probe). Kategorie „Speiseplan“ bleibt. Offen an Code (Inventur ZITATE-TRIAGE H13): Client aus dem Archiv übernehmen.

## HUELLE · Ergänzungen (gilt in allen Bereichen)
HUELLE-H01 Hilfetext an Griff und Blob (Hover Intent): erscheint erst nach motion.duration.hintDwell 3000 ms, solange der Zeiger je 100 ms höchstens size.hintRadius 7 px (Luftlinie) wandert; sonst beginnt das Verweilen neu. Klick, Taste, Scrollen blenden sofort aus. Tastaturfokus (:focus-visible) zeigt sofort. Kein natives title an diesen zwei Stellen. Gilt in allen Bereichen. · ALFA Shell.dc.html (hintSetup, shell.hint) · Johannes 23.10. (entscheidungen.md:444); Werte: hoverIntent sensitivity 7, Abfrage 100 ms
HUELLE-F10 Blob-Punkt nur, wenn der Assistent im verdeckten Zustand geantwortet hat (Blob zu, Antwort noch nicht gesehen). Erlischt beim Öffnen des Assistenten. Nicht mehr für ungelesene Mail oder Abgleichfehler (Zahl am Eingang, Abgleich-Knopf zeigen das). Puls unverändert (motion.duration.pulse), offen. · ALFA Shell.dc.html:70, onMode(o, mode); ALFA Mail/Einstellungen shDot, Probe-Schalter assistantReply · Johannes 23.10.
HUELLE-F11 Assistent meldet sich im verdeckten Zustand auf der Vorderseite des Blobs (Blob in Ruhe). Form der Anzeige, Effekt und Verdrahtung werden später festgelegt; bis dahin gilt als einzige Anzeige der Blob-Punkt (HUELLE-F10). Code legt den Anschluss an (Ereignis „Assistent hat verdeckt geantwortet“ → Blob-Vorderseite), ohne eigene Anzeige zu erfinden. Offen bei Johannes: Anzeige, Effekt, Dauer, Puls. · ALFA Shell.dc.html:70 · Johannes 23.10.
HUELLE-F09 Augen in Ruhe: wie Master und Code halb geschlossen (lidRestScale 0,45, blobLidOffset 1,4); nichts zu ändern. Johannes fragte am 22.10. nach Strichen (entscheidungen.md:398): offen bei Johannes, kein Bauauftrag. · ALFA Shell.dc.html:248
HUELLE-K K.foldAt = Token size.foldAt 112 (TOKENBOGEN.json). · alfa-shell.js:4

## Farbe
FARBE-00 Keine Farbwelten. Farbbögen gesperrt, gehen nicht an Code. · Johannes 23.10. „Noch keine farbwelten“

## Vertrag nachgetragen 23.10.
components.json: AccountTitle, AccountDeck, AccountCard, EnvelopeStack, Envelope, SwitchGlass, AccountNameRow, AccountShowRow; AccountAlert + mail.account-alert.deck. TOKENBOGEN.json: motion.duration.switchIn 360, switchOut 760, hintDwell 3000; size.foldAt 112. Nicht nachgetragen (nicht freigegeben): motion.glide, motion.swap, state.*, axis.*.
