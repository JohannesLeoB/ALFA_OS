# 00-LIES-MICH: Entscheidungen und Regelprüfung gegen ED

ED = die sechs maßgeblichen Bögen `ALFA Atelier.dc.html`, `ALFA Aufmass.dc.html`, `ALFA Moodboard.dc.html`, `ALFA Konfigurator.dc.html`, `ALFA Planvergleich.dc.html`, `ALFA Draws.dc.html`. Die Bögen tragen den Stand 21.10. (HANDOFF_Weiterarbeit_2110.md:1); die Entscheidungen sind vom 29.10. (00-LIES-MICH.md:114-115).

## (a) Entscheidungen von Johannes (29.10.) und Reihenfolge

Überschrift: „## Für Johannes zu entscheiden, bevor gezeichnet wird“ (00-LIES-MICH.md:112)

- 00-LIES-MICH.md:114: „1. **Entschieden (Johannes 29.10.):** Projektdaten entstehen in der App, über den Dialog „Neues Projekt“ und den Fragebogen. Drive, Airtable, ClickUp und lokale Ordner sind Ziele, die Firma und Person im Hub als Routen wählen (Lieferung 28.10., SPEC Teil „Hub und Dateien“).“
- 00-LIES-MICH.md:115: „2. **Entschieden (Johannes 29.10.):** Die Editoren sind ein eigenes Modul innerhalb der App, ein Kreativ-Paket nach Art der „Creative Cloud“. Dazu gehören Aufmaß, Atelier, Konfigurator, Plan und Planvergleich sowie Moodboard. Für Design heißt das: ein Einstieg in den Editoren-Bereich, darin die Editoren mit gemeinsamer Werkzeugleiste, gemeinsamer Layerliste, gemeinsamen Ein- und Ausgängen (Projekt, Projektordner, Medienkatalog) und einer gemeinsamen Ablage der Entwürfe. Wie man zwischen den Editoren wechselt und ob einer aus der Akte direkt aufgeht, zeichnet Design.“
- 00-LIES-MICH.md:116: „3. **Reihenfolge:** Vorschlag aus dem Archiv: Projekte zuerst, dann die Werkzeuge, die daran hängen.“ (als Vorschlag, nicht als Entscheidung markiert)

## (b) Regeln gegen ED

### Regeln, die schon gelten (00-LIES-MICH.md:64-69)

**R1 Token** — „Jede Farbe, jedes Maß und jede Dauer kommt als Token.“ (00-LIES-MICH.md:66) — **nein**
- Atelier: `z-index:40` (ALFA Atelier.dc.html:182); Farben als Literale `oklch(.45 .17 265)` u. a. (ALFA Atelier.dc.html:356); `gap:4px;max-width:176px` und Dauer `160ms` (ALFA Atelier.dc.html:146).
- Aufmass: `z-index:40` (ALFA Aufmass.dc.html:190); `max-width:176px` (ALFA Aufmass.dc.html:154).
- Moodboard: `z-index:40` (ALFA Moodboard.dc.html:173); Palette als Hex-Literale `PAL0` (ALFA Moodboard.dc.html:327).
- Konfigurator: `z-index:40` (ALFA Konfigurator.dc.html:173); Materialfarben `MATC` als Literale (ALFA Konfigurator.dc.html:500).
- Planvergleich: `z-index:40` (ALFA Planvergleich.dc.html:111), `z-index:50` (ALFA Planvergleich.dc.html:120).
- Draws: `z-index:40` (ALFA Draws.dc.html:64).
- Bestätigt durch HANDOFF: „Toast z 40 und Menü z 50 statt layer.toast 4 und layer.menu 5 (alle sechs)“ (HANDOFF_Weiterarbeit_2110.md:59).

**R2 Textschlüssel** — „Jeder sichtbare Text ist ein Schlüssel mit `de`.“ (00-LIES-MICH.md:67) — **nein**
- In keinem Bogen ein Verweis auf `texts.json` oder `"text.`-Schlüssel (Suche je Bogen: 0 Treffer). Texte stehen als Literale, z. B. ALFA Atelier.dc.html:671, ALFA Aufmass.dc.html:671, ALFA Moodboard.dc.html:713, ALFA Konfigurator.dc.html:737, ALFA Planvergleich.dc.html:283, ALFA Draws.dc.html:56.

