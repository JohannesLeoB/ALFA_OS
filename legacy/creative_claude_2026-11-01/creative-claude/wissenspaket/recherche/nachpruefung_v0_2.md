# Nachprüfung Kapitel 5 „Wissenspaket Küche“, Version 0.2

Stand 31.10.2026 · Unabhängige Nachprüfung gegen `paket2/recherche/pruefbericht_v0_1.md`. Geprüft wurden `paket2/KAPITEL_WISSENSPAKET.md` (566 Zeilen), sieben Schemata, sieben Beispiele, sieben Negativbeispiele mit `erwartet.json`, `pruefe_schema.py` und RN. RF und RS habe ich nur gezielt gelesen. Keine Datei im Paket wurde geändert. Eigene Testkopien liegen unter `kapitel/nachpruefung/` (`faelle.py`, `faelle/*/ausgabe.txt`).

Fundstellen: §-Abschnitt im Kapitel, sonst `datei:zeile` (km = kuechenmodell, pb = planungsbogen, wz = werkzeuge, bib = bibliothekseintrag, ps = pruefe_schema.py).
Schwere: **hoch** = falsches Ergebnis oder Datenfehler · **mittel** = ein Agent muss raten, oder eine Regel ist nicht durchgesetzt · **niedrig** = Form, Klarheit.
Statusregel für A: **erledigt** = alle genannten Teilpunkte umgesetzt. Neu aufgefallene Restpunkte stehen in B oder C. **teilweise** = mindestens ein genannter Teilpunkt fehlt oder ist unvollständig.

---

## A Die 10 wichtigsten Korrekturen

