# Briefing für eine fremde Claude-Session · die fünf Editoren der ALFA-OS-App

Zweck: Wissenslücken schließen, bevor jemand Code oder App-Beschreibungen schreibt.
Stand: 17.10.2026. Verfasser: die Design-Session „ALFA OS Editoren Sketches 1610". Kein Wort hier stammt vom Nutzer selbst geschrieben; er hat nach eigener Aussage keine Dokumente verfasst. Die Entwürfe (HTML-Bögen) sind seine Messlatte, nicht dieses Papier.

## 0 · Lesehilfe

Jede Aussage trägt eine Stufe:

- **[C]** im Code gelesen (Swift im Altcode `MYKILOS Y/Sources`, oder JS `werkzeug.js`).
- **[B]** im Altentwurf gesehen (mykilOS-Blätter `paket/design/*.dc.html`). Das sind Entwürfe mit fest eingetragenen Beispieldaten, kein Nutzungsbeweis.
- **[A]** unser aktueller Entwurf (`ALFA *.dc.html` in diesem Projekt).
- **[T]** nur in Tests oder Kommentaren belegt, Implementierung nicht gelesen.
- **[?]** Ableitung oder offen. Nicht als Tatsache weitergeben.

Nutzerverhalten (was Leute real tun) ist **in keiner Quelle belegt**. Wer das braucht, muss den Nutzer fragen oder die Swift-Ansichten in `MykilosWidgets` lesen. Das habe ich nicht getan.

## 1 · Kontext

**Produkt:** eine native Swift-App (macOS, später iPad) für ein Küchen- und Möbelstudio. Der Nutzer heißt Johannes. Bereich „Editoren": Moodboard, Skizze/Atelier, Aufmaß, Konfigurator, Planvergleich (ELT).