**R3 Firmenwerte nicht als feste Texte** (00-LIES-MICH.md:68) — **nein**
- Firmenname — nein:
  - Moodboard: „Studio Brenner · A3 quer“ (ALFA Moodboard.dc.html:325); `lic: "Eigentum Studio Brenner"` (:339, :344, :345); Logo „Studio Brenner, Wortmarke“ (:344), „Studio Brenner, Kürzel“ „SB“ (:345); Kopfzeile `text: "Studio Brenner"` (:360, :364).
  - Draws: Schriftfeld „ALFA“ und „Studio“ (ALFA Draws.dc.html:260); CI „Studio, Kunde, Neutral“ (ALFA Draws.dc.html:133; erfunden laut README.md:29 und HANDOFF_Weiterarbeit_2110.md:39).
  - Konfigurator: „Studio-Standard ≥ 1000“ (ALFA Konfigurator.dc.html:526).
  - Atelier, Aufmass, Planvergleich: kein Firmenname gefunden (Suche mykilos|studio|GmbH|Tischlerei: kein Treffer) — ja.
- Ordnernamen — kein fester Ordnername gefunden (Suche PROJEKTE|_LEADS|0x_: kein Treffer). Generisch „Projektordner (Drive)“ (ALFA Atelier.dc.html:631, ALFA Aufmass.dc.html:656). Feste Plan-Dateinamen „ELT_EG · Fassung 2…4“, „KUE_01 · Fassung 2“ (ALFA Planvergleich.dc.html:266): unklar, ob Firmenwert (BR nennt nur Ordnernamen).
- Phasen — nein: Konfigurator `status: "Vorplanung"`, `"Vorabzug"` (ALFA Konfigurator.dc.html:363, :365, :367, :483). Atelier-Versionsstatus „Verworfen“, „Freigegeben“ (ALFA Atelier.dc.html:377), „Entwurf“ (:670), „Master“ (:673): unklar, ob Phase im Sinn von BR.
- Materialpalette — nein: Atelier `MATS` (ALFA Atelier.dc.html:359), Slot-Farbnamen „Ultramarin, Terracotta, Salbei, Ocker, Graphit, Taube“ (:356); Konfigurator `MATS` (ALFA Konfigurator.dc.html:345), Vorgaben je Teil (:360); Draws `MATS` „Eiche, Nussbaum, Lack weiß, Stahl“ (ALFA Draws.dc.html:129); Moodboard Farbpalette `PAL0` (ALFA Moodboard.dc.html:327).
- Vorlagen — nein: Moodboard `TPLS` „Stimmungsseite, Materialraster, Vollbild mit Titel …“ (ALFA Moodboard.dc.html:331), Formate `FMT` (:325); Aufmass „Aufmaß quer“ (ALFA Aufmass.dc.html:699); Konfigurator `ARCH` „Hochschrankwand mit Geräteblock …“ (ALFA Konfigurator.dc.html:565); Draws `TPLS` „A3 quer, A4 hoch …“ (ALFA Draws.dc.html:132; erfunden laut README.md:30).
- Anrede in Anfragen — ja: `anfrage()` baut Tischler- und Steinmetz-Text ohne Anrede, beginnt mit „Entwurf …“ (ALFA Konfigurator.dc.html:492-497). Suche „sehr geehrt|hallo|liebe|grüße“ in allen sechs Bögen: kein Treffer.
- Als Beispiel markiert: nur Planvergleich „Dateiwahl folgt · Beispieldaten“ (ALFA Planvergleich.dc.html:271). Sonst keine Markierung (Suche beispiel|demo).