| # | Korrektur (Kurzform) | Status | Fundstelle v0.2 | Begründung |
|---|---|---|---|---|
| 1 | Koordinaten rechtshändig und eindeutig, Skizze, Schmalflächen, Beispiel korrigieren, Test im Skript | **teilweise** | §5.4 „Koordinaten (rechtshändig)“; gemeinsam:5; teil:5, teil:120; km-Beispiel:35, 51–52; ps:185–205 (I7) | Raum und Teil sind rechtshändig, haben eine Skizze und definierte Schmalflächen. Freiraum, Nut und Lochreihe sind korrigiert, und I7 prüft den Umlaufsinn. Eindeutig ist das System aber nicht bei gedrehten Elementen (`rot_z`), bei Wänden außer A und bei der Referenzseite (B1–B3, B6–B8). |
| 2 | Eingabeklassen/Herkunft entwirren; `vorgaben.werte`, Maßquelle je Maß, feste Elemente | **erledigt** | §5.2 „Herkunft“ und „Eingabeklassen“; gemeinsam:8–12; pb:32–47 (`messungen`), pb:100–105 (`vorgaben.werte`), pb:121–137 (`elemente_fest`); pb-Beispiel:30 (`arbeitshoehe` = `annahme`) | `annahme` steht nur noch für Unbestätigtes. Der Bogen hat jetzt Projektwerte, Messungen mit Quelle und Toleranz und feste Elemente. Neu: Die Invariante I1 lässt ein stilles Hochstufen zu (C1). |
| 3 | Eine Stufenzählung, ein Ausgaben-Vokabular | **erledigt** | §5.8 („Die Stufen entsprechen §5.12“), §5.12; gemeinsam:85–89; pb:189; setup:211, 217; wz:107 | Die Stufen in §5.8 und §5.12 stimmen für alle Ausgaben von Stufe 1 bis 6 überein, und das Enum `ausgabe` wird überall genutzt. Rest: `fusion_abgleich` und `ifc` haben keine Stufe (C9, C10), Vorlagen-`zweck` hat ein eigenes Vokabular (C14). |
| 4 | `werkzeuge.schema.json`; Werkzeuge `bogen_speichern`, `revision_freigeben`, `aufmass_importieren`, `fusion_abgleich`; Revisionsregel | **teilweise** | §5.10; wz:1–146 | Das Schema, die fehlenden Werkzeuge und die Spalte „Revision“ gibt es jetzt. Sieben Werkzeuge haben aber kein `_aus`, `bericht.annahmen` fehlt in den meisten Antworten, und mehrere Teilschemata sind offen und untypisiert (C5, C6). |
| 5 | Küchenmodell ergänzen und Schemata schließen | **erledigt** | km:8–96 (`variante`, `solver`, `scores`, `fest`, `freigabe`, `annahmen`), `additionalProperties: false` in allen Hauptschemata, teil:95–98 (`if/then`), gemeinsam:63–67 (`bibref_fest`) | Alle genannten Felder sind da. Rest: Die Werkzeug-Teilschemata sind offen (→ Nr. 4, C6). |
| 6 | Prüfskript: Invarianten, Negativbeispiele, Beispiele für `teil` und `bibliothekseintrag`, `date-time`; Beispiele auf Invarianten bringen | **teilweise** | ps:14–21, 87–206, 250–260; `beispiel/fehler/` (7 Dateien + `erwartet.json`); zwei bib-Beispiele | I1–I7, `date-time` und die sieben Negativbeispiele laufen, und die Beispiele erfüllen die Invarianten. Es fehlt ein eigenes `teil.*.json`-Beispiel, das Präfix `teil` wird nur verarbeitet (T15). Ein unbekanntes Präfix bricht weiterhin mit Traceback ab (T15b). |
| 7 | Stufe 0: E12, E14, F13 vorziehen; Material- und Kanteneinträge; Bestellliste zuordnen; Vorlagen-Inventar | **erledigt** | §5.12 Stufe 0 und Stufe 1; §5.8 (`bestellliste` Stufe 1); §5.8.1 „Inventar zuerst“ | Alle vier Teilpunkte sind umgesetzt, E18 kommt dazu. |
| 8 | Vorlagenweg: Escaper je Format, Typst nur mit JSON, SVG/HTML editierbar, Feldkatalog, Bemustern aus PDF | **erledigt** | §5.8.1 (Formattabelle, Feldkatalog, Render-Weg, DWG, Bemustern); setup:145 (`html_jinja` entfernt); setup:168 (Mini-Syntax offen benannt) | Alle Teilpunkte sind umgesetzt. Rest zu ZPL-Escaping: C19. |
| 9 | Fertigungsschema: Säge, Bearbeitung mit z, Richtung, Durchgang, Bögen; Bohrbild-Bezug; `nr`; Bestellposition; Montage; Innenausstattung | **teilweise** | setup:104–116; teil:9, 54–63, 80–89, 119–143; bib:24–32, 56–66; km:123–135, 158–168 | Die meisten Teilpunkte sind umgesetzt. Es fehlt eine **Bestellposition** als Schema, es gibt nur `bib.bestellung`. Die Transformation eines Bohrbilds aufs Teil (Achsen, Spiegelachse, Schmalflächen) ist offen (B9). |
| 10 | Belege bereinigen (Peka, „Vorschlag:“, Übertreibungen, DXF-Version, „R:5“, AMFI) | **erledigt** | §5.7 (Peka/Blanco mit RN), §5.14 (Pecasa ersetzt), §5.8 (Semikolon/BOM als Vorschlag, DXF R12), §5.5 (Patent „nahezu“), §5.7 (Recht, IDM), §5.13 E12, §5.9 (AMFI), §5.11 (Quote 93,9 % mit Kontext) | Alle Punkte sind umgesetzt. Stichproben stimmen mit den Beilagen: DIN 919-1 „Entwurf 10/2026“ (RF 6), MCP-SDK 0.12.1 mit 4–5 Abhängigkeiten (RS 8), Vapor 5 Beta (RS), AMFI-Bericht (RS 8), Peka-Angaben (RN 1). |

Bilanz: 6 erledigt, 4 teilweise, 0 nicht erledigt.

---

## B Koordinaten rechnerisch

### B.0 Rechnung

**Raum** (§5.4, gemeinsam:5)
- Ist das System rechtshändig? x × y = (1,0,0) × (0,1,0) = (0,0,1) = z. Ja.
- Blick vom Raum auf Wand A: Blickrichtung f = (0,−1,0), oben u = (0,0,1). Dann ist rechts = f × u = (−1,0,0). Bildschirm rechts ist also −x, die Ecke x = 0 liegt rechts, x läuft nach links. Die Aussagen des Kapitels stimmen.
- Beispiel-Grundriss [[0,0],[2460,0],[2460,3000],[0,3000]]: Die Gaußsche Fläche ist +7.380.000 mm², der Grundriss läuft also gegen den Uhrzeigersinn. Wand A läuft von (0,0) nach (2460,0). Der Raum liegt links der Kante, also bei +y.
- Kapitel und `gemeinsam.schema` sind deckungsgleich.