**Zwei Designwelten, nicht vermischen:**
- **ALFA OS** (dieses Projekt, gültig): Shell, 3-Spalten-Bogenlayout, Tokens `--c-*` in `alfa-theme.css`, Spaltenbreiten je Bogen in `alfa-shell.js`. Der Nutzer gab uns als Maßstab nur, was er selbst auf den Bögen sah.
- **mykilOS** (Altcode, „Altcode: nicht alles gut, erklärt aber ein paar Dinge"): Papierkorn, Lucide-Icons, `--mkr-*`-Schatten. **Nur für Funktion und Datenmodell lesen, nichts Visuelles übernehmen.**

**Altcode-Pfade:**
- `mykilos-alles/MYKILOS Y/Sources/{MykilosKit, MykilosDesign, MykilosKalkulationsCore, MykilosApp}`. `MykilosApp` war leer. `MykilosWidgets` (Ansichten) habe ich nicht gelesen.
- `…/MYKILOS Y/Tests/MykilosWidgetsTests/*` [T].
- `…/MYKILOS Y/paket/design/` (HTML-Blätter) und `paket/design/ds/werkzeug.js`.
- `mykilos-alles/Neuer Ordner mit Objekten/mykilos-y-elt-editor/` mit `docs/`, `paket/`, `prototypes/` (u. a. `eltplan`, `fassungsvergleich`, `elt-editor`).

**Architekturregeln [C], aus Dateiköpfen:**
- `MykilosKit` ist **Foundation-only**: kein SwiftUI, kein GRDB, keine Hardware. Modelle sind rein, `Codable`, testbar.
- Koordinaten in Annotationen sind **normiert 0…1** (`BildPunkt`), unabhängig von der Foto-Auflösung. Maße kanonisch in **Metern** (Aufmaß) bzw. **mm** (Plan, Konfigurator, Werkzeugkasten).
- Quellbezüge sind **Referenzen, nie Kopien** (Konfigurator zieht Maße live aus Aufmaß/Artikel/Moodboard).
- Leitprinzip im Altcode: **nichts erfinden.** Wo keine Quelle ist, steht ein ehrlicher Leerzustand.

**Arbeitsregeln des Nutzers (wörtlich oder eng am Wortlaut):**
- Die HTML-Bögen sind die Messlatte.
- „Keine Stapelkarten, nutze andere UI-Blocks." **Befund (Code gelesen, `ALFA Moodboard` Z. 271–275, `ALFA Atelier` Z. 277–281, `ALFA Aufmass` Z. 244–248):** Alle drei tragen noch die Methoden `stackCards`/`stackCards0`. `stackCards` gibt aber nur die vordere Karte zurück (top 0, transparent, ohne Schatten) und setzt Reiter darüber. Sichtbar ist also ein Blatt mit Reitern, kein Stapel. `ALFA Planvergleich` nutzt kein `stackCards`, sondern `R.tabs` direkt. Ob Methodenname und Hover-Logik (`hoverCard`) bleiben sollen, ist nicht geklärt.
- Die Moodboard-Werkzeugleiste ist „die bislang am besten designte". Ihr **Layout** gilt kanonisch für alle Editoren (schwebende, ziehbare Palette, Griff, Doppelklick dockt an, 12-px-Radius, 28-px-Knöpfe). Die **Werkzeuge** bleiben je Editor eigen.
- Berichte kurz, mit Quellen. Keine Rückfragen, die sich aus den Quellen beantworten lassen.

## 2 · Gemeinsames Werkzeugfundament [C]

Quelle: `paket/design/ds/werkzeug.js`, in Swift gespiegelt in `MykilosDesign/MykWerkzeugkasten.swift`. Gilt laut Dateikopf für **Blattwerk, Aufmaß, Atelier, Konfigurator, Papers, Werkzeuge**. **Moodboard steht nicht in dieser Liste** (Dateikopf `werkzeug.js`). Die Swift-Ansicht `WerkzeugModus` führt es seit 27.07.2026 trotzdem als dritten Modus [T✓, `WerkzeugAnsichtTests` Z. 1–1093]; siehe Abschnitt 11.

- **Regel im Code:** „Eine Zeichenfläche ohne Lineal, Unterlage und Ebenen ist unfertig."
- **Neun Stifte** (Reihenfolge verbindlich), je mit Erklärsatz: Stift (freie Linie, Pencil-fähig), Linie (rastet auf 10 mm), Fläche, Maß (Maßkette), Winkel (Schräge, Gehrung), Flucht (Fluchtpunkt setzen und ziehen), Text (immer waagerecht), Bild (aus der Bibliothek), Radierer (nimmt nur die oberste Ebene). 3×3-Gehäuse, Taste 58 px, Ecken außen 12, innen 4.
- **Fünf Ansichtsschalter:** Lineale (an), Millimeterraster (an), Perspektivraster (aus), Maßlinien (an), Schriftfeld (an).
- **Fünf Ebenen** mit Quelle und Deckstufe 1–6: Bestand (Drive · Grundriss), Aufmaß (Aufmaß A-01), Entwurf (lokal), Bemaßung (aus dem Aufmaß), Notizen (Assistent · Chronik).
- **Fünf Unterlagen** mit Deckkraft (Vorgabe 55 %): Keine, Grundriss, Aufmaßblatt, Perspektivpause, Werkplan. Die Unterlage ist nie Teil der Fassung.
- **Lineale** in mm: Strich alle 50, Zahl alle 200, Rinne 22 px, Positionen in **Prozent**. Raster in 100-mm-Feldern, folgt dem Zoom. Perspektivraster: ein Fluchtpunkt, 9 Strahlen von −46° bis +46°.
- **ELT-Editor-Prototyp [B]** führt statt der neun Universaltasten eine **disziplinbelegte** Palette (Dose, Schalter, Leuchte …). Der Kasten ist also je Disziplin umbelegbar.
- **Widerspruch zwischen Quellen:** Der Kasten nennt neun Stifte. Skizzenbuch-Blatt [B] zeigt 8 andere Werkzeuge (Stift, Bleistift, Pinsel, Radierer, Linie, Rechteck, Text, Lineal). Zeichenfläche-Blatt [B] zeigt 6 (Maß, Symbol, Merkpunkt, Kalibrieren, Hand, Perspektive). Es gibt **keine** einheitliche Werkzeugliste.

## 3 · Moodboard

**Unser Entwurf [A]** `ALFA Moodboard.dc.html`:
- A3-Seiten-Editor mit Seiten, **Musterseite A**, Raster und Fangen, Hilfslinien, Zoom (Einpassen, 50 %, 100 %, Zoom-Werkzeug), Hand.
- Bibliothek links (Bilder, Logos u. a.), Objektkarten rechts. Objekte: Text, Bild, Fläche. Bildrahmen mit Füllung, Crop und **Freistellen mit Toleranz**. Palette aus Bild, Vorlagen (`TPLS`), Ausrichten/Verteilen, Drehen, Spiegeln, Reihenfolge, Sperren.
- Palette: Auswahl (V), Text (T), Bildrahmen (F), Fläche (R), Hand (H), Zoom (Z), Raster, Fangen. Undo/Redo 60 Schritte (⌘Z, ⇧⌘Z).
- **Herkunft dieser Idee:** der Nutzer wünschte einen InDesign-/Canva-artigen Seiteneditor. Sie stammt **nicht** aus dem Altentwurf.

**Altentwurf [B]** `mykilOS Skizzenbuch.dc.html`, Reiter „Moodboard":
- Freies Brett auf einer Vollfläche, **keine Spalten und keine Seiten**. Leicht gedrehte Karten (−1,5° bis +1,4°): Bilder, Farbflächen, Notiz.
- Aktion „Palette aus 6 Bildern gezogen". Rechts „Auswahl · Bild" (Breite, Drehung, Quelle) und „Verknüpft" mit Katalogartikeln (Front Linoleum 4175, Griffleiste GR-118) mit „In Warenkorb". Oben „Als PDF" und „Freigabe senden". Unten eine Ablage mit fünf Kacheln.
- `mykilOS Papers.dc.html` [B] ist die Materialbibliothek: Serien links, Bogen als Raster/Liste/Bemusterungstisch, rechts Detail mit „Passt zu", „Verwendet in", Bestand. Tasten „Auf den Tisch", „Aufs Modeblatt", „Nachbestellen".

**Code [C]/[T]:**
- Tests zur Bühne (`MykModeblattBuehneTests`, ganz gelesen, 103 Z.) [T✓]: Elemente liegen als Anteile 0–1. Rastung in 1/40-Schritten (`eingerastet(0.23) == 0.225`). Mindestbreite 0,05, Mindesthöhe 0,04, Höhe bleibt `nil`, wenn sie nie gesetzt wurde.
- Sechs feste Material-Slots (`MaterialSlot.standardSatz()`) [T✓: `WerkzeugAnsichtTests` „Moodboard darf nicht belegt starten", `slots.count == 6`].
- Vorlagen [T✓, `VorlagenAnsichtTests` ganz, 388 Z.]: Das **Blatt** `mykilOS Vorlagen.dc.html` führt 18 Soll-Vorlagen in fünf Familien (Zeichnung 7, Moodboard 2, Beleg 6, Korrespondenz 2, Präsentation 1). **Tatsächlich vorhanden** sind 10: 6 Belegdateien (Angebot, Auftragsbestätigung, Lieferschein, Rechnung, Gutschrift, Mahnung) und 4 Codevorlagen (u. a. Aktenvermerk). Kopfzeile: „6 von 18 aus dem Blatt · 4 nur im Code · 12 fehlen". Zeichnung, Moodboard und Präsentation sind leer. Das Zeichnungs-Leerfeld nennt DWG und .vwx als Grund. Die Vorlagen-Ansicht ist Widgetklasse W15 „Registratur" mit Charakter C09 „Rissblatt".

**Offen [?]:**
- Soll Moodboard ein **freies Brett** (Altentwurf) oder eine **Seitenmontage** (unser Entwurf) sein, oder beides als Ansichten?
- Wie hängt es mit Papers (Material), Katalog (Artikel) und Konfigurator („Quelle Moodboard") zusammen?
- Nicht gelesen: `MykModeblattBildwerk.swift`, `MykModeblattSeiten.swift`, `VorlagenAnsichtTests` im Detail.

## 4 · Skizze / Atelier

**Unser Entwurf [A]** `ALFA Atelier.dc.html`:
- Szenen (`SCN`), Ansicht Skizze / Beide / Render. Werkzeuge: Stift, Linie, Rechteck, Radierer, Fluchtlinien, Raster. Kontextleiste: Perspektive (Ein-, Zwei-, Drei-Punkt, Axo), Material, Auflösung.
- Rechts: **Pipeline** (Stufen mit Fortschritt, überspringbar), **Parameter** (Stil, Licht, Auflösung, Material, Perspektive), **Fassungen** (Renderstände v1…).
- **Herkunft der Render-Pipeline:** Wunsch des Nutzers plus Websuche (Veras, Rendair u. a.). Im Altcode **Kit [C]**: `RenderCheckout`, `PromptKompilierer`, `PromptVorlagen`. Inhalt nicht gelesen.

**Datenmodell [C]** `Domain/Skizze/*`:
- Dokument = **Foto** (mit EXIF) + Filter (keiner, Schwarz-Weiß, abgedunkelt) + **Layer** + **Material-Slots** + **Maß-Anker**.
- Formen: Polylinie (offen/geschlossen), Rechteck, Freihand. Strich: Farbe schwarz/weiß/Slot, Dicke dünn/mittel/dick (1,5/3/5 pt). Objekte tragen Bezeichnung und optional **Füll-Slot** (nur bei geschlossenen Formen wirksam). Die Bezeichnung fließt in den Render-Prompt.
- **Layerarten:** Bestand, Neu, Entfernen, **Notiz (wird nie exportiert)**. Layer: sichtbar, gesperrt, Deckkraft.
- Substrat-Check mit Ampel: mind. ein gefülltes Volumen, jeder benutzte Slot hat ein Material, keine Notiz-Layer im Export.
- **Undo** = `Verlaufsstapel`, Tiefe 500, ein Eintrag je abgeschlossener Geste. Foto, Filter, Viewport sind nicht Teil des Undo.
- **Maß-Anker:** bemaßte Referenzstrecke im Bild („Türblatt 2010 mm") leitet den Maßstab ab. Im Kopf „Stretch — Modell heute, Voll-UI später".
- `PerspektivRaster.swift`, `PlatziertesBild.swift`: vorhanden, nicht gelesen.

**Altentwurf [B]:**
- `mykilOS Atelier.dc.html`: Fassungen links (Ordner, Texturen, Proben), Mitte Skizze/Render/Gegenüberstellung. **Zeichengeräte** (Reißschiene, Zirkel, Geodreieck, Schraffurkamm) lassen sich über das Blatt ziehen, Alt/Shift dreht oder weitet. Zehn Tuschfarben, fünf Ebenen (Unterlage, Konstruktion, Zeichnung, Ton, Notiz) mit Auge. Fluchtpunkte VP1, VP2, optional VP3 (Zenit oder Nadir), Horizont, Messpunkte, Standlinie.
- Rechts: Aquarellkasten (Mischen, Notation), Pinselbrett, **Anweisung** mit Bausteinen, Stimmungsproben, Herkunft (Aufmaß, Modeblatt, Katalog, Drive), Verlauf v1–v3. Aktion „Render rechnen". Gegenüberstellung „Skizze v1" gegen „Render v3" mit Stempel „Freigegeben". Fußsatz: „Skizze bleibt Skizze · der Render ist eine eigene Fassung".
- `mykilOS Skizzenbuch.dc.html` [B]: Skizze liegt auf einem **Aufmaß-Foto** als Referenzebene („Referenzebene 32 %") mit Maßlinien. Acht Werkzeuge links, Strichstärken-Regler, rechts Ebenen (Möbel, Maße, Material, Foto), unten Maß, Fläche, Zoom, Blattleiste.
- `Perspektive.dc.html`, `Perspektivraster.dc.html`, `Kreativwerkzeuge.dc.html`: vorhanden, **nicht gelesen**.

**Offen [?]:** Welche der Geräte und Pinsel sind echtes Ziel und welche Dekor? Wie wird der Render real erzeugt (externe Bild-KI, lokal)? Was ist im Nutzerfluss Pflicht (Foto, Skizze, Slots, Prompt, Render, Fassung, Freigabe)?

## 5 · Aufmaß

**Unser Entwurf [A]** `ALFA Aufmass.dc.html`: Räume (Flur, Garderobennische, Abstellraum, Küche), Ansicht Grundriss oder Wand, Wände, Öffnungen (Tür, Fenster, Durchgang), Maßketten, Raster 1 m, Sperren; rechts Raum, Wände, Öffnungen; Aktionen „Plan als PDF", „Stückliste ableiten". **Es ist ein Raummodell aus Wänden, kein Foto-Aufmaß.**

**Datenmodell [C]** `Domain/Aufmass*.swift`:
- **Foto-Aufmaß ist der Kern.** `Aufmass` = Projektnummer, Titel, **Positionen**, **Fotos**, **Layer**, **Symbole**, **Pins**.
- `AufmassPosition`: Bezeichnung, Meter, **Quelle** (manuell, laser, auto), optional Foto + `BildLinie` (normiert), Layer, Linienstil (dünn, normal, gestrichelt, punktiert).
- **Kalibrierung** `GrundrissKalibrierung`: aus einer Referenzstrecke (isotrop) oder getrennt in X und Y (verzerrter Plan). Aus Pixeln allein entsteht keine echte Länge.
- **Layer:** Name, Farbe (MykColor-Rolle oder Hex, 10er-Palette), Sichtbarkeit, Schriftgröße. Standard: Gesamtmaße, Wasser/Installation, Details. Löschen ist verlustfrei (Maße werden layerlos und bleiben sichtbar).
- **Installationssymbole** (11 Typen): Wasser, Abwasser, Gas, Strom, Steckdose, Netzwerk, Heizung, Lüftung, Lautsprecher, Gerät, Anschluss. Dazu Pins (Notizen im Bild).
- **Viewport:** Zoom 1–12×, Zoom unter dem Cursor, Pan, Einpassen.
- **Perspektive** `AufmassPerspektive`: Fluchtpunkt aus 2–5 nachgezeichneten Linien (Kleinste-Quadrate), Horizont, Leitstrahl, **magnetisches Lineal** (rastet innerhalb 7°).
- Einheiten mm/cm/m; Maßzahl ohne Tausenderpunkt („2178 mm", Nutzerwunsch).
- Nicht gelesen: `AufmassAutoBemassung`, `AufmassDokument`, `AufmassDateiname`.

**Altentwurf [B]** `mykilOS Aufmass.dc.html`:
- Blätter A-01 bis A-04 („Küche Nord", „Bad" …) mit Stand wie „freigegeben · 4 Maße" oder „offen · Schräge fehlt". Ansichten Plan, Maßliste, Fotos.
- Acht Maße (M-01…M-08) mit **Toleranz** (± 3, ± 6, ± 12). Weicht ein Maß ab, wird es rot, und **„Blatt freigeben" ist gesperrt** („Erst Abweichung klären"). Im Blatt ist die Freigabe selbst leer (`() => {}`).
- **Laser-Panel** (Leica DISTO D110): Strecke, Fläche, Dauermessung, Funkauge. Ohne Funk bleibt die Anzeige leer, Eintrag von Hand.
- Räume mit Flächensumme, Passpunkte, Lineal in mm, Wege zu Konfigurator, Atelier, Drive.

**Gegenstück [B]** Zeichenfläche-Blatt: Foto-Aufmaß mit Werkzeugen Maß, Symbol, Merkpunkt, Kalibrieren, Hand, Perspektive; **Hinweis „Nicht kalibriert — Maße stehen, gelten aber noch nicht"**; Ebenen mit Summe und Anzahl je Ebene.

**Offen [?]:** Ist das Aufmaß heute eher Foto oder Raummodell? Beide Welten sind im Altcode vorhanden. Was ist die Quelle der Wahrheit für den Konfigurator (`RaumBezug.aufmass`)? Was passiert mit der Freigabe real?

## 6 · Konfigurator

**Datenmodell [C]** `Domain/Konfigurator/*`:
- **Ein Entwurf, drei Projektionen:** Schätzung (live, intern), **Kunden-Set** („VORPLANUNG"), **Gewerk-Anfrage** („VORABZUG", Tischler/Stein). Status: vorplanung, vorabzug, finalisiert. Stempeltexte wie auf den echten Blättern.
- **Grammatik = Korpus-Stückliste:** Zone → Segment (Breite) → Fächer (unten→oben) mit Ausstattung. Zone: Typ (Zeile, Insel, Hochschrankwand, Wandzeile …), Tiefe, Korpushöhe, Sockel, Höhenbänder, optional Überstand.
- **Ausstattung:** Tür mit Fachböden, Schubkästen (Anzahl, Material Legrabox oder Holz massiv), offenes Regal, Fachböden, Blende, **Gerät**, Spülbecken, Müll-Auszug, leer. Gerätekategorien: Backofen, Kochfeld, Dunstabzug, Geschirrspüler, Kühl-/Gefrierschrank, Mikrowelle, Wärmeschublade, Kaffeevollautomat, Weinschrank, sonstiges.
- **Raumbezug** (Referenz, nie Kopie): Aufmaß, Skizze, Kundenfoto, freie Maße, keiner. Optionale Position der Zone im Raum (mm, Drehung); ohne Position schweigen die Regeln ehrlich.
- **Domänenregeln (im Code zitiert):** Die **Front** ist der dominante Preistreiber. Frontauszug = Schubkasten, das **Material** treibt den Preis. Die Arbeitsplatte ist eine eigene Ebene, nie Teil des Korpus. Geräte-Nische (Geschirrspüler) = eigener Korpus mit Front. Wandzeilen-Breite folgt der Zeile darunter. Blenden sind preislich vernachlässigbar. Geräte kommen von MYKILOS und gehören nicht in die Tischler-Preise, aber als Einbaukontext aufs Blatt. **Preise immer live aus dem Katalog**, nie im Entwurf gespeichert (`ArtikelRef`).
- **Regelwerk** (`KonfigRegeln`): sanfte Führung, nie Blockade. Regeln u. a. Geschirrspüler neben Spüle, Müll nahe Spüle, Wärmeschublade unter Backofen. Maße: Durchgang mind. 1000 mm (hart 850), Nischenhöhe 560–600, Arbeitshöhe 850–950. Jede Regel trägt `belegt` oder `annahme`. **Annahmen muss Johannes bestätigen.**
- **Archetypen** („nie bei null anfangen"), aus drei echten Akten (Rehder 2025_016, Heinz HH_25015, Neuhaus 24021): Hochschrankwand mit Geräteblock (4 Segmente 600/600/759/1200), Spülenzeile (600/600/600/600/450), Kochzeile, Insel mit Tresen, kompakte Insel, Wandzeile. „Zone als Archetyp sichern" ist bewusst nicht gebaut.
- **Aggregat** `KonfigEntwurf`: Projektnummer (ohne Vorgang kein Entwurf), Variantenname („Entwurf A", „B" …, ein Klick klont), Status, Raumbezug, Materialdeklaration, Zonen, Notizen, Zeitfenster, Kompilate. Breitenraster 300/400/450/600/800/1200 ist **Vorschlag, kein Käfig**.
- **Quellen-Stand:** Ein kompiliertes Blatt friert Aufmaß-, Artikelpreis- und Moodboard-Stand ein (`QuellenStand`). Der Entwurf bleibt lebendig, Drift wird sichtbar gemacht, nie still ignoriert. Kompilate: anfrageTischler, anfrageStein, kundenSet.
- **Gewerk-Scope** (`GewerkScope`, aus einer echten Mail zitiert): Tischler bekommt Korpusse, Fronten, Sockel, Schubkästen. Steinmetz bekommt die Arbeitsplatte (beim Tischler nur Kontextzeile). MYKILOS liefert Geräte, Spüle, Armatur, Griffe.
- Weitere Dateien, nicht gelesen: `KonfigAnfrageText`, `KonfigKuerzel`, `KonfigMaterial`, `KonfigRenderPrompt`. `KonfigModell` ist jetzt ganz gelesen.

**Altentwurf [B]** `mykilOS Konfigurator.dc.html` (nur Zeilen 381–680 gelesen):
- **Modi:** Ansicht, Stückliste, Zuschnitt, Schauschnitt (Isometrie 30°), Modeblatt.
- **Blattvorlagen:** A0 Layout, A1 Entwurf, A2 Layout, A3 Grundriss, Elektro und Sanitär, Darstellungen. Zeichenart: Z1 Rissbild, Z2 Kartonbild, Z3 Handriss. Optionen: Schriftfeld, Maßkette, Rahmen.
- Pro Korpus: Breite (Regler), Front, Oberfläche (5), **Griff** (Griffmulde, Griffleiste, Bügelgriff, Push-to-open), **Schattenfuge** (2, 3, 4, 6, 8 mm), Ausbau (Vollauszug, Besteckeinsatz, Innenschublade, Beleuchtung, Soft-Close).
- Prüfzeilen: über 900 mm Mittelwand, Gerätemaß Hochschrank, Summe gegen Wandlänge (4180 mm).
- **Preislogik im Blatt ist ein Dummy** (Fläche × 1180 + 240 …). Nicht übernehmen.
- **Abweichung vom Kit:** Das Blatt führt flache „Korpusse" mit Breite. Das Kit führt Zone → Segment → Fach. Es gibt kein einziges verbindliches Konfigurator-Modell.

**Für unser ALFA-Projekt: noch kein Entwurf [A].** Beschrieben ist nur der Bedarf.

**Offen [?]:** Welche Ansicht ist die Hauptarbeitsfläche (Zonenbaum, Frontansicht, Grundriss)? Welche Regeln hat Johannes bestätigt? Wie sieht der Weg Kunden-Set → Vorabzug → Final aus?

## 7 · Planvergleich / ELT

**Status:** Konzept (MD, nach deiner Regel nur als Aussage gelesen) und **zwei Dummy-Prototypen** [B]. **Nicht in Swift, nichts gerechnet** („Mockup · nichts gerechnet", „Dummy · Fundstellen hinterlegt"). Im Kit [C] gibt es nur `PlanDokument` (siehe unten).

**Zwei verschiedene Dinge, laut Konzept** (`docs/concepts/elt-plan-editor.md` §0, Zeilen 1–200 gelesen):
- **Fassungsvergleich:** dasselbe Blatt, zwei Stände. Frage: „Was hat sich geändert?" Ergebnis: Änderungsliste. Arten: neu, weg, verschoben, Maß, Text.
- **Gewerkeüberlagerung:** verschiedene Blätter, gleicher Ort (ELT über Bau-Grundriss, Kücheneinbau über ELT). Frage: „Passt das zusammen?" Muss erst zur Deckung gebracht werden (Blatt-Ursprung). Ergebnis: Konfliktliste. Arten: Kollision, zu nah, fehlt, unerreichbar.
- Beide teilen Schieber und Fundstellen-Markierung, die Prüfung dahinter ist verschieden.

**Prototyp „Planrevisionen"** [B] `prototypes/fassungsvergleich/index.html` (ganz gelesen):
- Kopf „Villa Blankenese · P-2026-014 · A-04 Grundriss OG · 1:20 · DIN A3 quer", Paar „Fassung 2 → 3". Drei Spalten 212 px / Mitte / 316 px.
- **Links:** Fassungsstapel (Fassung 3 freigegeben, Rolle B; Fassung 2 im Umlauf, Rolle A; Fassung 1 Entwurf), darunter Zählung („5 Unterschiede", aufgeschlüsselt nach Art).
- **Mitte:** der Plan mit **Schieber** (Griff ◂▸), nummerierten Marken und Höfen. Modi **Schieber, Überlagern, nur Änderungen**. Knöpfe „ganz 2", „Mitte", „ganz 3", „vorige", „nächste". Bedienung: ziehen, ← →, Tab springt von Fund zu Fund.
- **Rechts:** Änderungsliste. Zeile: Nr., Was, Art-Pille, „von → nach", „Bauteil · Grund · Kürzel". Filter nach Art mit Zahl. Unten Stempel „Freigegeben 30.07.2026 · JO", Knöpfe „Als Liste ausgeben", „In die Akte".
- Fünf hinterlegte Funde, Beispiele: Nische 1.240 → 1.480 mm (Grund „Aufmaß vom 29.07."), Oberschrank ergänzt („Wunsch Bauherr, Telefonat 28.07."), Trennwand entfernt, Außenmaß 3.240 → 3.252.
- Wahl koppelt Plan und Liste (Marke anfassen hebt die Zeile).

**Prototyp „ELT-Plan"** [B] `prototypes/eltplan/index.html` (Z. 21–190): Gewerkeüberlagerung. Titel „ELT-Plan", „Junge/Schultzendorff · 2026_017 · ELT_EG · 1:50 · DIN A1 · Fassung 4". Links Ebenen und „Fremdgewerk: Kücheneinbau KUE_01 (1:20, über Blatt-Ursprung zur Deckung gebracht)". Mitte Schieber „ELT_EG · Fassung 4" gegen „KUE_01 · Fassung 2". Rechts **Konflikte** („jeder Konflikt nennt zwei Objekte, nicht eines"), „Als Liste ausgeben", „An Elektriker". ELT-Symbole: Dose, Schalter, Leuchte, gestrichelte Leitungen, Kreis „TGA_EL_Neu · Kreis 3 · 16 A".

**Prototyp „ELT-Editor"** [B] `prototypes/elt-editor/index.html` (Z. 1–300 von 925): die echte **ELT-Zeichenfläche** (Bearbeiten), getrennt vom Vergleich. Links: Werkzeugkasten mit **ELT-Belegung statt der neun Universaltasten** (laut Dateikopf: „ELT braucht andere Objekte"), Fang-Achse, Stromkreis (A…), Höhenkote OKFF, ausgewähltes Objekt, Lineale und Raster. Mitte: Fläche mit Rückseite („Eselsohr") als **Schaltkreis-Schema** (ein Schalter je Stromkreis-Buchstabe, keine Normnotation, keine Lastberechnung). Rechts: Blattvorschau A1 quer mit Plankopf, Ebenen, **Prüfregeln-Ampel in Kelvin**, Katalog mit Artikeln und Warenkorb. Symbolkatalog `ds/elektrosymbole.js` mit 41 Zeichen (Dateiname gesehen, Inhalt nicht gelesen).

**Konzept, nur als Aussage der MD** (Zeilen 1–200 von 327):
- **Blatt:** Code (GRD_EG, ELT_OG, KUE_01 …), Disziplin (bau, elt, hz, sa, kueche, bebauung), Maßstab, Format, Geschoss, Ursprung. Eine Fläche, ein Werkzeugkasten, ein Modell; die Disziplin ändert nur Ebenen, Werkzeuge und Regeln.
- **Modell:** Fassung (Stand: entwurf, imUmlauf, freigegeben, ueberholt), Geometrie hängt an der **Fassung**, nicht am Blatt. Ein **Fund ist ein Datensatz** (quittierbar, exportierbar), keine bloße Markierung. Vergleichslauf mit Schwelle und Ausrichtung.
- **Ebenen:** Bestand (gesperrt), Raster, Gewerk, Bemaßung, Beschriftung, Notiz, Fremdgewerk (nur lesend).
- **ELT-Prüfregeln** deterministisch, vor jeder KI: Steckdose ohne Kreis, Kreis ohne Absicherung, Feuchtraum ohne FI, Leuchte ohne Schalter, Überlast, fehlende Höhenkote, Objekt außerhalb Raum.
- **Ingest:** DXF ist kanonisch. Symbolidentität kommt von der **Ebene** plus Geometrie-Fingerabdruck, nicht vom Blocknamen.
- **Drei Vergleichsstufen** (`planrevisionen-vergleich.md`): 1 Bild gegen Bild (zuerst empfohlen, funktioniert mit fremden PDFs), 2 Vektor gegen Vektor (Textänderungen), 3 Objekt gegen Objekt (DXF, „Steckdose verschoben"). Stufe 3 fällt mit dem DXF-Import an.
- **Ausdrücklich ungelöst:** ein Foto eines gedruckten Plans mit Rotstift-Notizen (WRA51-Vorabzug) ist ein eigenes Vorhaben.
- **Offene Punkte laut MD:** Woher kommen die Fassungen (Drive-Versionen, Akte, eigene Tabelle)? Ausrichtung über Plankopf, Passmarken oder Rahmen? Schwelle ab wann ein Fund gilt? Ausgabeformat der Änderungsliste (PDF/CSV)?
- **Anbindung im Altcode:** `MykFassung.swift`, `MykFassungsliste.swift` gebaut. Charaktere C06 Blattstapel, C12 Stempel, C14 Eselsohr.

**Kit [C]** `PlanDokument`: freies Zeichenmodell in Plan-mm (3D-Punkte). Elemente: Linie, Polylinie, Rechteck, Text, Bemaßung. Layer (Gesamtmaße, Wasser/Installation, Details). Projektion Elevation oder Isometrie, jederzeit umschaltbar. Korpusse sind später eine **Interpretation** der Geometrie, nicht ihr Kern. `PlanProjektion`, `PlanTransform`: nicht gelesen.

**Achtung, Namensfalle:** `docs/PLAN_ETAGENVERGLEICH_2026-07-29.md` handelt **nicht** von Plänen. Es vergleicht die Altapp „X" mit der neuen App „Y" nach Codeschichten (Kit, Services, Design, Präsentation) und enthält einen Feature-Baum der App. Nicht als Planvergleich zitieren.

**Nicht gelesen:** `elt-plan-editor.md` ab Zeile 200 (Fassungsausrichtung, Gewerke §6), `elt-editor/index.html` ab Zeile 300, `elt-modul.md`, `PLANWESEN_VORLAGEN.md`, `paket/design/mykilOS Planwerk.dc.html`, `ds/elektrosymbole.js`, die ELT-Lastenhefte, `colorreader-widget.md`.

**Für unser ALFA-Projekt [A]** `ALFA Planvergleich.dc.html` (391 Z., ganz gelesen; Stilattribute und Zeilen 14/59/82 beim Lesen auf 420 Zeichen gekürzt):
- Bogen „Planvergleich", Gruppe „Kreativ" in der Shell. Listenspalte: Vergleiche, gruppiert nach Abschnitt, mit Zähler offener Funde; Fuß „Vergleich anlegen" (Menü: „Fassung gegen Fassung", „Gewerk gegen Gewerk", beide nur Toast „Anlegen folgt · Beispieldaten").
- Mitte: ein SVG-Plan mit Wänden, Tür, Fenster, ELT-Symbolen (Dose, Schalter, Leuchte, Leitung, Kreis) und Küchenkästen. Drei Ansichten (Tasten 1/2/3): **Schieber** (Griff, Schnitt bei `cut` 0,06–0,94), **Überlagern** (Revision: schwarz neu, grau gestrichelt alt, Signalfarbe für „weg"; Gewerk: schwarz ELT, grau Küche), **Änderungen** (nur Geändertes). Nummerierte Fundmarken im Plan, Tab springt zum nächsten Fund, Zoom 0,5–4, Hand/Auswahl, Raster 1 m, Marken an/aus. Schwebende Palette (V, H, Zoom, Einpassen, Raster, Fundmarken) wie im Moodboard, ziehbar, Doppelklick dockt an, Position in `localStorage` („alfa.planvergleich.pal").
- Rechts: Reiter **Funde** (Zeile: Nr., Titel, Detail, Art, Status offen/geklärt; geöffnet: „Grund · …", „Als geklärt"/„Wieder öffnen", „Nächster") und **Ebenen** (Wände und Öffnungen, Elektro, Küche, Beschriftung, je mit Auge). Fuß: „Als Liste ausgeben", „An Elektriker" (beides nur Toast).
- Beispieldaten fest im Code: `r34` ELT_EG F3→F4 (5 Funde: neu D4, verschoben L2, weg S1, Maß D3 1050→1150, Text Kreis 3→4), `r23` F2→F3 (3 Funde), `g1` ELT_EG × KUE_01 (3 Konflikte: Nähe D1↔WA 500 mm, Versatz L2↔Insel 250 mm, Überdeckung D3↔GS). Planmaß 6200 × 4400 mm. Fundarten: neu, verschoben, weg, Maß, Text; bei Gewerk Nähe, Versatz, Überdeckung.
- **Nicht umgesetzt:** echter Dateivergleich, DXF/PDF-Import, Ausrichtung, Schwelle, Stufen 1–3 der Konzeptschrift, Foto-Plan mit Rotstift, Export. Alles ist Attrappe mit Toast.
- **Abweichung zum Konzept:** Das Konzept zählt die Vergleichsarten Schieber, Überlagern, nur Änderungen. Der Entwurf hat sie 1:1. Eine Änderungsliste mit „Art und Grund" ist umgesetzt. Die Konzeptfrage „Quelle der Fassungen" bleibt offen.
- `P.pin` (Fundmarken-Symbol) steht im Code; ob die Zeichnung im Browser sauber lädt, wurde in diesem Briefing nicht geprüft.

**Offen [?]:** Wollen wir beide Fälle (Fassung und Gewerk) in einem Bogen oder getrennt? Liegt die Wahrheit im Plan oder in der Fund-Liste? Wer bekommt die Liste (Elektriker, Werkstatt)?

## 8 · Querschnitt

- **Verknüpfungen [B]/[C]:** Aufmaß → Konfigurator (Korpusbreiten), Aufmaß → Atelier (Grundriss als Zeichenebene), Konfigurator ← Moodboard/Papers (Material), Konfigurator ← Katalog (Artikel, Preise live), alle → Drive (Ablage als Fassung), Atelier-Render → Modeblatt.
- **Gemeinsame Grundbegriffe:** Fassung (nummerierter Stand, Ablage über Drive), Layer mit Auge, Quelle an jeder Zahl (LAS/MAN/AUT im Aufmaß), Stempel für Reifegrad, „Blatt".
- **Datenehrlichkeit:** Jede Zahl trägt ihre Herkunft. Eine fehlende Quelle zeigt „—", keine erfundene Herkunft.

## 9 · Was die fremde Session herausfinden soll

1. **Nutzerfluss je Editor** aus den Swift-Ansichten in `MykilosWidgets` und aus dem Nutzer, nicht aus Blättern: Was tut er in welcher Reihenfolge? Was ist Pflicht, was Zierde?
2. **Ein verbindliches Modell** je Editor (siehe „Widerspruch" bei Werkzeugliste, Konfigurator-Modell, Aufmaß Foto/Raum).
3. **Welche Werkzeuge** pro Editor wirklich gewollt sind, mit Quelle. Die Wunschliste aus einer Websuche (Bluebeam, Procreate, Concepts, Photo Measures …) ist **Ableitung** und keine Anforderung.
4. **Konfigurator und Planvergleich:** je ein eigener Nutzerflussentwurf, bevor Oberfläche gebaut wird.
5. **Modularisierung:** Welche Teile sind gemeinsamer Baustein (Ebenen, Kalibrierung, Viewport, Verlaufsstapel, Layer, Quelle/Herkunft), welche editorspezifisch?
6. **Aufträge** nur auf ausdrückliches Wort des Nutzers; Ergebnis kurz, mit Quellen, mit Stufe [C]/[B]/[A]/[T]/[?].

## 10 · Quellen (alle gelesen, sofern nicht „nicht gelesen")

- `MykilosKit/Domain/AufmassModell.swift`, `AufmassLayer.swift` (bis Z. 200), `AufmassViewport.swift`, `AufmassPerspektive.swift` (bis Z. 120), `PlanDokument.swift`, `Werkzeug.swift`
- `MykilosKit/Domain/Skizze/SkizzenModell.swift` (bis Z. 250), `SkizzenLayer.swift`, `Verlaufsstapel.swift`, `SkizzenMasse.swift`
- `MykilosKit/Domain/Konfigurator/KonfigModell.swift` (ganz), `KonfigRegeln.swift` (bis Z. 160), `KonfigArchetypen.swift` (bis Z. 120)
- `MykilosDesign/MykWerkzeugkasten.swift`, `Navigation/MykKontextpalette.swift`, `paket/design/ds/werkzeug.js`
- `paket/design/` mykilOS Blattwerk (Z. 1–400), Zeichenflaeche (Z. 1–400), Aufmass (ab Z. 380), Atelier (Z. 1–600, 1050–1380), Skizzenbuch (ganz), Papers (Z. 1–400), Konfigurator (Z. 381–680)
- `prototypes/fassungsvergleich/index.html` (378/378 Z.), `prototypes/eltplan/index.html` (Z. 21–190), `prototypes/elt-editor/index.html` (Z. 1–300)
- `docs/concepts/planrevisionen-vergleich.md` (ganz), `docs/concepts/elt-plan-editor.md` (Z. 1–200), `docs/PLAN_ETAGENVERGLEICH_2026-07-29.md` (ganz, handelt von X-gegen-Y-Code, nicht von Plänen)
- `KonfigModell.swift` jetzt ganz
- Tests ganz gelesen (alle Zeilen): `MykilosKitTests/` SkizzeModell (317), AufmassModell (76), AufmassLayer (257), AufmassPerspektive (168), AufmassViewport (71), AufmassDokument (56), AufmassFoto (53), AufmassAutoBemassung (83), AufmassDateiname (92), GrundrissKalibrierung (60), Werkzeug (65), WerkzeugWolke (199), MykModeblatt (308), KonfigModell (277), KonfigMaterialAtelierBruecke (46), KonfigRenderPrompt (50), KonfigAnfrageText (80), PlanProjektion (173), PlanTransform (94), PlatziertesBild (127), FluchtEinrasten (62), PerspektivRaster (131). `MykilosDesignTests/MykWerkzeugkasten` (422). `MykilosWidgetsTests/` MykModeblattBuehne (103), VorlagenAnsicht (388), WerkzeugAnsicht (1093), WerkzeugHand (90).
- Tests **nicht** gelesen: `MykilosDesignTests/` MykPerspektive, MykModeblattBildwerk, MykFluchtMatcher, Fassung u. a.; `MykilosKitTests/` Papers*, Bemusterung*; `MykilosWidgetsTests/` Papers*, EinstellungenPapersSchritt.
- Unsere Dateien: `ALFA Moodboard.dc.html`, `ALFA Atelier.dc.html`, `ALFA Aufmass.dc.html`, `ALFA Shell.dc.html`, `alfa-shell.js`, `alfa-theme.css`


## 11 · Nachtrag nach Volllesung der Tests (18.10.2026)

Alles hier [T✓] aus den oben unter 10 genannten Tests, sofern nicht anders markiert. Tests belegen **Sollverhalten im Code**, nicht Nutzung.

### 11.1 · Es gibt ein vereintes „Werkzeug" mit fünf Modi und einem Kasten
- `WerkzeugModus`: **Aufmaß · Skizze · Moodboard · Konfigurator · Plan** (Reihenfolge und Titel geprüft; Lucide-Zeichen ruler, pen-line, palette, box, map). Der zweite Modus heißt „Skizze", nicht „Atelier". Die drei alten Ansichten (`.aufmass`, `.atelier`, `.konfigurator`) laden den jeweiligen Modus; `.projektakte` ergibt keinen.
- Testkommentar zur Herkunft des Moodboard-Modus (27.07.2026), wörtlich: „Werkstatt soll einfach das Aufmaßtool, das Moodboard-Tool und das Zeichentool werden … Dann bau das doch einfach 3-fach." „Vier Modi war nie eine Regel, sondern ein Stand."
- **Ein Kasten für alle:** Stift, Unterlage und Ansichtsschalter bleiben beim Moduswechsel stehen. Jeder Modus nennt `sinnvolleStifte` (müssen im Kasten existieren).
- **Ein Zustand je Modus:** Der Ausfall einer Quelle verdeckt die andere nicht. Ohne Quelle ist jeder Modus leer, außer Moodboard (Slots stehen ab Werk, unbelegt). Keine Beispieldaten beim Start. Ohne Maßstab: kein Blattmaß, kein Lineal, und ein Satz sagt warum (`ohneMassstabSatz`).
- **Millimeter gibt es nur mit Quelle:** Aufmaß über `GrundrissKalibrierung` (Foto), Skizze über `MassAnker` (2010 mm auf halber Breite → 4020 mm Blattbreite), Konfigurator aus Zonenmaß (600+400 breit, 720+80 hoch), Plan aus dem Einpassrahmen. Foto-Aufmaß und Skizze sind sonst **normiert 0…1**.
- Alle gezeichneten Punkte sind **Anteile 0…1**, nie Pixel (ausdrücklich „häufigster Fehler"). `z` im Lineal ist px je mm und folgt dem Zoom. Linealteilung: Strich alle 50 mm, Zahl alle 200 mm (nicht die 250/1000 des Aufmaßblatts).

### 11.2 · Aufmaß, wie der Code es meint
- **Foto-Aufmaß ist Hauptsache.** Testkommentar, Johannes mit zwei echten Blättern: „Wichtiger beim Aufmaß als die Maße als Liste sind die Aufmaß-Zeichnungen." Vorlage ist `Fliesen-Aufmass-A3.pdf`, ein Baustellenfoto mit farbigen Etiketten.
- Nur Maße **mit** `BildLinie` erscheinen auf der Fläche; reine Listenmaße haben keinen Ort. Beschriftung ist die echte Zahl (`4180 mm`, kein Tausenderpunkt). Auge je Ebene blendet wirklich aus.
- **Herkunft:** Mono-Kürzel an der Zahl, **LAS** Laser, **MAN** von Hand, **AUT** erkannt. Auf Fotos „keine Farbe, kein Halo" (Blatt `mykilOS Herkunft.dc.html`:216). Der Strich hat `licht == nil`.
- **Marken (Pins)**, drei Arten, je eine Ebene (z. B. „Zu prüfen"), je eine Vorgabefarbe als Hex: feststellung, frage, pruefen. Ohne Foto keine Marke. Marke ohne Text entsteht nicht. Marke und Maß-Stift schließen sich aus (Maßkette bricht beim Wechsel ab). Zweite Marke derselben Art nutzt dieselbe Ebene.
- **Freie Farbwahl mit Favoriten** (Johannes 29.07.: „komplett freie farbwahl für die Beschriftungen … mit kleiner Favoriten Speicherung"; „es sind ja Dokumente die ausgegeben werden, nicht App Design" → Kelvin-Regel gilt hier nicht). Start: die drei Blattfarben. Maximal 8 Favoriten. Gemerkte Farbe wandert nach vorn, keine Dubletten, ungültiges Hex wird ignoriert, Vorrat in `UserDefaults`. **Die Farbe hängt an der Marke, nicht an der Ebene.** Bleibt es bei der Vorgabe, trägt die Marke keine eigene (`farbe == nil`). Altes JSON ohne `farbe` liest unverändert.
- **Layer:** Standard „Gesamtmaße / Wasser/Installation / Details" (critical, cash, positive). Palette 10 Farben, höchstens 10 Layer, nächste freie Farbe, Name leer → „Layer N". Löschen macht Annotationen layerlos und sichtbar, nichts geht verloren. Teilsumme und Anzahl je Layer. Hex-Farbe und Schriftgröße je Layer (Standard 9). Treffer-Prüfung auf Symbole/Pins berücksichtigt das Bildseitenverhältnis.
- **Auto-Bemaßung:** aus Eckpunkten Breite/Höhe; Mindestspanne 0,15, Achstoleranz 0,05; leicht schräg gilt als waagerecht; `alleHauptkanten` entdoppelt nahe Parallelen.
- **Perspektive:** Fluchtpunkt aus 2+ Linien (auch außerhalb des Bildes, y<0 möglich), Cluster erkennt 1-, 2-Punkt und Vertikale im Unendlichen, `maxAnzahl` kappt. Horizont aus 2 Fluchtpunkten über die Bildbreite. Magnetisches Lineal rastet auf den Strahl; quer zum Strahl → kein Fang.
- **Bühne trägt das Seitenverhältnis des Fotos** (`WerkzeugFlaeche.eingepasst`). Altfehler: Foto lag mit `.fill` auf der ganzen Fläche, dieselbe Koordinate traf je Fenstergröße ein anderes Motiv. Pixelmaß kommt aus der Repräsentation, nicht aus `NSImage.size`.
- **Datei:** `<Projekt>_Aufmaß[_Bezeichnung]_<Datum[_HHmm]>.mykaufmass.json`. „Neues Aufmaß"/„Aufmaß"/leer als Bezeichnung entfallen. Pfadzeichen weg, Leerzeichen → Bindestrich, Projektnummer-Unterstrich bleibt. `formatVersion` ist gesetzt.
- Einheiten kanonisch **Meter**; mm ganzzahlig ohne Tausenderpunkt, m mit 2 Nachkommastellen und Komma. Laserwert kommt in Metern. Fläche „5,76 m²", Volumen „3,00 m³".
- Viewport: Zoom 1–12, unter dem Cursor festhaltend, Pan nur wenn gezoomt, Pan geklemmt, `fit()` setzt zurück.
- Kalibrierung isotrop (eine Referenz) oder anisotrop (X und Y getrennt), entartete Referenz → `nil`.

### 11.3 · Skizze / Atelier, wie der Code es meint
- **Die Hand erzeugt Objekte** (01.08.2026, Zitat im Test: „ALLES in der App ist Null, die app produziert rein GARNICHTS!"): Freihand-Stift (Stift 0) → ≥ 3 Punkte → Objekt in der obersten **offenen** Ebene. Dichtefilter: Punkte unter 0,3 % Weg werden verworfen. Zittern (< 3 Punkte) wird kein Objekt. Gesperrte Ebenen: Hand bleibt still. Radierer nimmt das oberste Objekt der obersten sichtbaren Ebene, **nur im Modus Skizze**, und ist über `Verlaufsstapel` rückgängig/wiederholbar.
- Strichart aus Form und Füllung: gefüllt = Slot gesetzt **und** Form geschlossen → `flaeche`; sonst `kontur`; Freihand → `zug`. Notiz-Ebene trägt Hinweislicht (3200 K) und wird nie exportiert.
- **Render-Kette:** Dokument → `VorlagenKompilierer` → Prompt aus Blöcken Szene, Geometrie, Materialien, Stil, Verbote (deterministisch, byte-gleich bei zwei Läufen) → `RenderRezept` → `RenderAuftrag` mit Versionen. **Genau ein Master** (alter Master fällt auf „freigegeben"). Heute nur Engine `fireflyManuell` verfügbar, `nb2`/`nbPro` nicht. Substrat-Ampel prüft mind. ein gefülltes Volumen und je benutztem Slot ein Material.
- Geometrie-Block (Golden): „Ultramarin markiertes Volumen = Hochschrankwand", „Entfernen: Alte Einbauküche", „Maß — Türblatt: 2.010 mm". Slot-Farben u. a. Ultramarin, Terracotta, Salbei. Referenzen heißen „Referenz 1/2 …", Reihenfolge übersteht Roundtrip.
- **Material kommt aus dem Konfigurator:** `KonfigPalette.alsMaterialReferenzen()` liefert dieselbe kuratierte Palette (stabile UUIDs je Palette-ID). Die alte Fake-Liste ist weg.
- `SkizzenGeometrie`: Punkt in Rechteck/Polygon (offene Polylinie ist keine Fläche), nächstes Objekt im Radius, Winkelrasten (fast waagerecht → exakt), Magnet nur im Radius.
- **Platzierte Bilder:** Rahmen um den Mittelpunkt, Skalieren lässt das Bild nicht wandern, Mindestbreite, Treffer rechnet Drehung heraus, gesperrte Bilder sind nicht greifbar, oberster zIndex gewinnt, Verschieben hält den Mittelpunkt in der Fläche.
- **Flucht-Fang:** wirkt nachweislich (Zahl, nicht Bild): Zug neben dem Strahl wird auf ihn gezogen (Toleranz 7°), weiter weg bleibt frei, Schalter aus → nichts. Horizont zieht seine Fluchtpunkte mit; der dritte Punkt (Auf-/Untersicht) liegt bewusst nicht auf dem Horizont. Raster-Strahlen starten im Fluchtpunkt und enden knapp hinter dem Bildrand.
- `PerspektivRaster`-Arten: Ein-, Zwei-, Drei-Punkt. Art wechseln behält gesetzte Punkte.

### 11.4 · Moodboard und Modeblatt, wie der Code es meint
- **Zwei Dinge heißen Moodboard:** (a) im Werkzeug-Modus „Moodboard" die **sechs Material-Slots** (unbelegt ab Werk); (b) das **Modeblatt** `MykModeblatt` (Raum, Kunde, Projektnummer, Seiten mit Rubrik/Unterthema und Modus **Collage** oder **Raster(spalten 2 | 4)**), A4 quer 297×210 mm in Punkten, Rand 36, Inhaltsfläche beginnt bei y = 96, unten Fußzeile. Ränder sind physisch, nicht anteilig.
- Elemente liegen als Anteile 0–1 (x, y, breite, hoehe?). Bild-Beschnitt (`MykModeblattBeschnitt`): Füllen über die kurze Achse, **verzerrt nie**; Anschnitt 0…1 (0,5 mittig) schiebt das Bild, geklemmt; ohne Übermaß kein Versatz; ohne Maße keine Division durch null.
- Drehung in 90°-Schritten, Grade normalisiert (−90 → 270), quer kehrt sich das Seitenverhältnis um, gespiegelt nicht. Neue Elemente kaskadieren (nie auf einen Punkt). Raster-Kacheln überlappen nie; Beschriftung ragt nicht in die Nachbarkachel (Fehler aus Vorgängerapp, 23.07.2026). Beschriftung weicht dorthin aus, wo kein anderes Bild liegt; Standardplatz „unten links".
- Beschriftung: nur nicht-leere Zeilen, **in Versalien**. Dateiname → lesbarer Titel („Falmec_Levante_Schwarz_8034122476933.jpg" → „Levante Schwarz"; kurze Zahlen = Produktcode bleiben). Fußzeilencode fällt auf den Kunden zurück, in Versalien. Alte Entwürfe ohne neue Schlüssel dekodieren weiter.
- **Ziehen/Größe der Bühne:** `gezogen` rechnet gegen den Griff-Startwert (nicht gegen den Zwischenstand), klemmt auf 0…1. `vergroessert` klemmt Breite auf 0,05…1,0.

### 11.5 · Konfigurator, wie der Code es meint
- Korpus-Zählung ist **fachbasiert**: Blende und leer zählen nicht; Rehder-Wand = 12 Korpen (3+4+2+3 volle Fächer); Heinz-Renovierung = 6 Korpen, 6 Schubkästen (2× Holz massiv).
- **Archetyp-IDs:** `hochschrankwand-geraeteblock` (Segmente 600/600/759/1200, Bänder 800/1260/560; Gerätesäule mit Backofen, Wärmeschublade, Kaffee, Kühl-Gefrier), `spuelenzeile` (Kette GS–Spüle–Müll verdrahtet), `renovierung-heinz` (2 Zonen), `insel-tresen`. Jeder Archetyp baut frische IDs.
- **Regel-IDs:** `gs-neben-spuele`, `muell-nahe-spuele`, `waerme-unter-backofen`, `durchgang-insel` (ohne Positionen: ehrliches Schweigen; 940 mm → Hinweis; 800 mm → Warnung), `zone-passt-in-raum`, `kochfeld-dunstabzug`. Annahme-Regeln sind „Johannes' offene Fragen", `offeneAnnahmen` nie leer, solange er nicht bestätigt.
- **Kürzel-Grammatik** (Tastatur): `725t 725 3sh 725 3sh 725t` = Heinz-Insel (t = Tür mit Fachböden, 3sh = 3 Schubkästen Holz; ohne Breite Standardbreite; `gs sp mu 3s`). Unfug wird gemeldet, nicht geraten (Breite < 100, 45 Schübe).
- Frontauszug = Schubkasten, Material unterscheidet (Legrabox vs. Holz massiv), kein eigener Fall. Variantenname: „Entwurf A", „B" …, Lücken werden aufgefüllt. Klon vergibt alle IDs neu, Kompilate leer.
- **Gewerk-Scope** (Rehder-Mail): Geräte, Arbeitsplatten, Armatur, Spülbecken, Griffe „kommen von uns" (MYKILOS), Korpen = Tischler, Arbeitsplatte = Steinmetz.
- **Anfrage-Text:** Tischler in Du-Form („Moin Moin Rami", „Kalkulatorisch würde ich von insgesamt 6 Korpen ausgehen", „4 Korpen gleicher Breite (725 mm)", Lagerprogramm-Hinweis), Steinmetz in Sie-Form mit Plattenzahl („2 Platten"). `.mykilos` liefert bewusst nichts. Kein Senden-Vokabular, es ist eine Anfrage. Betreff „Anfrage Kommission <Name>".
- **Render-Prompt** (fünf Blöcke, „GEOMETRIE (verbindlich)", „Fugenbild", „Keine Marken-Logos", Sockel-Default „analog zu Front"); Foto-Raum verlangt das Kundenfoto als Referenz, Material-`assetRef` wird Referenzbild.
- Stempel: VORPLANUNG, VORABZUG, finalisiert = keiner.

### 11.6 · Plan, wie der Code es meint
- `PlanProjektor`: **Elevation** = Frontansicht (Tiefe z fällt weg); **Isometrie** 30° (+y senkrecht unverkürzt, +x rechts-oben, +z links-oben). Papier-y zeigt nach oben; `PlanTransform` spiegelt für den View. Rückrechnung auf die Zeichenebene (Elevation z=0, Isometrie y=0) und **Achsen-Snap** (Elevation: waagerecht/senkrecht; Isometrie entlang der drei Achsen). Einpassmaßstab füllt die kürzere Achse; entarteter Rahmen und 0×0-Container ohne NaN. Rechteck spannt vier Ecken auf. Nur Elemente sichtbarer Layer zählen.

### 11.7 · Hub und Werkzeugwolke (rechte Leiste, nicht die Zeichenpalette)
- `WerkzeugKonfiguration.standard` sichtbar: neuesProjekt, neuerPlan, mail, suchen. Die rechte Leiste darf die linke Sidebar **nicht** kopieren (verbotene Namen: kataloge, papers, projekte, heute, assistent, einstellungen). Anpassbar: entfernen, hinzufügen, verschieben, Duplikate fliegen raus.
- `WerkzeugWolke`: bis `fassungsvermoegen` Werkzeuge lose in Ringen, Mindestabstand 58 px, Fläche 520×432, von innen nach außen (erstes in der Mitte), am Rand wird die Mitte hereingeklemmt, im zu kleinen Fenster mittig. Hover vergrößert das Icon **und** die Nachbarn (monoton, weit Entfernte bleiben unberührt). `HubPhysik`: Einrastnähe 48 px („rastet überall" wurde auf 48 gesenkt, vorher 140), Randabstand 24 pt, Kante des Hubs bleibt im Randstreifen.

### 11.8 · Was weiterhin offen ist
1. Wie die Vorgänger-App **real benutzt** wird: nur die Tests wurden gelesen, nicht die Swift-Ansichten in `MykilosWidgets/Sources`. Tests zeigen Sollverhalten.
2. Ob unsere ALFA-Editoren **drei Bögen** bleiben (Moodboard, Aufmaß, Atelier) oder ein vereintes Werkzeug mit fünf Modi werden. Der Altcode hat das vereinte Werkzeug und daneben eigene Ansichten.
3. Unser Aufmaß ist ein **Raummodell aus Wänden** (Schließfehler, Fläche, Öffnungen), der Altcode kennt als Kern das **Foto-Aufmaß**. Beides existiert im Altcode (Plan/Grundriss-Kalibrierung und Foto), unser Entwurf bildet nur die eine Seite ab.
4. Unser Moodboard ist eine **Seitenmontage** (Formate A3 quer / 16:9 / A4 hoch, Musterseite, Typo, Schriften, Moods, Vorlagen, Freistellen per Randfüllung). Der Altcode kennt Modeblatt (A4 quer, Collage/Raster) und die sechs Slots.