**R4 N20 „nur wenn technisch möglich, nie ausgegraut“** (00-LIES-MICH.md:69; gilt laut BR für Mail, für andere Bereiche offen) — **nein** in drei Bögen, **ja** in drei
- Alle sechs haben die Ausgrau-Logik `op: o.off ? .4 : 1` (ALFA Atelier.dc.html:272, ALFA Aufmass.dc.html:280, ALFA Moodboard.dc.html:263, ALFA Konfigurator.dc.html:263, ALFA Planvergleich.dc.html:357, ALFA Draws.dc.html:362).
- Benutzt: Atelier `off: !sub.ready || !!ph.job` (ALFA Atelier.dc.html:678); Moodboard `off: !s.hist.length`, `off: !s.fut.length` (ALFA Moodboard.dc.html:740); Draws `off: s.zoom <= T.zoomMin` (ALFA Draws.dc.html:405).
- Aufmass, Konfigurator, Planvergleich: keine Verwendung von `off:` gefunden.

### Aus den Archiv-Specs (00-LIES-MICH.md:71-78)

**S1 Werkstatt: es gilt Punkt 2 (ein Editoren-Modul)** (00-LIES-MICH.md:73, :115) — **nein**
- Jeder Bogen ist ein eigener Eintrag der Gruppe „Kreativ“: Moodboard, Aufmaß, Atelier, Planvergleich, Konfigurator (ALFA Planvergleich.dc.html:148; gleich ALFA Atelier.dc.html:217, ALFA Aufmass.dc.html:225, ALFA Moodboard.dc.html:208, ALFA Konfigurator.dc.html:208). Kein gemeinsamer Einstieg.
- Draws hat eine eigene Gruppe „Draws“ (ALFA Draws.dc.html:122) und steht nicht in „Kreativ“.
- „Plan“ als eigener Editor: in GROUPS fehlt (ALFA Planvergleich.dc.html:148).
- Gemeinsame Ablage der Entwürfe: fehlt; jeder Bogen legt eigene Toasts „Im Projektordner gesichert · Entwurf“ ab (ALFA Atelier.dc.html:680, ALFA Konfigurator.dc.html:754).

**S2 Aufmaß, Atelier, Konfigurator, Bemusterung, Moodboard hängen an einem Projekt** (00-LIES-MICH.md:74)
- Atelier — ja: `PROJ` (ALFA Atelier.dc.html:354), Fotos mit `proj: "p1"` (:376).
- Aufmass — ja: `PROJ` (ALFA Aufmass.dc.html:367), `proj: "p1"` (:386).
- Konfigurator — ja: `PROJ` (ALFA Konfigurator.dc.html:337), `proj: "p1"` (:363).
- Moodboard — unklar: kein `proj`-Feld gefunden; nur Dokumentname „Küche Hansen · Stimmung“ (ALFA Moodboard.dc.html:373) und Kopfzeile „Küche Hansen“ (:360).
- Bemusterung — fehlt: kein Bogen.
- Planvergleich, Draws (nicht in der Aufzählung): Draws Projektfelder mit Vorgabewerten (ALFA Draws.dc.html:142).

**S3 Cash, Service und Akte gehören zu Projekte** (00-LIES-MICH.md:75) — **unklar**: ED zeichnet Projekte nicht. Suche Cash|Service: kein Treffer. „Akte“ nur in Draws „aus Akte P-2041“ (ALFA Draws.dc.html:429; erfunden laut HANDOFF_Weiterarbeit_2110.md:39).

**S4 Akte ohne die vielen Reiter** (00-LIES-MICH.md:76) — **unklar**: Akte in ED nicht gezeichnet.