**Teil** (§5.4, teil:5)
- x läuft entlang l1 (von b1 nach b2), y von l1 nach l2, z nach oben. In der Skizze heißt das: x nach rechts, y nach oben, z zum Betrachter. Damit ist x × y = z, das System ist rechtshändig.
- Steht die Referenzseite fest und ist l1 bekannt, ist b1 eindeutig: Es ist die linke Schmalseite, wenn man auf die Referenzseite blickt und l1 vorn liegt.
- Die Koordinaten auf den Schmalflächen sind definiert: l1/l2 mit (x, z), b1/b2 mit (y, z). Bohrungen gehen senkrecht in die Fläche.

**Beispielwerte**
- Rückwandnut: y = 560 − 16 − 8,5 = **535,5**. Die Nut belegt y 535,5 bis 544,0. Bis zur Hinterkante l2 (y = 560) sind es 16 mm, das ist genau der Einstand. Tiefe 8 < Dicke 19. In x läuft die Nut von 0 bis 805 (Seite) bzw. 0 bis 562 (Boden), also im Fertigmaß. Sie liegt auf „oben“, der Innenseite. **Passt**, aber nur, wenn man y als untere Nutkante liest (B8).
- Lochreihe: y = 37 entspricht `abstand_vk` ab l1, der Vorderkante samt 1-mm-Kante. In x läuft die Reihe von 96 bis 96 + 17 · 32 = 640 ≤ 805, Tiefe 12 < 19, `richtung x` liegt parallel zur Vorderkante. **Passt.**
- Freiraum Auszug: Der Schrank liegt absolut bei x 600–1200, y 0–560, z 100–905. Mit der 19-mm-Front liegt die Vorderfläche bei y = 579, der Auszug reicht bis y 1100, das sind 521 mm. x und z decken den Schrank, und der Raum misst 2460 × 3000 × 2500. **Passt**, I7 ist grün. Die Höhenkette 100 + 805 + 5 = 910 stimmt mit der Arbeitshöhe.

**Urteil**
- Das Raumsystem ist rechtshändig. Eindeutig ist es nur für ungedrehte Elemente an Wand A.
- Das Teilsystem ist rechtshändig. Eindeutig ist es nur für Korpusteile mit fester Referenzseite.
- Die Beispielwerte stimmen.

### B.1 Befunde