**S5 „Keine Erklärsätze. Rückfragen nur, wo üblich. Rückgängig statt Frage.“** (00-LIES-MICH.md:77)
- Keine Erklärsätze — **nein**, in allen sechs Bögen:
  - Atelier: „Render-Ansicht · Skizzenwerkzeuge ruhen. Zurück zu «Skizze» zum Zeichnen.“ (ALFA Atelier.dc.html:600); „Bestand, Neu, Entfernen und Notiz sind feste Arten. Notizen werden nicht exportiert. Nichts gewählt: Klick auf ein Objekt zeigt seine Werte hier.“ (:644); „Notizen liegen auf der Notiz-Ebene und gehen nicht in Substrat oder Prompt.“ (:659); „Noch keine Version. Substrat bereitmachen, in «Rezept» den Auftrag senden.“ (:671); Werkzeughinweise „Klick oder Ziehen entfernt Striche, Bilder und Notizen auf entsperrten Ebenen“ (:609), „Klick setzt ein Platzhalterbild · Bild folgt aus Hub oder Datei“ (:610).
  - Aufmass: „Noch keine Maße. Werkzeug M wählen und auf dem Foto ziehen.“ (ALFA Aufmass.dc.html:671); „Nichts gewählt. Maß, Symbol oder Pin anklicken. Die Werte erscheinen hier und in der Kontextleiste.“ (:673); „Klicken wählt · Leere Fläche ziehen verschiebt · Doppelklick auf ein Maß ändert den Wert“ (:623).
  - Moodboard: „Leerer Rahmen: ein Bild aus der Bibliothek wählen“ (ALFA Moodboard.dc.html:713); „Zoom: Klick vergrößert, Alt verkleinert“ (:711); „Platzhalter ohne Bilddatei, nur markiert“ (:441).
  - Konfigurator: „Segment anklicken zeigt Breite und Fächer. Kürzel (K) baut ganze Zonen: 600t 3s sp gs.“ (ALFA Konfigurator.dc.html:737); „Farben in der Ansicht sind Darstellung. Die Einträge kommen aus der Moodboard-Palette; Katalogquelle im Altcode: unbekannt.“ (:740); „Sieben Regeln aus dem Altcode: 2 belegt …, 5 Annahmen. …“ (:742); „Annahmen: Korpus 19, Rückwand 8, … Maße in mm.“ (:745); „Segment anklicken · Ziehen sortiert in der Zone · …“ (:684).
  - Planvergleich: „Jeder Konflikt nennt zwei Objekte, eines aus jedem Gewerk.“ / „… Jeder Fund nennt Art und Grund.“ (ALFA Planvergleich.dc.html:276); „Plan 1:50 · DIN A1. Fremdgewerke liegen über den Blatt-Ursprung zur Deckung.“ (:283).
  - Draws: Markup „Lade ein Objekt aus dem Konfigurator oder gib Claude ein Foto, ein PDF oder einen Text.“ (ALFA Draws.dc.html:56); „Keine Mängel. Das Blatt ist bereit für den Export.“ (:435); „Kein Objekt geladen. Unten laden oder Claude ein Foto, PDF oder Text geben.“ (:438); „Ohne Objekt bleiben die Ansichten leer.“ (:446); „Ansicht auf dem Blatt anklicken. Ziehen setzt sie aufs Raster, Ecken ziehen ändert die Größe, Alt zieht frei.“ (:448); „Gib mir ein Foto, ein PDF oder einen Text. Ich baue daraus ein Objekt fürs Blatt.“ (:499). HANDOFF dazu: „Brief v13 N18 und N40: keine Erklärsätze in der UI, der Draws-Bogen verstößt dagegen.“ (HANDOFF_Weiterarbeit_2110.md:74)
- Rückfragen nur, wo üblich — **ja**, mit einer Stelle zu prüfen: kein `confirm(` in den sechs Bögen. `prompt(` nur als Eingabe beim Umbenennen oder für Tags (ALFA Atelier.dc.html:533, ALFA Aufmass.dc.html:533, ALFA Moodboard.dc.html:626, :630, ALFA Konfigurator.dc.html:490, :731). Frage im Fehlerfall: „Schrift Geist ließ sich nicht einbetten. Mit Systemschrift erneut versuchen?“ (ALFA Draws.dc.html:163) — unklar, ob „üblich“.
- Rückgängig statt Frage — **ja** in vier Bögen: „Entfernt“ mit Rückgängig (ALFA Atelier.dc.html:449, ALFA Aufmass.dc.html:451); „Seite gelöscht“ (ALFA Moodboard.dc.html:578); „Segment entfernt“, „Zone gelöscht“ (ALFA Konfigurator.dc.html:437, :490). Planvergleich, Draws: kein Toast mit Rückgängig gefunden; Draws hat „Entfernen“ (ALFA Draws.dc.html:460; erfunden laut README.md:38).