| ID | Fundstelle | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| B1 | §5.4 „Lage“; gemeinsam:45–51; ps:57–64, 197–199 | **mittel** | „Ecke mit kleinstem x, y, z“ plus `rot_z` „gegen den Uhrzeigersinn“ nennt keinen Drehpunkt. Beispiel: ein Schrank an Wand B (x = 2460), t = 560, `rot_z` = 90°. Liest man `pos` als kleinste Ecke, ist pos = (1900, y₀, z₀). Liest man `pos` als lokalen Ursprung und dreht darum, ist pos = (2460, y₀, z₀). Das sind 560 mm Unterschied. Nicht festgelegt ist außerdem, dass die Front bei lokal y = t liegt. Das Skript überspringt gedrehte Elemente, prüft aber deren Kinder ungedreht (T03). | Festlegen: „`pos` = lokaler Ursprung im Elternsystem; Drehung um `pos`; lokal x entlang der Front, lokal y von der Wand in den Raum, Front bei y = t“. In `elemente_flach` die Elterndrehung anwenden. |
| B2 | §5.4 „Raum“; pb:26–29, 48–76 | **mittel** | Welche Wand „Wand A“ ist und dass sie auf der x-Achse liegt, ist an keine Datenregel gebunden. Tauscht man `wand-a` auf die Punkte 1→2, bleibt alles grün (T02). | „Wand A = `waende[0]`; `grundriss[von]` = [0,0], `grundriss[nach]` = [L,0] mit L > 0“ und in I7 prüfen. |
| B3 | pb:62–66 (`oeffnungen.x`), pb:78–89 | **mittel** | Der Bezug von `x` für Öffnungen auf anderen Wänden als A ist nicht definiert (wandlokal ab `von`?). Fenster an Wand B sind aber für Hängeschränke und Kollisionen entscheidend. | „`x` = Abstand vom Wandanfang `von` entlang der Wand, Blick vom Raum“ in pb festschreiben. |
| B4 | gemeinsam:5; pb:27 | niedrig | z = 0 auf OKFF steht nur indirekt in der Beschreibung des Grundrisses. | In gemeinsam:5 ergänzen: „z = 0 auf OKFF“. |
| B5 | §5.4 „Raum“ („Die Wandansicht spiegelt nur der Plan-Adapter“) | niedrig | Eine Wandansicht ist eine Projektion mit −x nach rechts, keine Spiegelung. Das Wort lädt dazu ein, die Geometrie zu spiegeln. Auch die Achszuordnung des `FusionClient` (Y-up oder Z-up) ist nicht festgelegt [Einschätzung]. | „Die Wandansicht projiziert in Blickrichtung −y (Bildschirm rechts = −x)“. Achszuordnung im FusionPort festlegen. |
| B6 | §5.4 „Teil“; teil:5 | **mittel** | „Referenzseite = Seite mit den meisten Bearbeitungen“ ist instabil. Bei Gleichstand ist nichts festgelegt, und eine weitere Bohrung auf der Unterseite (`element_aendern`) kann die Referenzseite wechseln. Dann spiegeln sich alle Koordinaten des Teils. | Referenzseite je `rolle` fest in einer Tabelle (Korpusteile innen, Front Rückseite, Arbeitsplatte oben …), nicht nach Anzahl der Bearbeitungen. |
| B7 | §5.4 „Teil“; teil:5 | **mittel** | l1 ist nur für Korpusteile definiert. Für Front, Rückwand, Arbeitsplatte, Sockel, Passleiste und Blende fehlt die Festlegung. | Tabelle „l1 je `rolle`“, z. B. Front: untere Kante, Rückwand: untere Kante. |
| B8 | teil:119–125; §5.4 „Beispiel“; ps:141–150 | **mittel** | Der Bezugspunkt je Bearbeitungsart steht nicht im Schema. Bei der Nut lesen Kapitelformel und I4 (`y + breite`) y als untere Nutkante. Liest man y als Mittellinie, verschiebt sich die Nut um 4,25 mm [Einschätzung: in CNC-Formaten ist die Mittellinie üblich]. | In `bearbeitung` festlegen: Bohrung = Mittelpunkt; Nut/Falz = Kante mit kleinerem y (Richtung x) bzw. x (Richtung y), Breite in +y/+x; Tasche = Ecke min. |
| B9 | teil:54–63; bib:24–31 | niedrig | `beschlaege.bohrbild` hat nur x/y, auf Schmalflächen gelten aber (x,z) bzw. (y,z). Die Spiegelachse von `gespiegelt` ist offen, ebenso die Achsen des Bohrbilds gegenüber den Teilachsen. | Bohrbild = {seite, u, v, drehung, spiegel_achse}, wobei u und v die Flächenachsen der jeweiligen Seite sind. |
| B10 | km-Beispiel:30, 35; km:171 | niedrig | `masse.t` = 560 enthält die Front nicht. Die Front (y 560–579) liegt weder im Element noch im Freiraum, die Kollisionsprüfung erfasst sie also nicht. | `masse` inklusive Front festlegen oder Fronten als eigene Quader führen. |
| B11 | km-Beispiel:74–75 | niedrig | `wk-1` und `aw-1` liegen bei x 1300 bzw. 1350, außerhalb des Spülenschranks (x 600–1200), sind aber `element: z1-02` zugeordnet. Die Toleranz von 50 mm reicht nicht. | Die Anschlüsse ins Schrankfeld legen oder das Element anpassen. Für ANS gibt das einen guten Rot-Testfall. |

---

## C Neue Widersprüche (Kapitel ↔ Schemata ↔ Beispiele ↔ Skript)

| ID | Fundstellen | Schwere | Befund | Korrektur |
|---|---|---|---|---|
| C1 | §5.4 I1; ps:98–101; pb:5 („vorgaben ist bindend (herkunft projekt)“) gegen pb:101 (`werte` erlaubt `annahme`) | **hoch** | I1 vergleicht nur den Wert, nicht die Herkunft der Quelle. Steht `arbeitshoehe` im Bogen als `annahme` mit offener Frage, darf das Modell sie als `projekt` führen und aus `annahmen[]` streichen, und alles bleibt grün (T06). Das Gleiche gilt für `setup`: `sockel_rueckversatz` ist im Setup `annahme`, im Modell als `setup` geführt bleibt es grün (T07). `gemessen` wird gar nicht geprüft, und `erbt_von` wird ignoriert. Damit greift die zentrale Ehrlichkeitsregel aus Korrektur 2 nicht. | I1: `projekt` nur, wenn `vorgaben.werte[k].herkunft` = `projekt` und der Wert gleich ist; `setup` nur, wenn `konstruktion[k].herkunft` = `setup`, dabei die Kette `erbt_von` auflösen. Sonst muss `annahme` stehen. pb:5 korrigieren: „bindend außer Werten mit `annahme`“. |
| C2 | §5.2 „Konstruktions-Mindestsatz“ und Fertig-Kriterium; setup:15, 56; km:23–28; km-Beispiel:9–20, 51–52 | **mittel** | Das Kapitel nennt 9 Pflichtschlüssel, darunter `rueckwand`, `lochreihe` und `verbinder`. Das Setup-Schema verlangt nur 6. Die drei zusätzlichen Schlüssel sind Objekte und können deshalb nicht in `kuechenmodell.werte` stehen, das nur `wert`-Typen erlaubt. Das Beispiel verfehlt so das eigene Fertig-Kriterium von Schritt 3, und seine Teile lesen aus `setup.lochreihe` bzw. aus dem Baustein statt aus `werte`, gegen §5.2 „Bausteine lesen nur dort“. | Die drei als flache `wert`-Schlüssel führen (`rueckwand_einstand`, `rueckwand_nut_breite`, `lochreihe_abstand_vk` …) oder strukturierte Werte zulassen. `required` angleichen und den Mindestsatz in I1 prüfen. |
| C3 | §5.4 „Revision“; km:80–94; wz:111 | **mittel** | Gefertigt wird, „wenn `freigabe` gesetzt ist“. Nirgends steht aber, dass `freigabe.revision` = `revision` sein muss, und `element_aendern` setzt die Freigabe nicht zurück. Eine Freigabe für Revision 1 bei Modell-Revision 2 bleibt grün (T05). | Regel ergänzen: „gültig nur bei `freigabe.revision == revision`“. `element_aendern` setzt `freigabe` auf null. Die Prüfung in I5 bzw. einer I8 ergänzen. |
| C4 | §5.4 „Teile und Befunde sind abgeleitete Daten derselben Revision“; §5.10 „Idempotent“; km:47–75 | **mittel** | `teile` und `pruefung` tragen keine Revisionsmarke. Nach `element_aendern` sind die Teile veraltet, ohne dass es jemand merkt (T17). Bei derselben Revision hängt der Hash davon ab, ob `teile_ableiten` schon lief. | Felder `teile_revision` und `pruefung.revision` ergänzen. `ausgeben` und Freigabe verlangen Gleichheit, sonst `revision_veraltet`. |
| C5 | §5.10 („Ein- und Ausgaben stehen als Schema … `<name>_aus`“; „Jede Antwort enthält `bericht.annahmen`“) gegen wz | **mittel** | `_aus` fehlt für `bib_suchen`, `bib_eintrag`, `bib_importieren`, `vorlage_rendern`, `korrektur_melden`, `regelvorschlaege` und `regel_entscheiden`. `bericht` steht nur in `planen_aus`, `teile_ableiten_aus` und `ausgeben_aus`. `pruefen_aus.befunde`, `revision_freigeben_aus.freigabe` und `planen_aus.scores` sind untypisiert (`{"type":"object"}`). Die Hülle „Ausgabe oder `fehler`“ fehlt als `oneOf`. | Alle `_aus` ergänzen und überall `bericht` aufnehmen. `befunde`, `freigabe` und `scores` per `$ref` auf km. Eine `antwort_<name>` = `oneOf`[`_aus`, `fehler`]. |
| C6 | wz:7–8, 63, 71, 84, 95, 102, 106–110, 115 | **mittel** | `ref_bogen` und `ref_modell` sind offen, und mit `allOf` zusammengesetzte Eingaben lassen sich so nicht schließen. Ein Tippfehler wie `vorlag` statt `vorlage` bleibt unbemerkt (T10). Das ist gefährlich, weil das MCP-`inputSchema` daraus entsteht. `element_id`, `modell_id` und `vorschlag_id` sind nackte Strings ohne ID-Muster. | `unevaluatedProperties: false` je `_ein`, `$ref id` für alle IDs. |
| C7 | §5.4 „Rolle Admin oder Team“; wz:102, 144 | **mittel** | Die Rolle ist ein Eingabefeld. Der Aufrufer, auch Claude, erklärt sich also selbst zum Admin, und die Freigaberegel läuft ins Leere. | Die Rolle kommt aus der Identität der Sitzung im Werkzeugkern, nicht aus der Eingabe. Die Eingabe enthält nur die Bestätigung. |
| C8 | km:5; §5.4 Tabelle „Schreibt“ | niedrig | `revision_freigeben` schreibt `freigabe` ins Modell, steht aber nicht unter den Schreibern. | Den Schreiber ergänzen. |
| C9 | §5.1 Regel 2; §5.8 Zeile `fusion` (Stufe 0, Prüfung „`fusion_abgleich` ohne Abweichung“); Integrationskatalog „0–5“; §5.12 | **mittel** | `fusion_abgleich` und das Element `freiform` sind keiner Stufe zugeordnet, und Stufe 0 nennt keinen Fusion-Adapter. Der Rückweg aus Fusion war im Vorbericht ein hohes Risiko (R5a). Er ist jetzt spezifiziert, aber nicht eingeplant. | In Stufe 0 oder 1 aufnehmen, mit dem Fertig-Kriterium „Abgleich beider Küchen ohne Abweichung“. |
| C10 | §5.8 `ifc` „später“; Integrationskatalog: Claude „1 / 5“, Ablage „5“ | niedrig | Für `ifc` gibt es keine Stufe. Stufe 1 enthält kein `kitchen-mcp`, Stufe 5 keine Ablage. | `ifc` als „nach Stufe 6“ führen und den Katalog an die Stufeninhalte angleichen. |
| C11 | §5.9 („wenn F2, F3 **und** F12 sie fordern“) gegen §5.12 Stufe 4 („F2, F3 **oder** F12“) | niedrig | „und“ und „oder“ widersprechen sich, und davon hängt ab, wann Stufe 4 startet. | Eine Konjunktion festlegen, vermutlich „oder“. |
| C12 | §5.5 „Gekoppelte Wände …“; §5.9 Grundsatz 4 und Port `SolverPort`; F13 | **mittel** | F13 erlaubt in der Desktop-App „native Hilfsprogramme (… Solver)“, und der `SolverPort` nennt CP-SAT. Grundsatz 4 dagegen lässt nur Typst und die PackingSolver-CLI nativ zu und stellt OR-Tools unter „nur CI, Entwicklung und SaaS“. Offen bleibt, ob CP-SAT nativ in der App laufen darf. Außerdem ist „blockiert bis F13“ (§5.5, Stufe 3) überholt, weil Stufe 0 F13 ohnehin verlangt. | Grundsatz 4 präzisieren: „CP-SAT als native C++-CLI nur nach F13 = ja; OR-Tools über Python nur SaaS“. „Blockiert bis F13“ durch „nur bei F13 = ja, sonst SaaS“ ersetzen. |
| C13 | §5.8.2 („das erzwingt das Schema“); teil:97 | niedrig | Ein Teil mit Faser, bei dem `drehbar` fehlt, besteht (T08). Erzwungen wird die Regel nur, wenn `drehbar` gesetzt ist. | Im `then` `"required": ["drehbar"]` ergänzen. |
| C14 | setup:144 (`zweck`) gegen gemeinsam:88 (`ausgabe`) | niedrig | Es gibt zwei Vokabulare: `blatt_werkplan`/`werkplan`, `etikett`/`etiketten`, `montageanleitung`/`montage`, `bestellung`/`bestellliste`. `ausgeben(ziel, vorlage)` kann deshalb nicht prüfen, ob die Vorlage passt. | `zweck` = Enum `ausgabe` plus `plankopf`, `schrift`, `marke`, oder eine Zuordnungstabelle. |
| C15 | §5.4 „Teilnummer `nr` fester Länge“; teil:9; setup:173; km-Beispiel:44 | niedrig | Das Muster `^[A-Z0-9-]{1,16}$` erlaubt variable Länge. `{auftrag}` aus `teil_nr` kommt in keinem Schema vor, und woher `N2460` stammt, ist offen. | Feld `auftrag` (fest lang) in Bogen und Modell ergänzen. `nr`-Länge über das Setup prüfen. |
| C16 | pb:19 (`aufmass.quelle` mit `roomplan`) gegen pb:40 (`messungen.quelle` ohne `roomplan`); wz:42 | niedrig | Die Aufmaßquellen sind uneinheitlich. | Ein Enum `messquelle` in gemeinsam. |
| C17 | wz:111 (Liste der Fertigungsziele) gegen §5.10; Beispiel `werkzeug.ausgeben_ein` (Werkplan aus nicht freigegebener Revision 1) | niedrig | Die Liste der Fertigungsziele steht nur als Freitext im Schema. `werkplan`, `step` und `montage` fehlen dort, obwohl sie an die Werkstatt gehen. | Ein maschinenlesbares `$defs/ausgabe_fertigung`. Werkplan ohne Freigabe nur mit Stempel „nicht freigegeben“ (`setup.planstempel`). |
| C18 | ps:229–260; §5.4 „Alle sieben Negativbeispiele scheitern an den … vorhergesagten Stellen“ | niedrig | Der Abgleich läuft nur über Teilstrings, zusätzliche Fehler werden nicht gemeldet: `neg-schema` erzeugt 7 Befunde gegen 6 Erwartungen, und „teile/1: “ deckt zwei Fehler ab. Der Kontext (Bogen, Setup) kommt nur aus `beispiel/`, Negativbeispiele für Bogen- und Setup-Invarianten sind also nicht möglich. Ein unbekanntes Präfix führt zum Absturz (T15b). | Die Erwartung als exakte Menge von (Pfad, Regel) führen. Kontextdateien je Negativfall zulassen. Unbekannte Präfixe melden statt abbrechen. |
| C19 | §5.8.1 Zeile `zpl` | niedrig | Mit `^FH` muss auch der Hex-Indikator `_` selbst maskiert werden (`_5F`), und Teil-IDs enthalten `_` [Einschätzung zum Druckerverhalten]. | Den Escaper um `_` ergänzen. |
| C20 | §5.12 Stufe 0 („minimale Einträge für Material und Kante“); bib-Beispiel `abs-weiss-1` (`ungeprueft`) | niedrig | Die Ausgaben aus Stufe 1 sind Fertigungsziele und brauchen eine Freigabe, I5 verlangt dann `geprueft`. Mit dem Beispieleintrag scheitert die Freigabe (T13). | Fertig-Kriterium für Stufe 0: „genutzte Einträge `geprueft`“. |
| C21 | §5.4 I3; ps:116–130 | niedrig | `anschluss.element` wird nicht aufgelöst (T16). | In I3 aufnehmen. |