**S6 „Ein fehlender Wert bleibt leer; nie abgeleitet oder erfunden.“** (00-LIES-MICH.md:78) — **nein**
- Atelier — nein: Versionen mit Zeit „Gestern, 16:40“, Status „Verworfen/Freigegeben“ (ALFA Atelier.dc.html:377). Leer gelassen (ja): „Standardliste (Wortlaut im Altcode: unbekannt)“ (:548).
- Aufmass — nein: Beispielkalibrierung `mm: 2100` (ALFA Aufmass.dc.html:386), Maß „Fensterbreite“ `mm: 1600`, `src: "Manuell"` (:392). Leer gelassen (ja): ohne Kalibrierung `mm: null` und „Nicht kalibriert · Wert eintragen“ (:506).
- Moodboard — nein: erfundene Bilddaten „Ole Petersen“, „3. Okt. 2026“, „15. Aug. 2026“ (ALFA Moodboard.dc.html:340, :343), Lieferant „Nordlicht Stoffe“ (:343, :347), Lizenz „Eigentum Studio Brenner“ (:339).
- Konfigurator — nein: angenommene Werte rechnen mit, „Annahmen: Korpus 19, Rückwand 8, Sockel 16, Tiefe 560 (Wand 320), Platte 600 bzw. Insel 900.“ (ALFA Konfigurator.dc.html:745), „Stärke … mm (Annahme)“ (:496), „5 Annahmen“ (:742), Gerätemaße Backofen, Mikrowelle, Kühlschrank, Geschirrspüler (:499), „Studio-Standard ≥ 1000“ (:526), `pass: 950`, `wall: 4433` (:363). Leer gelassen (ja): „Artikelpreise“ „unbekannt“, „Katalog fehlt, daher kein Preis“ (:746); Gerätemaße `null` für Wärmeschublade u. a. (:499).
- Planvergleich — nein: fester Hinweis „Plan 1:50 · DIN A1“ (ALFA Planvergleich.dc.html:283); Beispielpläne „ELT_EG“, „KUE_01“ (:266). Leer gelassen (ja): „Mindestabstand zum Nassbereich ist nicht hinterlegt, du legst ihn fest“ (:177).
- Draws — nein: Projektfelder mit Vorgabewerten „Brandt“, „Küche Nordwand“, „Lindenstraße 14“, „20259 Hamburg“, „K-2041“, „21.10.2026“ (ALFA Draws.dc.html:142); „aus Akte P-2041“ (:429); Claude-Import gespielt „Claude hat ein Objekt erzeugt · 6 Teile · bitte prüfen“ (:285). Alle in README „Erfunden“ (uebergabe-draws-IN-PROGRESS/README.md:37) bzw. „Nicht gebaut“ (README.md:42).

## Leseprotokoll
- `br/brief-werkstatt/00-LIES-MICH.md`: ganz, 116 Z.
- `br/brief-werkstatt/02-bemusterung.md`: ganz, 62 Z.
- `ed/HANDOFF_Weiterarbeit_2110.md`: ganz, 83 Z.
- `ed/uebergabe-draws-IN-PROGRESS/README.md`: ganz, 68 Z.
- Sechs Bögen nicht ganz gelesen: `ALFA Atelier.dc.html` (693 Z.), `ALFA Aufmass.dc.html` (721 Z.), `ALFA Moodboard.dc.html` (752 Z.), `ALFA Konfigurator.dc.html` (767 Z.), `ALFA Planvergleich.dc.html` (398 Z.), `ALFA Draws.dc.html` (561 Z.). Alle Zeilen per Skript geprüft: (1) Textknoten im Markup mit ≥ 3 Wörtern; (2) String-Literale hinter `text|sub|tip|assist|hint|toastIt|label|note|title|placeholder` mit ≥ 5 Wörtern oder Satzende; (3) Stichwörter zu Firmenname, Ordnern, Phasen, Material, Vorlagen, Anrede, Beispiel/Demo, `confirm(`/`prompt(`, `off:`, `z-index`, Textschlüssel. Einzeln gelesen: Konfigurator Z. 345, 346, 360, 492–500, 565; Atelier Z. 217, 354–361; Planvergleich Z. 148, 177, 255, 276; Aufmass Z. 386. Erklärsätze in String-Verkettungen ohne diese Schlüssel können der Suche entgangen sein.
- `ed/BRIEFING_Editoren.md` (302 Z.), `ed/alfa-bausteine.js` (131 Z.): nicht gelesen.
- v-Fassungen: nicht gelesen.