Ohne Befund geprüft:
- Revisionsregel in §5.4, §5.10, wz:5 und km:5: wortgleich.
- Werkzeugnamen in §5.10 und wz-`$defs`: alle 19 vorhanden.
- Fehlercodes in §5.10 und wz:12: identisch.
- Befund-Feldnamen `regel`/`schwere`: §5.6 = km:60–61.
- Stufen von Stufe 1 bis 6: §5.8 = §5.12 (Ausnahmen C9, C10).
- `setup.weiche` und `setup.ausgaben` auf das Enum `ausgabe`: ja.
- W8 (Preise), W23 (Regel-ID), W25 (Maschinen nur im Setup), B5–B8 des Vorberichts: behoben.

---

## D Prüfskript

### D.1 Lauf im Paket

`cd paket2 && python3 -I pruefe_schema.py schema`:
```
Schemata gueltig: bibliothekseintrag, gemeinsam, kuechenmodell, planungsbogen, setup, teil, werkzeuge
bibliothekseintrag.abs-weiss-1.json ok
bibliothekseintrag.spanplatte-mfc-weiss-19.json ok
  Warnung kuechenmodell.nische-2460.json I5 nische-2460-z1-02-seite_links: abs-weiss-1 ist ungeprueft (Planung erlaubt, Fertigung nicht)
  Warnung kuechenmodell.nische-2460.json I5 nische-2460-z1-02-boden: abs-weiss-1 ist ungeprueft (Planung erlaubt, Fertigung nicht)
kuechenmodell.nische-2460.json ok
planungsbogen.nische-2460.json ok
setup.studio-beispiel.json ok
werkzeug.ausgeben_ein.json ok
werkzeug.planen_ein.json ok
NEGATIV … alle 7: scheitert wie erwartet
exit=0
```
Das entspricht der Angabe in §5.4: 7 Schemata, 7 Beispiele, 7 Negativbeispiele. Umgebung: jsonschema 4.26.0, Python 3.13.

### D.2 Zusätzliche Fehlerfälle

Alle Fälle laufen auf Kopien in `nachpruefung/faelle/<fall>/schema`. Skript: `nachpruefung/faelle.py`, Ausgaben in `…/ausgabe.txt`.

| Fall | Änderung | Soll | Ergebnis | Schwere der Lücke |
|---|---|---|---|---|
| T01 | Grundriss im Uhrzeigersinn | erkennen | **erkannt** (I7) | – |
| T02 | `wand-a` auf die Punkte 1→2 (nicht auf der x-Achse) | erkennen | nicht erkannt | mittel (B2) |
| T03 | Bereich `z1` mit `rot_z` = 90° bei (0,0,0); das Kind liegt dann bei x < 0 | erkennen | nicht erkannt; nur eine Warnung zu `z1`, das Kind wird ungedreht geprüft | mittel (B1) |
| T04 | Freiraum mit `min` > `max` | erkennen | nicht erkannt | niedrig |
| T05 | Freigabe für Revision 1 bei Modell-Revision 2 | erkennen | nicht erkannt | mittel (C3) |
| T06 | `arbeitshoehe` als `projekt`, obwohl der Bogen `annahme` führt | erkennen | nicht erkannt | **hoch** (C1) |
| T07 | `sockel_rueckversatz` als `setup`, obwohl das Setup `annahme` führt | erkennen | nicht erkannt | mittel (C1) |
| T08 | `faser laengs`, `drehbar` fehlt | erkennen | nicht erkannt | niedrig (C13) |
| T09 | `faser laengs` mit `drehbar true` | erkennen | **erkannt** (Schema) | – |
| T10 | `ausgeben_ein` mit Tippfehler `vorlag` | erkennen | nicht erkannt | mittel (C6) |
| T11 | `korpus_h` = 800, `ableitung` ergibt 805 | erkennen | nicht erkannt | niedrig |
| T12 | Bohrung auf l1 mit Tiefe 600 > Teilbreite 560 | erkennen | nicht erkannt | niedrig |
| T13 | Freigabe gesetzt, Kante `ungeprueft` | erkennen | **erkannt** (I5) | – |
| T14 | Teil 2900 × 560 bei Lagerformat 2800 × 2070 | erkennen | **erkannt** (I6) | – |
| T15 | Datei `teil.seite-links.json` | prüfen | **geprüft** („ok“) | – |
| T15b | unbekanntes Präfix `kante.*.json` | melden | KeyError mit Traceback, exit 1; Dateien danach bleiben ungeprüft | niedrig (C18) |
| T16 | `anschluss.element` = `z9-99` | erkennen | nicht erkannt | niedrig (C21) |
| T17 | Revision 3, Schrankbreite 900, Teile unverändert | erkennen | nicht erkannt | mittel (C4) |
| T18 | Kind bei y = −10 (hinter Wand A) | erkennen | **erkannt** (I7) | – |

Ergebnis: Erkannt werden T01, T09, T13, T14 und T18, T15 wird korrekt geprüft. Nicht erkannt werden T02–T08, T10–T12, T16 und T17. Die gefährlichste Lücke ist T06: Eine unbestätigte Arbeitshöhe kann als Vorgabe erscheinen.

---

## E Namensregel

| Fundstelle | Befund | Schwere | Korrektur |
|---|---|---|---|
| Kapitel insgesamt | Keine Personen- oder Kundennamen. Projekte heißen nur `ref-a` und `nische-2460`, „Python-Weg v3.3“ ist entfernt. | – | – |
| §5.0 „Belege“ (`creative-claude/korpus/`), §5.9 Schnitt-Tabelle (`creative-claude/`) | Interne Repo- bzw. Projektbezeichnung im Fließtext; grenzwertig. | niedrig | Neutral formulieren: „Projektkorpus (außerhalb des Pakets)“, „eigenes Repo für das Paket `Kitchen`“. |
| §5.1, §5.14 | `martinfowler.com` steht nur in der URL, der Linktext heißt „Strangler Fig, 2024“. | – | als Quellen-URL zulässig |
| Schemata, Beispiele, Negativbeispiele | Keine Namen. IDs neutral (`studio-beispiel`, `frage-ok-ap`, `regeln-runde-1`, `N2460-…`). bib:59 verbietet Personennamen bei `lieferant` ausdrücklich. | – | – |
| RN | Nur Hersteller-, Produkt- und Dokumentbezeichnungen (Peka, Blanco, Pleno Maxi, Magic Corner, Dok.-Nr.); das ist nach der Ausnahme in §5.0 zulässig. Keine Personennamen. | – | – |

---

## Reihenfolge der Nacharbeit (Vorschlag)

1. **C1**: I1 um die Herkunft der Quelle ergänzen (T06, T07).
2. **B1–B3, B6–B8**: Lage bei `rot_z`, Wand A, Öffnungsbezug, Referenzseite und l1 je Rolle, Bezugspunkt je Bearbeitungsart. Danach I7 mit Drehung und Wand-A-Test.
3. **C3, C4**: Freigabe und abgeleitete Daten an die Revision binden.
4. **C5–C7**: Werkzeugschema vervollständigen und schließen, Rolle aus der Identität statt aus der Eingabe.
5. **C2**: Mindestsatz zwischen Kapitel, Setup-Schema und `kuechenmodell.werte` angleichen.
6. **C9, C12**: `fusion_abgleich` einplanen, CP-SAT in der App eindeutig regeln.
