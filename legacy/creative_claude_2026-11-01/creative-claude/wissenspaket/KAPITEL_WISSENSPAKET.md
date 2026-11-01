# 5 Wissenspaket Küche: Konzept und Code-Design

Stand 31.10.2026 · Version 0.2 (nach zwei unabhängigen Prüfungen überarbeitet) · Status **Entwurf, nicht freigegeben** · Ergänzt `ARCHITECTURE.md` §0–§4 · Liegt außerhalb des ALFA-Repos; Bau in ALFA erst auf Wort des Owners.

## 5.0 Für Agents

Zweck: Ein Wissenspaket, mit dem Claude heute in Fusion Küchen plant und das Schritt für Schritt eigene Werkzeuge bekommt, bis Fusion und Claude dort, wo sie nur rechnen, ersetzt sind. Ziel ist eine native macOS-App mit Swift-Kern als ALFA-Modul, später derselbe Kern als SaaS.

Leitwörter:
- **Würgefeige**: Neue Teile wachsen neben den alten und übernehmen Aufgabe für Aufgabe (§5.1).
- **Weiche**: Sie entscheidet je Ausgabe, ob der alte oder der neue Weg ausliefert (`setup.weiche`).
- **Herkunft**: Jeder Wert sagt, woher er kommt. Bestätigt sind `kern`, `setup`, `projekt` und `gemessen`, unbestätigt ist `annahme` (§5.2).
- **Vorgabe / Vorschlag / Rückfrage**: die drei Eingabeklassen (§5.2).
- **Revision**: Jede Ausgabe nennt die Modellrevision, aus der sie entstand. Gefertigt wird nur aus einer freigegebenen Revision (§5.4).
- **Adapter**: liest das Modell, schreibt genau ein Format und schreibt nie ins Modell zurück (§5.8).
- **Golden Master**: das festgehaltene Ergebnis des alten Wegs, gegen das der neue geprüft wird. **Schattenbetrieb**: Der neue Weg läuft mit, liefert aber nicht aus (§5.11).
- **Episode**: eine vom Menschen korrigierte Planungsentscheidung mit Beleg. Aus Episoden werden Regeln (§5.2).

Lesereihenfolge: §5.1–5.4 Konzept und Daten → §5.5–5.8 Fachkern (Planen, Prüfen, Bibliotheken, Ausgaben) → §5.9–5.10 Code und Werkzeuge → §5.11 Lernen → §5.12 Stufenplan → §5.13 Entscheidungen und offene Fragen.

Beilagen neben dieser Datei:
- `schema/`: JSON Schema v0.2 (Draft 2020-12) mit `gemeinsam`, `planungsbogen`, `setup`, `kuechenmodell`, `teil`, `bibliothekseintrag` und `werkzeuge`. Beispiele liegen in `schema/beispiel/`, Negativbeispiele mit erwarteten Fehlerstellen in `schema/beispiel/fehler/`.
- `pruefe_schema.py`: Aufruf `python3 -I pruefe_schema.py schema`. Prüft Schemata, Beispiele, die Invarianten I1–I8 und die Negativbeispiele.
- `recherche/`: fünf Recherchen mit allen Quell-URLs, dazu die beiden Prüfberichte. Kürzel: **RF** Fertigung/CAM/Formate, **RC** Code-Bausteine, **RP** Planung/Normen/Aufmaß, **RS** Swift-Ökosystem, **RN** Nachrecherche Peka/Blanco. Zitierform `RF 1.2`, `RP [Q21]`, `RP 0 Nr. 4`.

Belege: Kürzel mit Abschnitt oder URL in §5.14. Markierung wie in den Recherchen: [belegt], [unsicher], [Einschätzung]. „Vorschlag:“ steht für einen eigenen Entwurf. „Projektkorpus“ steht für die Studio-Küchenpläne und Lernrunden im Projektordner; er ist nicht beigelegt.

Namensregel (§0) gilt: keine Personen-, Kunden- oder Projektnamen. Projekte heißen nur `ref-a` (Referenzküche Wandzeile mit Kochinsel) und `nische-2460` (Nischenküche 2460). Ausnahme in diesem Kapitel: Hersteller, Software, Formate und Normen werden genannt, wo Schnittstellen beschrieben werden. Welche davon das Studio nutzt, steht nur im Setup.

## 5.1 Grundsatz: Würgefeige

Wir arbeiten weiter mit Fusion und Claude und bauen dabei die Teile, die sie ersetzen. Kein Ersatz in einem Schritt: Kleine neue Teile übernehmen über Nahtstellen eine Funktion nach der anderen, Übergangscode ist dabei eingeplant ([Strangler Fig, 2024](https://martinfowler.com/bliki/StranglerFigApplication.html)).

Vier Regeln:
1. **Wahrheit liegt im neutralen Modell.** Das Küchenmodell (JSON, §5.4) ist die Quelle; Fusion, PDF, CSV und DXF sind Ausgaben. Maße ändern sich nur im Modell.
2. **Rückweg aus Fusion.** Wird in Fusion doch etwas geändert, liefert `fusion_abgleich` eine Liste der Abweichungen. Der Mensch übernimmt sie mit `element_aendern` oder verwirft sie. Sonderformen, die nur Fusion kann, werden im Modell zum Element `freiform` mit Hüllquader und STEP-Verweis.
3. **Jede Ausgabe ist ein Adapter, die Weiche wählt.** Alter und neuer Adapter laufen nebeneinander. `setup.weiche` legt je Ausgabe fest, welcher ausliefert, und `ausgeben` meldet den Weg (`alt`/`neu`).
4. **Gleichwertigkeit wird gemessen.** Golden-Master-Tests halten das Verhalten des alten Wegs fest ([Characterization test](https://en.wikipedia.org/wiki/Characterization_test)). Verglichen werden kanonisches JSON und Zeichenliste, keine PDF-Bytes (§5.9).

Ablösen heißt zweierlei:
- **Fusion ablösen**: Teileliste, Pläne, Zuschnitt, Etiketten und Prüfung, später STEP und 3D-Vorschau. Fusion bleibt für Sonderformen, Renderings und Kontrolle.
- **Claude ablösen, wo Claude rechnet**: Was Claude jede Runde gleich tut, wird eine Kernfunktion. Claude bleibt für Sprache → Planungsbogen, für Vorschläge, Erklärungen, Ausnahmen und das Lernen. Koordinaten setzt ein Solver, nicht das Sprachmodell. Im LEGO-Eval-Benchmark erfüllen die besten Verfahren höchstens 10 % der Detail-Constraints (RP 3 [Q57]).

## 5.2 Das Wissenspaket: Kern, Setup, Projekt

| Ebene | Inhalt | Wer pflegt | Beispiel |
|---|---|---|---|
| **Kern** | Verfahren, Formeln, Bausteine, Prüfregeln, Normwerte, Defaults | Paket, versioniert | `korpus_h = arbeitshoehe − sockel_h − ap_d`; Regel ABS-02 |
| **Setup** | Werte, Kataloge, Vorlagen, Maschinen, Stile, Preise, bestätigte Regeln | Firma, Gruppe oder Nutzer | Korpus 19, Rückwand 8 in Nut, Platten 2800 × 2070, Schnittbreite 4,4 |
| **Projekt** | Planungsbogen: Raum, Messungen, Anschlüsse, Vorgaben, Wünsche, offene Fragen | Mensch je Auftrag | Nische 2460, Arbeitsplatte 5 mm |

- **Setup** ist das **Profil** aus §0 und §3, erweitert um Kataloge, Maschinen, Preise und bestätigte Regeln. Es gibt die Ebenen `firma`, `gruppe` und `nutzer`, verbunden über `erbt_von`; das nähere Setup gewinnt.
- Zuordnungstest (erweitert §3.1):
  - ändert sich zwischen Firmen oder Nutzern → Setup
  - ändert sich zwischen Aufträgen → Projekt
  - Verfahren oder Norm → Kern
  - gerätespezifisch → Bibliothek, nie Kern (RP 0 Nr. 4)
- **Vorrang**: Projekt > Setup > Kern. Projektwerte stehen in `planungsbogen.vorgaben.werte`. Sie sind bindend, außer wenn sie `herkunft = annahme` tragen; dann gehört eine offene Frage dazu. Aufgelöst wird einmal je Lauf in `kuechenmodell.werte`, und Bausteine lesen nur dort.
- **Herkunft**:
  - `kern`, `setup`, `projekt` und `gemessen` sind bestätigt und erscheinen nicht als Annahme.
  - `annahme` ist unbestätigt: Fallback, gelernter Kandidat, unbestätigte Setup-Regel oder Projektwert mit offener Frage.
  - Ein abgeleiteter Wert erbt die schwächste Herkunft seiner Eingänge; aus einer Annahme wird wieder eine Annahme (Invariante I1).
  - Zuordnung zu den Status aus §3: `bemasst` = `projekt` oder `gemessen` mit Beleg; `abgeleitet` = Beleg mit `ableitung`; `annahme` bleibt `annahme`.

### Eingabeklassen

| Klasse | Bedeutung | Verhalten |
|---|---|---|
| **Vorgabe** | vom Menschen gesagt oder eingetragen | bindend (`projekt`); Abweichung nur mit Rückfrage |
| **Vorschlag** | Fallback, gelernter Kandidat, unbestätigte Setup-Regel | wird angewendet, `herkunft = annahme`, steht im Bericht |
| **Rückfrage** | Konflikt oder fehlender Pflichtwert | `offene_fragen[]`; die Planung läuft mit einem Vorschlag weiter, wenn er umkehrbar ist |

Bestätigte Kern- und Setup-Werte sind Standards, keine Vorschläge. Kennzahl **Übernahmequote** (§5.11).

### Kern-Grundwerte (Auszug, Status aus RP (a))

| Schlüssel | Wert | Status | Beleg |
|---|---|---|---|
| `ap_bis_haengeschrank_min` | ≥ 450 mm (Zielwert im Setup) | Norm, sekundär | RP 2.1 [Q21] |
| `sockel_h_min` | ≥ 80 mm | Norm, sekundär | RP 2.1 |
| `ap_t_min` | ≥ 600 mm | Norm, sekundär | RP 2.1 |
| `haengeschrank_t` | 310–400 mm | Norm, sekundär | RP 2.1 |
| `nische_unterbau_h_min` | ≥ 820 / 870 / 920 mm | Norm, sekundär | RP 2.1 |
| `arbeitshoehe` | Ellenbogen − 100…150 mm; ±50, wenn mehrere Personen die Küche nutzen | Verband (AMK 2011) | RP 2.3 [Q31] |
| `hauptarbeitsflaeche_min` | ≥ 800 mm, Ziel 900–1200 | Ratgeber | RP 2.4 |
| `ablage_kochfeld_min` | ≥ 300 mm | Ratgeber | RP 2.4 |
| `gang_min` | ≥ 1200 mm, barrierefrei 1500 | Ratgeber / Norm | RP 2.5 |
| `steckdosen_ap` | 2 je 1,2 m Arbeitsfläche + 3 allgemein | Norm, Tabelle [unsicher] | RP 2.2 [Q26] |
| `stromkreise_eigen` | Herd, Mikrowelle/Dampfgarer, Geschirrspüler | Norm, Tabelle [unsicher] | RP 2.2 [Q26] |
| `installationszone_h` | 1000–1300 mm über OKFF, Vorzug 1150 | Norm, sekundär | RP 2.2 [Q30] |
| `haube_ueber_kochfeld` | aus Gerätedaten; Fallback 650 mm mit Warnung | Hersteller | RP 2.6 |

Die Recherche hat drei Annahmen korrigiert (RP 0):
- DIN 68935 regelt Bäder; für Küchen gilt DIN EN 1116:2018-03.
- DIN 18022 ist zurückgezogen.
- Das Fünf-Zonen-Modell stammt von Blum (2005), nicht von der AMK.

Normwerte sind nur sekundär belegt. Vor der Freigabe als Kernwert wird das Original geprüft (F1).

### Konstruktions-Mindestsatz (Pflicht im Setup)

Alle Konstruktionswerte sind flache `wert`-Schlüssel mit Herkunft. So landen sie unverändert in `kuechenmodell.werte`, und Bausteine lesen nur dort.

| Schlüssel | Bedeutung | Gebraucht von |
|---|---|---|
| `korpus_d`, `korpus_t` | Korpusplattendicke, Korpustiefe | alle Schrankbausteine |
| `rueckwand_d`, `rueckwand_einbau`, `rueckwand_einstand` (+ `rueckwand_nut_tiefe`, `rueckwand_nut_breite` bei Nut) | Rückwand | alle Schrankbausteine |
| `front_d`, `fuge_front` | Front | Fronten, Schubkästen |
| `sockel_h` | Sockelhöhe | Unterschrank, Hochschrank, Sockel |
| `lochreihe_abstand_vk`, `lochreihe_teilung` (+ Durchmesser, Tiefe), `verbinder` | System 32, Verbinder | Bohrbilder |

Pflicht sind die elf Schlüssel ohne Klammer, so steht es auch im `required` von `setup.konstruktion`. Fertig-Kriterium für Planungsschritt 3 (§5.5): Diese Schlüssel und jeder Parameter des genutzten Bausteins stehen in `kuechenmodell.werte` (I1).

### Wie Wissen wandert

```
Korrektur im Projekt ──► Episode im Setup (Zähler, Beleg)
  Episoden ≥ n, von einer Admin-Rolle bestätigt ──► Setup-Regel
  gleiche Regel in ≥ m Setups, bereinigt, mit Zustimmung ──► Kern-Kandidat ──► Kern-Release
```
- Preise, Namen und Kundendaten verlassen das Setup nie.
- Kern-Releases sind versioniert. Das Setup nennt `kern_version`, das Modell hält beides fest.
- Vorschlag: n = 3, m = 3. Für den Hold-out zählen nur Küchen, die nicht zum Lernen dienten.

## 5.3 Fünf Schichten

```
5 Oberflächen   Claude (Chat/Code) · ALFA OS (macOS) · später SaaS-Web
                         │  MCP · ALFA-Assistent · später HTTP
4 Skills        kueche-planung · kueche-werkplanung · kueche-fertigung · kueche-praesentation  (Ablauf + Verweise)
                         │
3 Werkzeuge     Server „kueche“ über dem Kern (§5.10)
                         │
2 Bibliotheken  material · kante · beschlag · geraet · zukauf · asset · vorlage · stil
                         │
1 Datenmodell   Planungsbogen · Setup · Küchenmodell · Teil · Bibliothekseintrag · Werkzeuge  (JSON Schema)
```

- Schicht 1 kennt keine Software, Schicht 3 keine Oberfläche, ein Skill keine Datei auf dem Mac.
- Fusion ist ein Adapter (`ausgeben` mit Ziel `fusion`), kein Fundament.
- Skills enthalten nur Abläufe und Verweise, keine Kataloge. Skills in der API sind auf 30 MB und 20 je Anfrage begrenzt und laufen ohne Netz und ohne Paketinstallation ([Skills-Guide](https://platform.claude.com/docs/en/api/skills-guide)). Kataloge kommen über Werkzeuge. Portabel ist das Skill-Format, nicht die Laufzeit (RC 8).

## 5.4 Datenmodell

| Schema | Rolle | Schreibt | Liest |
|---|---|---|---|
| `planungsbogen` | Raum, Messungen mit Quelle und Unsicherheit, Wände, Öffnungen, Anschlüsse (Bestand), Hindernisse; Vorgaben mit `werte`, `elemente_fest`, Materialien, Geräte, Nutzer; Wünsche, Ausgaben, offene Fragen | Mensch (über Claude, Formular, Aufmaß-Import) | Planer |
| `setup` | Konstruktion (Mindestsatz), Kataloge, Beschlagsysteme, Lagerformate mit Sichtseiten, Maschinen mit Sägeparametern und Werkzeugen, Vorlagen, Planstempel, Namensschema, Regeln, Preise, Ausgabe-Presets, Weiche | Nutzer; Lernschleife nach Bestätigung | Planer, Adapter |
| `kuechenmodell` | eine Variante: aufgelöste Werte, Solver-Angaben, Scores, Elementbaum (fest, Fronten, Innenausstattung, Freiraum, Montage, Freiform), Teile, Anschlüsse, Prüfbefunde, Annahmen, Freigabe | Planer, Prüfer, `teile_ableiten`, `revision_freigeben` | alle Adapter |
| `teil` | Nummer für Code 128, Material, Dicke, Fertig- und Zuschnittmaß, Faser, Drehbarkeit, Sichtseite, Kanten, Bearbeitungen, Beschläge mit Bohrbild-Lage, Etikett, Zusammenbau | Kern (PartEngine) | Zuschnitt, CNC, Kanten, Etikett, Montage, Bestellung |
| `bibliothekseintrag` | Maße, Einbau, Anschlüsse, Bohrbild mit Bezug, Auswahlregeln mit Beleg, Material, Bestelldaten, CAD-Dateien, Quelle, Status, Lizenz, Weitergabe | Bibliotheksdienst | Planer, Adapter |
| `werkzeuge` | Ein- und Ausgaben jedes Werkzeugs, Fehlercodes (§5.10) | – | Server, App, Tests |

### Koordinaten (rechtshändig)

```
Raum, Grundriss von oben, Wand A unten          Teil, Referenzseite oben (z = Dicke)

  y ▲   Raum (y > 0)                               y ▲      l2 (hinten)
    │                                                │  ┌──────────────────┐
    │  ┌──── Unterschrank ────┐                   b1 │  │                  │ b2
    └──┴──────────────────────┴──► x                 │  └──────────────────┘
  (0,0)        Wand A (y = 0)                         └─────── l1 (vorn) ─────► x
```
- **Raum**: Wand A ist `waende[0]` und liegt auf der x-Achse von [0,0] nach [L,0]. Der Raum liegt bei y > 0, z zeigt nach oben, z = 0 auf OKFF, x × y = z.
  - Vom Raum aus auf Wand A geblickt ist der Ursprung die rechte Ecke, und x läuft nach links, so wie in Fusion beim Blick in −y (Bildschirm rechts = −x).
  - Die Wandansicht ist eine Projektion in Blickrichtung −y. Das erledigt nur der Plan-Adapter; die Geometrie wird nie gespiegelt.
  - Der Grundriss läuft gegen den Uhrzeigersinn.
  - Öffnungen werden ab dem Wandanfang `grundriss[von]` entlang der Wand bemaßt (I7).
- **Teil**: Das Teil liegt mit der Referenzseite nach oben (z = Dicke).
  - Ursprung an Kante l1 und b1 auf der Unterseite; x entlang l1 (Länge), y von l1 nach l2, z nach oben. b1 liegt links, wenn man auf die Referenzseite blickt und l1 vorn ist. `faser laengs` heißt parallel zu x.
  - Referenzseite und l1 sind **je Rolle fest**, nicht nach Anzahl der Bearbeitungen; so kann eine weitere Bohrung das Teil nie spiegeln:

| Rolle | Referenzseite | l1 |
|---|---|---|
| Korpusteile (Seiten, Boden, Deckel, Traversen, Mittelseite, Einlegeboden) | Innenseite bzw. Seite zum Korpusinneren | Vorderkante |
| Front, Blende, Schubkastenfront | Rückseite | Unterkante |
| Rückwand | Innenseite | Unterkante |
| Arbeitsplatte, Schubkastenboden, Regal | Oberseite | Vorderkante |
| Sockel, Passleiste, Wange | Rückseite | Unterkante |
| Schubkastenseite, Schubkastenrückwand | Innenseite | Unterkante |

  - Schmalflächen: l1/l2 werden mit x und z bemaßt, b1/b2 mit y und z. Bohrungen gehen senkrecht in die Fläche.
  - Bezugspunkt je Bearbeitung:
    - Bohrung und Bohrreihe: Mittelpunkt der ersten Bohrung.
    - Nut und Falz: Kante mit kleinerem y (Richtung x) bzw. kleinerem x (Richtung y), die Breite zählt in die positive Richtung.
    - Tasche, Ausschnitt, Griffmulde: Ecke mit kleinstem x und y.
  - Ein Beschlag-Bohrbild wird mit (u, v, Drehung, Spiegelachse) auf die Flächenachsen der Seite gesetzt.
  - Beispiel: Die Rückwandnut liegt bei y = Breite − Einstand − Nutbreite = 560 − 16 − 8,5 = 535,5; die Lochreihe bei y = 37 (Abstand von der Vorderkante).
- **Lage** eines Elements:
  - `pos` ist der lokale Ursprung im System des Elternelements; `rot_z` dreht um `pos` gegen den Uhrzeigersinn.
  - Lokal läuft x entlang der Front und y von der Wand in den Raum; der Korpus belegt 0…b, 0…t, 0…h, die Front liegt bei y = t.
  - `masse` ist der Korpus ohne Front; Fronten bildet der Kern für die Kollisionsprüfung als eigene Quader.
  - **Freiräume** (Tür, Auszug, Gerätetür) stehen im Raumsystem.

### Festlegungen

- **IDs**: klein, ASCII, ohne Namen. Die sprechende Teil-ID folgt `setup.namensschema.teil_id`. Dazu kommt eine kurze **Teilnummer** `nr` für den Code 128 aus dem Auftragskürzel (`planungsbogen.auftrag`, fünf Zeichen) und einer Laufnummer; ein QR-Code darf die ID tragen (RF 6).
- **Revision**:
  - `bogen_speichern` und `aufmass_importieren` erhöhen die Bogen-Revision.
  - `element_aendern` erhöht die Modell-Revision und setzt `freigabe` auf null.
  - Teile und Befunde sind abgeleitete Daten und tragen ihre Revision (`teile_revision`, `pruefung.revision`). Weicht sie ab, gelten sie als veraltet (I8).
  - Gefertigt wird nur, wenn `freigabe.revision` gleich `revision` ist.
  - Die Rolle der Freigabe (Admin oder Team) stammt aus der Identität der Sitzung, nie aus einer Werkzeugeingabe.
- **bibref**: Im Modell und in Teilen gilt `bibref_fest` mit Pflicht-Stand, so friert das Projekt den Katalogstand ein.
- **null und fehlt**: `null` heißt „bewusst nichts“, z. B. keine Kante oder keine Freigabe. Ein fehlendes Feld heißt „nicht angegeben“.
- **Schema als Quelle**: Swift-Typen werden aus dem Schema erzeugt, nicht umgekehrt (§5.9, E18).

### Invarianten (Prüfer, Stufe „Fehler“; umgesetzt in `pruefe_schema.py`)

| Nr | Regel |
|---|---|
| I1 | Herkunft passt zur Quelle, nach Wert **und** Herkunft:<br>• `projekt` nur bei bestätigter Vorgabe mit gleichem Wert<br>• `setup` nur bei bestätigtem Setup-Wert (Kette `erbt_von` aufgelöst)<br>• `gemessen` nur mit passender Messung<br>• `kern` nur mit Beleg<br>• Ist die Quelle eine Annahme, bleibt der Wert eine Annahme; aus einer Annahme Abgeleitetes ebenso<br>• Die Rechenprobe einer `ableitung` stimmt<br>• Der Konstruktions-Mindestsatz ist vollständig |
| I2 | `annahmen[]` = genau die Schlüssel mit `herkunft = annahme` |
| I3 | Element-, Teil- und Anschluss-IDs sind eindeutig; `teil.gruppe`, `element.teile` und `anschluss.element` lösen auf |
| I4 | Jede Bearbeitung liegt im Fertigmaß (Reihen, Nuten und Taschen mit ihrer Ausdehnung). Die Tiefe ist kleiner als das Material in Bohrrichtung (Dicke, auf Schmalflächen Breite bzw. Länge), außer bei `durchgang` |
| I5 | Jeder Bibliotheksverweis löst auf. `gesperrt` ist ein Fehler. `ungeprueft` gibt bei der Planung eine Warnung und bei Freigabe einen Fehler |
| I6 | Jedes Plattenteil passt ins Lagerformat seines Materials (gedreht nur, wenn `drehbar`) oder trägt `teilung` |
| I7 | Der Grundriss läuft gegen den Uhrzeigersinn; Wand A liegt von [0,0] nach [L,0]; Elemente liegen mit ihrer Drehung im Raum; Freiräume haben min < max und liegen im Raum |
| I8 | `freigabe.revision`, `teile_revision` und `pruefung.revision` sind gleich `revision` |

Geprüft am 31.10.2026:
- sieben Schemata gültig
- sieben Beispieldateien gültig: Bogen, Setup, Modell, zwei Bibliothekseinträge, zwei Werkzeugaufrufe
- alle 23 Negativbeispiele scheitern an den in `fehler/erwartet.json` vorhergesagten Stellen, darunter:
  - Auszug hinter der Wand
  - Annahme still zur Vorgabe hochgestuft
  - Freigabe einer alten Revision
  - veraltete Teile
  - gedrehte Elemente außerhalb des Raums
  - Tippfehler in Werkzeugeingaben
  - Rolle in der Werkzeugeingabe
  - unbekanntes Dateipräfix

## 5.5 Planen

Ablauf „Regeln + Solver + Bewertung + Mensch wählt“. Er wird gestützt von Forschung (RP 3 [Q50], [Q52]) und einem Küchenpatent, das diesen Ablauf nahezu beschreibt, allerdings katalog- und rasterbasiert (RP 3 [Q51]).

| Schritt | Wer | Ergebnis | Fertig, wenn |
|---|---|---|---|
| 1 Aufmaß | Mensch, `aufmass_importieren` | Raum und Messungen im Bogen | Jede Messung hat Quelle und Toleranz. Kritische Maße sind per Laser bestätigt: Wandlängen auf Arbeits- und Sockelhöhe, Diagonalen, Lot, Brüstungen, Lage von Rohren und Dosen (RP 5). `unbestaetigt_kritisch = []` |
| 2 Briefing | Claude ↔ Mensch | Vorgaben, Werte, feste Elemente, Geräte, Wünsche | `bogen_pruefen` meldet `fehlend = []` |
| 3 Werte | Kern | `werte{}` mit Herkunft | Mindestsatz und alle Bausteinparameter sind aufgelöst (§5.2) |
| 4 Bedingungen | Kern | harte und weiche Bedingungen | Jede Bedingung trägt eine Regel-ID |
| 5 Solver | Kern | 1–3 Varianten | Jede Variante erfüllt alle harten Regeln. Sonst nennt `planen` die verletzten Regeln (`verletzt[]`) |
| 6 Bewertung | Kern | Scores für Ergonomie, Zonenfolge, Stauraum, Fertigung und Kosten | Jeder Score hat Wert und Begründung |
| 7 Prüfung | Kern | Befunde F/W/H (§5.6) | 0 Fehler |
| 8 Wahl | Mensch | gewählte Variante, `fest` an Elementen | Die Variante ist gewählt; feste Elemente bleiben beim nächsten Lauf |

- **Rechnen**: Küchen laufen meist eindimensional entlang von Wandsegmenten. Die Gleichung Breiten + Passleisten = Wandlänge ist ganzzahlig in mm exakt lösbar, auch ohne Raster (RP 3).
- **Desktop**: Für eine Wand oder Nische reicht dynamische Programmierung im Swift-Kern.
- **Gekoppelte Wände, Ecken, Inseln**: CP-SAT löst Küchenlayouts in Zehnersekunden (RP 3 [Q52], Beispiel RC 6). OR-Tools hat keine Swift-Anbindung (RS 7). In der Desktop-App läuft das deshalb nur, wenn F13 eine native CP-SAT-CLI erlaubt, sonst im SaaS.
- **Rollen**: Claude übersetzt das Briefing in Vorgaben und erklärt Varianten. Koordinaten setzt Claude nie ohne Solver und Prüfer.
- **Gleiche Variante** heißt: gleiche Modulfolge, Breiten ±1 mm.
- **Aufmaß zweistufig** (RP 5):
  - Ein Scan liefert die Topologie: Apple RoomPlan liefert Wände, Öffnungen und 16 Objektkategorien als JSON und USDZ, nennt aber keine Genauigkeit.
  - Der Laser liefert die kritischen Maße (DISTO-Export DXF/DWG).
  - Ein magicplan-DXF enthält keine Maße.
- **Studio-Eigenheit** laut Projektkorpus: mm-genau ohne Raster, Restfeld als Funktionsfeld, meist ohne Oberschränke. Der Solver bekommt deshalb kein Breitenraster, sondern Mindest- und Höchstbreiten je Funktion aus dem Setup.

## 5.6 Prüfen

Die Prüfdienste der Branche folgen einem gemeinsamen Muster (RP 4):
- regelbasiert, mit drei Schweregraden
- Bezug auf das einzelne Element
- Erklärung mit Quelle
- jederzeit wiederholbar

Hier wirken die Regeln auf die Geometrie statt auf Katalogtypen. Jede Regel soll Quelle und Status nennen; RP (b) liefert dazu die Datenquelle, den Status ergänzt Stufe 2.

Regelregister: 30 Regeln in zehn Klassen (Volltext mit Schwere und Datenquelle: RP (b)):
- KOL: Kollision, Öffnungshüllkörper, Eckblockade
- ABS: Abstände
- GER: Geräteeinbau, Lüftung, Nischenmaß
- ANS: Anschlüsse, Steckdosen, Installationszone
- ERG: Ergonomie, Zonenfolge nach Händigkeit
- WEG: Gänge, Türaufschlag
- VOL: Vollständigkeit
- FER: Fertigbarkeit
- TOL: Aufmaßunsicherheit
- SIC: Sicherheit

Regeln sind **Kernfunktionen mit Metadaten**, keine eigene Ausdruckssprache. Eine Sprache für Regeln kommt erst, wenn Nutzer selbst Regeln schreiben sollen. Vorschlag für die Metadaten:
```json
{"id": "ABS-02", "schwere": "fehler", "klasse": "ABS",
 "quelle": {"art": "norm", "ref": "DIN EN 1116:2018-03", "status": "sekundaer", "beleg": "RP 2.1 [Q21]"},
 "text": "Abstand Arbeitsplatte bis Hängeschrank {gemessen} mm, Mindestmaß {soll} mm",
 "testfaelle": {"rot": "tests/abs02_rot.json", "gruen": "tests/abs02_gruen.json"}}
```
Ein Befund trägt dieselben Feldnamen (`regel`, `schwere`), siehe `kuechenmodell.pruefung`.

Umsetzung:
- **Kollision**: Prüfung auf achsparallelen Boxen (AABB) mit Toleranz. Türaufschlag, Auszug, Gerätetür und Bedienfläche sind **Freiraum-Boxen** im Raumsystem. Das ist schnell und erklärbar („Tür z1-03 schlägt an Griff h1“). Exakt prüft ein B-Rep-Kern nur Schrägen, Ecken und importierte Formen (RC 5).
- **Gerätewerte** (Haube, Kochfeldabstände, Lüftung) kommen aus der Gerätebibliothek. Fehlen sie, gilt ein Fallback mit dem Befund „Warnung: Herstellerangabe fehlt“ (RP (a)).
- **Anschlüsse**:
  - Spüle und Geschirrspüler liegen in der Wasserzone mit Setup-Toleranz.
  - Jedes Elektrogerät hat einen Anschluss oder einen Stromkreis.
  - Keine Befestigung in der Installationszone ohne Leitungsortung (ANS-01…04).
  - Geplante Anschlüsse (`status: geplant`) sind von Bestandsanschlüssen getrennt.
- **Elektro und Gas**: Das System gibt nur Hinweise, keine Fachplanung (F8).

## 5.7 Bibliotheken

| Bibliothek | Inhalt | Quellen | Hinweis |
|---|---|---|---|
| `material` | Plattenwerkstoffe, Dekore, Dicken, Formate, Faser, Sichtseiten, Darstellung je Ausgabe | Herstellerkataloge, Händler-CSV, BMEcat, falls geliefert | ohne Preise |
| `kante` | Kantenbänder: Material, Dicke, Höhe | Kataloge | Zuschnittmaß = Fertigmaß − Kantendicke (+ Fräszugabe) (RC 3) |
| `beschlag` | Scharniere, Auszüge, Schubkästen, Klappen, PTO, Innenausstattung, Verbinder; Bohrbild mit Bezugspunkt, Auswahlregeln mit Beleg, Mindestbreiten | **Blum**: Konfigurator, CAD/CAM-Datenservice, Produktdaten-Service für Partner (RF 4). **Häfele**: CAD-Datenbank mit ~40.000 Artikeln, Formate nicht genannt (RF 4). **Peka**: Produktfamilien, Maße, CAD-Daten über die Service-Seite, Montageanleitungen mit Bohrbildern (RN 1). Hettich, Grass: CAD-Pakete, Partnerlisten (RF 4) | **Bohrbilder nie raten**: Der Topf Ø 35 ist bei allen Herstellern gleich, die Schraubbilder unterscheiden sich (45/9,5; 48/6; 52/5,5) (RF 4) |
| `geraet` | Einbau- und Nischenmaße, Abstände, Lüftung, Anschlüsse, Hülle als 3D | Montageanleitungen der Hersteller (RP [Q42], [Q43]); **Blanco**: Ausschnittschablonen 1:1 als PDF (RN 2) | EN 1116 nennt keinen Haubenabstand, nur einen Verweis auf den Hersteller |
| `zukauf` | Spülen, Armaturen, Griffe, LED, Sockelfüße | Kataloge | Bestelldaten im Eintrag |
| `asset` | 3D-Modelle und Texturen für Vorschau und Rendering (glTF/USDZ) | eigene, Hersteller | Lizenz je Datei |
| `vorlage` | Planblätter, Plankopf, Listen, Etiketten, Präsentation | Nutzer (§5.8.1) | genau ein Zweck je Datei (§3.3) |
| `stil` | Linienstärken, Schriften, Farben, Materialkombinationen, Zeichenregeln | Studio, gelernt aus Planvorlagen | |

Maschinen, Sägeparameter und CNC-Werkzeuge stehen nur im Setup, denn Werkzeugnummern sind maschinenspezifisch (RF Kurzfazit). **Preise** stehen nur in `setup.preise`.

**Schubkästen**: Auswahlregeln wie „Nennlänge aus Korpustiefe“ oder Zargenhöhe, Boden- und Rückwandmaß kommen als `regeln` mit Beleg aus dem Herstellereintrag. Der Baustein dazu entsteht in Stufe 3. **Peka-Innenausstattung** (Hochschrankauszug, Innenauszug, Ecklösung, Abfallsystem) erscheint im Modell als `element.innenausstattung[]`. Der Eintrag liefert Mindestbreite, lichte Höhe, Öffnungswinkel und Last (RN 1).

Regeln:
- **Herkunft der Einträge**: Jeder Eintrag trägt `quelle` (Art, URL, Stand), `status`, `lizenz` und `weitergabe`. Neue Einträge starten mit `ungeprueft`. Geplant werden darf mit `ungeprueft` (Warnung); gefertigt wird nur mit `geprueft` (I5).
- **Hersteller-CAD**: bleibt `weitergabe = nur_setup`, bis die Nutzungsbedingungen geprüft sind. Vorschlag: In der SaaS nur über Partnerprogramme (Blum Produktdaten-Service, Hettich- und Grass-Partner), denn eine Weitergabe ist laut RF 7 vermutlich nicht erlaubt [unsicher].
- **Recht**: Dateiformate selbst sind in der EU nicht urheberrechtlich geschützt. Wörtlich übernommene Handbuchtexte können dagegen eine Verletzung sein (RF 7, EuGH C-406/10). Das ist keine Rechtsberatung.
- **Kaufmännische Standards**: BMEcat, ETIM, openTRANS und OCI sind offen dokumentiert, beim IDM sind die Zugangsbedingungen unklar (RF 5). Für die Einzelfertigung sind sie nachrangig; Stufe 1 bestellt per CSV-Liste.

## 5.8 Ausgaben

Die Stufen entsprechen §5.12.

| Ausgabe (`ausgabe`) | Format | Stufe | Golden Master / Prüfung | Beleg |
|---|---|---|---|---|
| `zuschnittliste` | CSV/XLSX mit Spalten-Presets für den Optimierer der Werkstatt (Cut Rite, Ardis, intelliDivide). Vorschlag: Semikolon, UTF-8 mit BOM | 1 | Teileliste gleich dem Python-Weg (`ref-a`, `nische-2460`) | RF 1.2, 3.1 |
| `zuschnittplan` | SVG/PDF aus der eigenen Guillotine-Optimierung | 1 | jedes Teil genau einmal; Verschnitt ≤ Referenz | RC 3 |
| `etiketten` | PDF (A4/Rolle) und ZPL; Code 128 mit `nr`, QR mit ID, Kantenbild | 1 | Scan-Test; alle Felder befüllt | RF 6, RC 4 |
| `werkplan` | PDF A3: Plankopf, Grundriss, Ansichten, Schnitte, Stückliste; Darstellung angelehnt an DIN 919-1 (neuer Entwurf 10/2026) | 1 | jede Maßzahl auf der Zeichenliste = Modellmaß; Druck maßstabstreu (Prüfstrecke 100 mm ±0,5) | §3.4, RF 6 |
| `bestellliste` | CSV: Hersteller, Artikel, Menge, Mengeneinheit, Bezug; Kantenmeter je Kantenband | 1 | Summen gleich den Teilen | RF 5, 8 |
| `anschlussplan` | PDF: Wasser, Abwasser, Strom, Abluft, bemaßt ab Ursprung und OKFF; Bestand und geplant getrennt | 2 | jeder Anschluss bemaßt | RP 2.2 |
| `praesentation` | PDF A3 | 3 | – | Python-Weg `praesentation.py` (wird in Stufe 0 abgelegt) |
| `montage` | PDF: Zusammenbau je Schrank (Werkstatt) und Montagefolge (Baustelle: Reihenfolge, Wandbefestigung außerhalb der Installationszone, Sockelfüße, Ausrichten) | 3 | jeder Schritt hat Elemente und Ort | RP 2.2 |
| `dxf` | DXF R12 je Teil/Fläche mit Layer-Presets (z. B. woodWOP-Konvention `Werkstk_19_5`, `V_BohrLS_8`, `T145`); AC1015 nur bei Bedarf | 4 | ezdxf-audit; Re-Import: Lage und Durchmesser aller Bohrungen | RF 3.2, RS 5 |
| `step` | AP214 je Teil und Baugruppe; Quader aus eigenem Code, echte Bohrungen nur über Sidecar (F12) | 4 | Volumen ±0,1 %, Bounding-Box ±0,1 mm gegen Fusion | RC 1, RS 1 |
| `vorschau_3d` | GLB (eigen, auch Linux), USDZ (ModelIO, macOS) | 4 | glTF-Validator | RS 2 |
| `kantenliste` | Kanten je Teil; Barcode → Programm am Kantenanleimer | 6 | Format nicht öffentlich [unsicher] | RF 1.3 |
| `cnc` | MPR nur als Pilot mit Beispieldateien, Werkzeugtabelle und Freigabe der Werkstatt; PTX, BXF, MPRXE nur mit offizieller Partnerdoku | 6 | Freigabe durch den Bediener | RF 8 Nr. 7–8 |
| `ifc` | `IfcFurniture` USERDEFINED | nach Stufe 6 | – | RC 7 |
| `fusion`, `rendering` | Fusion-Adapter mit `fusion_abgleich`; Renderings bleiben in Fusion | 1 | `fusion_abgleich` beider Küchen ohne Abweichung | – |

**Nicht selbst bauen** (RF 8): Profi-Zuschnittoptimierung und Nesting (Cut Rite, Ardis, intelliDivide ab 45 €/Monat), Maschinen-Postprozessoren und Werkzeugverwaltung, Beschlagkonfiguratoren mit Kollisionsprüfung, ERP/EDI, IDM-Kataloge und Etiketten-Designer.

**Grenze beim Zuschnitt**: Unsere Optimierung dient der Vorschau, der Kontrolle und kleinen Aufträgen. An die Säge geht die Liste im Format des Optimierers der Werkstatt. Unser Plan geht nur an die Säge, wenn die Werkstatt keinen eigenen Optimierer hat und ihn freigibt.

### 5.8.1 Planvorlagen, die der Nutzer selbst anpasst

Ziel: Planvorlagen in der App anlegen und ändern, ohne Programmierer. Das Bedienkonzept des Vorlagen-Editors (Feldpalette, Vorschau, Versionen) braucht einen Bogen vom Design-Master (§2.5, L4–L6).

- **Inventar zuerst** (Stufe 0): Alle vorhandenen Studio-Vorlagen kommen in eine Liste mit Zweck, Format, Papier und Feldern. Fertig, wenn jede Vorlage einem `zweck` zugeordnet ist.
- **Vorlage** = Datei + Zweck + Feldliste + Platzhalter für Zeichnungsbereiche (`data-drawing="ansicht_a" data-massstab="1:20"`, §3.3). Maßzahlen kommen aus dem Modell, nie aus Pixeln (§3.4).
- **Zweck** einer Vorlage ist eine Ausgabe aus dem gemeinsamen Vokabular (`werkplan`, `etiketten` …) oder ein Bestandteil (`plankopf`, `schrift`, `marke`). So prüft `ausgeben`, ob die Vorlage zum Ziel passt.
- **Feldkatalog** (Kern, erweiterbar im Setup): `projekt`, `blatt`, `blattzahl`, `inhalt`, `massstab`, `datum`, `revision`, `bearbeiter_rolle`, `stempel_text`, `stempel_farbe`, `material_*`, `geraet_*`.
- **Formate und Escaping** (Mustache allein escapt nur HTML):

| Format (`setup.vorlagen.format`) | Für Nutzer editierbar | Felder | Escaping |
|---|---|---|---|
| `svg_mustache` | ja (Plankopf, Blattrahmen) | `{{feld}}` | XML-Escaping je Feld |
| `html_mustache` | ja (Präsentation, Listen) | `{{feld}}` | HTML-Escaping (Mustache-Standard) |
| `dxf_block` | ja, im CAD (Plankopf-Block mit ATTDEF) | Block-Attribute | DXF-Engine entfernt Zeilenumbrüche und begrenzt die Länge |
| `zpl` | eingeschränkt | Felder der ZPL-Engine | `^FH` mit Hex-Escaping für `^`, `~` und das Kennzeichen `_` selbst |
| `typst_json` | nein (intern) | Daten per `sys.inputs` als JSON, kein Mustache | Typst-Escaping in der Engine |

- **Render-Weg**: Zeichnungen gehen über die Zeichenliste nach CoreGraphics-PDF. Einseitige Blätter aus SVG/HTML werden mit WKWebView `createPDF` und fester Seitengröße erzeugt. Der bekannte Paginierungsfehler betrifft mehrseitige Ausgaben (RS 3) [Einschätzung]; das wird per Test in Stufe 0 geprüft (E14). Typst nur intern für mehrseitige Listen, falls F13 es erlaubt.
- **DWG** ist bis zu einer Lösung mit ODA praktisch ausgeschlossen: Die ODA-Bedingungen sind ungeklärt, und LibreDWG ist GPL (RC 2, RS 5).
- **Stempel** (z. B. Status) ist optional: Ob, Text und Farbe setzt der Nutzer im Setup (`setup.planstempel`); Standard ist aus, und der Stempel ist kein Stilmerkmal.
- **Bemustern** (Lernen aus vorhandenen Plänen), zunächst nur aus PDF:
  - Claude liest eine Studio-Vorlage, baut sie als `svg_mustache` nach, rendert sie mit Beispieldaten und legt Original und Nachbau übereinander (Raster 300 dpi).
  - Fertig, wenn die Linien von Rahmen und Plankopf höchstens 0,5 mm abweichen und jedes Feld des Originals als Platzhalter existiert.
  - Dann bestätigt der Mensch, und die Vorlage geht ins Setup.

### 5.8.2 Zuschnitt

| Parameter | Ort im Schema |
|---|---|
| Plattenformat, Dicke, Faser der Rohplatte, Sichtseiten, Reste | `setup.platten[]` |
| Schnittbreite (Sägeblatt), Besäumung je Seite, Stufenzahl, Stapelhöhe, Vorschub, Maximalformat | `setup.maschinen[].saege` |
| Faser (Laufrichtung) und Drehverbot je Teil, Sichtseite | `teil.faser`, `teil.drehbar`, `teil.sichtseite` |
| Zuschnittmaß (Fertigmaß − Kanten + Fräszugabe) | `teil.zuschnitt` (berechnet vom Kern) |

- Teile mit Faser dürfen nicht gedreht werden; das erzwingt das Schema.
- Der Kern rechnet zuerst mit einer eigenen Guillotine-Heuristik (heute Python `nest()`, später Swift).
- Die bessere Optimierung liefert PackingSolver (MIT, Problemtyp `rectangleguillotine` mit Schnittbreite, Besäumung je Seite, fester Faser, Stufen und Resten; Kanten als 1D-Problem) als Sidecar-Binary, falls F13 es erlaubt (RC 3).
- OpenCutList ist GPL und dient nur als Funktions-Checkliste.

## 5.9 Code-Design: Swift-Kern als ALFA-Modul

Vorgabe des Owners (31.10.2026): zuerst macOS nativ mit Swift-Kern und vielen Integrationen wie bei einer SaaS, später derselbe Kern als Dienst.

### Schnitt in zwei Teile

| Teil | Inhalt | Abhängigkeiten | Lebt |
|---|---|---|---|
| **Paket `Kitchen`** | Model + Logic + Port: Domäne, Werte, Bausteine, Teile, Prüfregeln, Planer, Zuschnitt, Zeichenliste, Erzeuger für SVG, DXF, CSV, ZPL, Code 128, GLB und STEP (Quader), Mustache mit Escaping, Werkzeugkern | keine (nur Foundation, wo möglich `FoundationEssentials`, kein Dispatch) | außerhalb ALFA in einem eigenen Repo; läuft auf macOS, Linux und später als Wasm (RS 9) |
| **ALFA-Modul** (Editoren-Modul, Name nach E1) | Store (GRDB: Modelle, Revisionen, Laufbuch, Bibliothek), Adapter (`PDFClient` CoreGraphics, `PreviewClient` WKWebView, `TypstClient`, `PrinterClient` ZPL, `FusionClient`, `SidecarClient`), State und Views nach Design-Master, Assistant-Tools | GRDB, Paket `Kitchen` (E12) | im ALFA-Repo nach E1/E2 |
| **Executables** `kitchen` (CLI) und `kitchen-mcp` | dieselben Funktionen für Skripte, Golden Master und Claude Desktop/Code | Paket `Kitchen`; `kitchen-mcp` zusätzlich das MCP-Swift-SDK | im Paket, nicht in der App |

ALFA-Regeln, die das Paket von Anfang an einhält (§1.4):
- Namen englisch, ASCII, CamelCase, ohne Modulpräfix und ohne verbotene Wörter.
- Rollensuffixe: reine Umformer heißen `…Engine` (Logic), Ein- und Ausgabe `…Client` (Adapter), Protokolle `…Port`, Speicher `…Store`.
- Starke Dateien mit 200–600 Zeilen, keine Kommentare im Code.
- Ports liegen im konsumierenden Teil: `Kitchen` definiert die Ports, das ALFA-Modul implementiert sie.
- Im ALFA-Assistenten gilt das Muster `MailSearchPort` (§1.2): Der Port liegt im Assistant, die Implementierung ruft den Werkzeugkern von `Kitchen`, registriert wird in der Composition Root. Innerhalb von ALFA braucht der Kern deshalb kein MCP.

```
Kitchen/                        SwiftPM-Paket, ohne fremde Abhängigkeiten
  Sources/Kitchen/
    Model/   Brief (Planungsbogen), Setup, Plan (Küchenmodell), Part, LibraryEntry, Value, Origin, ToolCall
             (aus schema/ erzeugt, E18)
    Logic/   ValueEngine, CabinetEngine, PartEngine, CheckEngine, LayoutEngine, CutEngine, DrawingEngine,
             SVGEngine, DXFEngine, CSVEngine, ZPLEngine, BarcodeEngine, MeshEngine, StepEngine,
             TemplateEngine (Mustache + Escaper je Format), ToolEngine (Register, Schemas, Dispatcher)
    Port/    PDFPort, PreviewPort, TypesetPort, SolverPort, PrinterPort, FusionPort, LibraryPort, PlanStorePort
  Sources/KitchenCommand/       Executable kitchen
  Sources/KitchenServer/        Executable kitchen-mcp (MCP über stdio, meldet sich als Server „kueche“)
  Tests/KitchenTests/           Golden Master, Schema-Roundtrip, je Prüfregel ein roter und ein grüner Fall
```

Grundsätze:
1. **Zeichenliste statt Zeichenprogramm.** Ansichten, Schnitte, Plankopf und Etiketten entstehen als plattformneutrale Liste: Seite, Layer, Linientyp, Strichstärke, Linie, Bogen, Polylinie, Text und Maßkette. Daraus erzeugen die Engines SVG und DXF, der `PDFClient` auf macOS PDF. Das Muster gilt als erprobt [Einschätzung, RS 3].
2. **Möbel sind Quader.** Ansichten, Kollision, Teile, STEP und GLB für achsparallele Quader schreibt der Kern selbst. Was Boolesche Operationen braucht, geht an einen Sidecar oder bleibt in Fusion (E13, F12): STEP mit echten Bohrungen und Nuten, Schrägen, Import fremder STEP-Dateien.
3. **Deterministisch.** Schlüssel werden sortiert und Zahlen fest formatiert, Uhr und IDs sind injiziert.
   - Golden Master entstehen auf Ebene von kanonischem JSON und Zeichenliste, nicht auf PDF- oder STEP-Bytes.
   - PDFs werden per Rastervergleich mit Toleranz geprüft.
   - Solver laufen mit Seed und einem Worker, ihr Ergebnis wird im Modell gespeichert (`solver`).
   - Der Schema-Roundtrip vergleicht semantisch (kanonisches JSON), nicht byte-gleich.
4. **Hilfsprozesse** (R4 der Prüfung): In der Desktop-App laufen nur native Einzelprogramme als eingebettete Helfer mit `inherit` (Typst, PackingSolver-CLI, CP-SAT als C++-CLI), und nur wenn F13 = ja. Python (build123d, OR-Tools über Python) läuft nur in CI, Entwicklung und SaaS. Das Sidecar-Protokoll ist JSON über stdin/stdout mit Protokollversion, Zeitlimit, Vertragstests und gepinnten Versionen.

| Port | Zweck | Adapter (ALFA-Modul bzw. Executable) |
|---|---|---|
| `PDFPort` | Zeichenliste → PDF | `PDFClient` (CoreGraphics) |
| `PreviewPort` | einseitiges SVG/HTML-Blatt → PDF, Vorschau | `PreviewClient` (WKWebView `createPDF`, E14) |
| `TypesetPort` | mehrseitige Listen | `TypstClient` (nur nach F13) |
| `SolverPort` | gekoppelte Layouts, beste Zuschnittpläne, B-Rep | `SidecarClient` (CP-SAT, PackingSolver, build123d) |
| `PrinterPort` | Etiketten | `PrinterClient` (ZPL ans Netzwerk oder in Datei; der Drucker rendert die Codes) |
| `FusionPort` | Übergang, `fusion_abgleich` | `FusionClient` (Fusion-MCP lokal) |
| `LibraryPort`, `PlanStorePort` | Bibliothek, Modelle, Revisionen, Laufbuch | GRDB-Stores in ALFA; JSON-Dateien im CLI; Server-DB im SaaS |

**Abhängigkeiten** (jede einzeln, E12; ALFA erlaubt bisher nur GRDB, §1.3):

| Baustein | Optionen | Vorschlag |
|---|---|---|
| Paket `Kitchen` in ALFA | als zweite Abhängigkeit (eigener Code, ein Stand für App und SaaS) · als Quelltext ins Modul kopiert (regelkonform, aber zwei Stände) | als Abhängigkeit |
| Mustache | eigen 500–900 Zeilen (RS 4) · swift-mustache (Apache-2.0, 0 Abhängigkeiten) | eigen, weil `Kitchen` frei von Abhängigkeiten bleibt; Escaper je Format sind ohnehin eigener Code |
| MCP | MCP-Swift-SDK 0.12.1 (+4–5 Abhängigkeiten) nur im Executable `kitchen-mcp` · eigener Transport 600–1.000 Zeilen | SDK im Executable; eigener Transport nur, falls das SDK scheitert |
| PDF-Satz | CoreGraphics + WKWebView für einseitige Blätter · Typst als Helfer (Apache-2.0) | erst Test (E14), Typst nur nach F13 |
| QR / Data Matrix | CoreImage im ALFA-Adapter · ZPL `^BQ`/`^BX` (der Drucker rendert) · eigener QR-Port 1.000–1.300 Zeilen für Linux | CoreImage + ZPL; Data Matrix nur auf Wunsch der Werkstatt (F5) |
| B-Rep | Fusion · Sidecar build123d/OCCT (nur SaaS/CI) · OCCTSwift (statisch, ~568 MB, nur Apple, LGPL-Pflichten) | Fusion bis F12 entschieden, dann Sidecar |
| Optimierung | eigene Heuristik · OR-Tools- oder PackingSolver-Sidecar · HiGHS als C-Ziel | zuerst eigen |
| DWG | ODA (Commercial ab 3.000 $, dann 2.250 $/Jahr, „limited commercial use“; für die SaaS Sustaining 7.500 $) · LibreDWG (GPLv3, nur Server) | später, nur bei Bedarf |
| Server (SaaS) | Hummingbird 2.x · Vapor 4 (Version 5 noch Beta) | Hummingbird |

Belege: RS 1–9. Alle Zeilenzahlen sind Schätzungen; RS 10 rechnet insgesamt mit 8.000–13.000 Zeilen eigenem Code ohne Tests. Gebaut wird nur, was eine Stufe verlangt. DXF und STEP kommen erst, wenn F2, F3 oder F12 sie fordern (R1 der Prüfung).

**Stufe 1 braucht davon nur** Model, ValueEngine, PartEngine (aus vorhandenen Teilen), CutEngine, DrawingEngine, SVGEngine, CSVEngine, ZPLEngine, BarcodeEngine (Code 128), TemplateEngine, `PDFClient` und `PreviewClient`.

**Typen aus dem Schema** (E18): Die Schema-Feldnamen sind deutsch, ALFA verlangt englische Bezeichner (§1.4). Ein Test in Stufe 0 prüft, ob quicktype alle sieben Schemata mit `$defs` und dateiübergreifenden `$ref` in Swift-Typen übersetzt. Englische Properties bekommen dabei `CodingKeys` auf die deutschen Schlüssel. Gelingt das nicht, werden die Typen von Hand geschrieben und das Schema dient als Test-Orakel (R6 der Prüfung).

**Anbindung an Claude**:
- Übergang: `kitchen-mcp` als eigenes Executable ohne Sandbox. Für Claude Code als stdio-Eintrag, für Claude Desktop als MCPB-Paket (RS 8).
- In ALFA: über den ALFA-Assistenten (siehe oben). Soll Claude Desktop auf ALFA-Daten zugreifen, ist ein eigenes Executable mit App Group und XPC der Vorschlag. Ein Praxisbericht meldet allerdings, dass AMFI sandboxed Einzelprogramme ablehnt, wenn eine fremde App sie startet; Ausweg wäre ein Proxy im Developer-ID-Build (stdio → localhost) (RS 8). **Vor Stufe 5 per Test klären.**
- SaaS: dieselben Ziele plus Streamable HTTP auf Hummingbird; der Browser zeigt vom Server erzeugtes GLB mit three.js (RS 9).

### Integrationskatalog (je Integration ein Port und ein Adapter)

| Integration | Richtung | Format / Weg | Stufe |
|---|---|---|---|
| Optimierer der Werkstatt (Cut Rite, Ardis, intelliDivide) | aus | CSV/XLSX-Presets | 1 |
| Etikettendrucker | aus | ZPL, PDF | 1 |
| Händler, Shop | aus | CSV-Bestellliste; später OCI/openTRANS | 1 / 6 |
| Aufmaß (RoomPlan, DISTO) | ein | RoomPlan-JSON, DXF | 2 |
| Herstellerdaten (Blum, Häfele, Peka, Blanco u. a.) | ein | Import aus CAD, PDF und Katalog in die Bibliothek | 2 |
| Fusion | aus und ein | Fusion-MCP lokal; `fusion_abgleich` | 1–5 |
| CAD/CAM der Werkstatt (imos, HOMAG iX, TopSolid, PaletteCAD) | aus | STEP, DXF (RF 2) | 4 |
| Maschinen (woodWOP-BAZ, Kantenanleimer) | aus | MPR-Pilot, Kantenliste | 6 |
| Ablage (Drive, iCloud, Dropbox, Netzlaufwerk) | ein und aus | ALFA-Dateiordner, Freigabe per Bookmark | 5 |
| Claude | ein und aus | MCP (`kitchen-mcp`) ab Stufe 1, ALFA-Assistent ab Stufe 5 | 1 / 5 |

**Prüfung im CI** (nur dort, nicht ausgeliefert): ezdxf-audit für DXF, OCCT-Import für STEP, glTF-Validator für GLB, `pruefe_schema.py` für alle JSON-Ausgaben (RS Empfehlung).

## 5.10 Werkzeuge (Server `kueche`)

Ein- und Ausgaben stehen als Schema in `schema/werkzeuge.schema.json` (`<name>_ein`, `<name>_aus`); daraus entstehen die MCP-`inputSchema`. Dieselben Werkzeuge bedient die App über den Werkzeugkern. MCP ist also nur eine von zwei Türen.

| Werkzeug | Zweck | Revision |
|---|---|---|
| `bogen_speichern` | Planungsbogen anlegen oder ändern | Bogen +1 |
| `aufmass_importieren` | RoomPlan-JSON, DISTO-DXF oder Messliste in den Bogen; meldet unbestätigte kritische Maße | Bogen +1 |
| `bogen_pruefen` | fehlende Pflichtwerte, Konflikte, offene Fragen | – |
| `werte_aufloesen` | Projekt > Setup > Kern mit Herkunft | – |
| `planen` | 1–3 Varianten mit Scores; `verletzt[]`, wenn keine alle harten Regeln erfüllt | neue Modelle, Revision 1 |
| `element_aendern` | Merge-Patch auf ein Element, meldet Folgen | Modell +1 |
| `teile_ableiten` | Teile, Kanten, Bearbeitungen, Zuschnittmaße | abgeleitet |
| `pruefen` | Befunde F/W/H | abgeleitet |
| `revision_freigeben` | Freigabe für die Fertigung; Eingabe nur `bestaetigt: true`, die Rolle kommt aus der Sitzung | setzt `freigabe` |
| `ausgeben` | Datei(en) zu einem `ziel` aus dem Ausgaben-Vokabular; meldet `weg` (alt/neu) | – |
| `fusion_abgleich` | Abweichungen Fusion ↔ Modell; unbekannte Körper als Kandidaten für `freiform` | – |
| `bib_suchen`, `bib_eintrag`, `bib_importieren` | Bibliothek lesen; Import als `ungeprueft` | – |
| `vorlage_bemustern`, `vorlage_rendern` | Vorlage nachbauen mit Vergleich; Vorlage füllen | – |
| `korrektur_melden`, `regelvorschlaege`, `regel_entscheiden` | Episoden, Vorschläge, Entscheidung (Rolle aus der Sitzung; Bestätigen nur Admin) | Setup bei Bestätigung |

Für alle Werkzeuge:
- **Antworthülle**: entweder `{ergebnis, bericht}` oder `{fehler}`.
- **Fehler** haben einen festen Code: `revision_veraltet`, `nicht_freigegeben`, `fehlend`, `unbekannt`, `ungueltig`, `blockiert`, `zeitlimit`, `keine_berechtigung`.
- **Eingaben sind geschlossen**: Unbekannte Felder sind ein Fehler, so fällt ein Tippfehler auf.
- **Rollen** kommen aus der Identität der Sitzung, nie aus der Eingabe.
- **Fertigungsziele** (`ausgabe_fertigung` im Schema) verweigern eine nicht freigegebene Revision. Ausnahme: ein Werkplan zur Abstimmung, dann aber mit Stempel „nicht freigegeben“.
- **Idempotent** sind reine Funktionen: gleiche Eingabe und gleiche Revision ergeben den gleichen Hash über die kanonische Form. Solver-Ergebnisse werden gespeichert und nicht neu gewürfelt.
- **Ehrlich**: Jede Antwort enthält `bericht.annahmen`. Kein Werkzeug rät Bohrbilder, Gerätemaße oder Maschinenwerte; fehlt etwas, meldet es `fehlend`.
- Jeder Aufruf schreibt eine Laufbuch-Zeile (§5.11). Werkzeuge bekommen Projekt-IDs, nie Namen.

## 5.11 Lernen, wie wir ersetzen

Jeder Lauf schreibt ein **Laufbuch** (JSON Lines) mit diesen Feldern:
- `lauf`, `schritt`
- `wer` (`mensch`, `claude`, `kern`, `adapter:<name>`, `fusion`)
- `werkzeug`
- Hash und Kurzform von Ein- und Ausgabe
- `korrektur` (Schlüssel, alt, neu, Grund)
- `dauer_s`, `tokens`

Drei Lernströme:
1. **Funktionen statt Claude.** Leistet Claude wiederholt dieselbe Umformung (gleiche Ein- und Ausgabestruktur, keine Korrektur), wird daraus eine Kernfunktion. Claude schreibt die Funktion, und der Golden Master aus dem Laufbuch prüft sie. Vorbild ist eine wachsende Bibliothek von Fähigkeiten als ausführbarer Code ([Voyager](https://arxiv.org/abs/2305.16291)).
2. **Adapter statt Fusion.** Jeder Fusion-Lauf liefert Golden Masters: kanonische Körperliste mit Bounding-Boxen, Volumen, Teileliste und Zeichenliste der Ansichten. Ein neuer Adapter läuft im Schattenbetrieb, die Weiche bleibt dabei auf `alt`.
3. **Regeln statt Korrekturen.** Aus einer Korrektur wird eine Episode, daraus eine Setup-Regel und schließlich ein Kern-Kandidat (§5.2). Der Ablauf ist ähnlich wie bei ExpeL, das Einsichten aus Erfahrungen sammelt ([ExpeL](https://arxiv.org/abs/2308.10144)); dort heißen sie nicht „Episoden“, die Analogie ist unsere. Für den Hold-out zählen nur frische Küchen. Die Quote 93,9 % aus Lernrunde 3 (Projektkorpus) ist kontaminiert, weil dieselben Küchen gelernt wurden, und gilt nicht.

**Ablösekriterium (eines für alle Wege)**: Die Weiche geht auf `neu`, wenn zwei Bedingungen erfüllt sind:
- Parität ≥ 0,95 über mindestens 20 Schattenläufe;
- die letzten 3 echten Projekte liegen in Toleranz (Volumen ±0,1 %, Bounding-Box ±0,1 mm, Teileliste gleich).

Weil echte Projekte selten sind, ergänzt ein **synthetischer Testkorpus** von 20 parametrischen Küchen die echten (R5 der Prüfung).

| Kennzahl | Formel | Richtung |
|---|---|---|
| Determinismus | Schritte `kern`/`adapter` ÷ alle Schritte | steigt |
| Parität | Schattenläufe in Toleranz ÷ Schattenläufe | ≥ 0,95 vor dem Umschalten |
| Übernahmequote | übernommene ÷ alle Vorschläge, je Schlüssel | steigt |
| Rückfragen | offene Fragen je Projekt | sinkt, nie durch Raten |
| Nacharbeit | Fertigungsfehler je Projekt (Rückmeldung der Werkstatt) | sinkt |

## 5.12 Stufenplan

Schritt für Schritt: Jede Stufe endet an einem prüfbaren Kriterium. Unabhängige Arbeiten dürfen parallel laufen (Bibliotheken und Prüfregeln aus Stufe 2 neben Stufe 1). „Blockiert bis“ nennt die Entscheidung, ohne die die Stufe nicht startet.

| Stufe | Inhalt | Fertig, wenn |
|---|---|---|
| **0 Vertrag** (begonnen) | Schemata v0.2, Beispiele und Prüfskript ✔. Dazu: Golden Masters aus `ref-a` und `nische-2460` sichern (Teileliste, Zuschnitt-CSV, Plan-PDF, STEP, Körperliste) samt Python-Skripten des alten Wegs; beide Küchen als `kuechenmodell` ausdrücken; Vorlagen-Inventar; minimale Einträge für Material und Kante; Tests zu quicktype (E18) und Einseiten-PDF (E14) | `pruefe_schema.py` grün ✔; beide Küchen gültig und I1–I8 grün; Golden Masters mit Hash abgelegt; jede Vorlage hat einen `zweck`; alle in Stufe 1 genutzten Bibliothekseinträge sind `geprueft`; **E12, E14, E18 und F13 entschieden** |
| **1 Zuschnitt, Etiketten, Pläne** | Swift-Paket `Kitchen` (Teil Stufe 1, §5.9) liest `kuechenmodell` und erzeugt Zuschnittliste, Zuschnittplan, Etiketten (PDF, ZPL), Werkplan und Bestellliste mit Kantenmetern. `kitchen` und `kitchen-mcp` mit den Werkzeugen dieser Stufe. `fusion_abgleich` für beide Küchen. Eine Studio-Vorlage bemustern. Weiche steht auf `alt`, Schattenbetrieb | Für beide Küchen: Teileliste gleich dem Python-Weg; jedes Teil im Zuschnitt genau einmal; Verschnitt ≤ Python-Weg; jede Maßzahl der Zeichenliste = Modellmaß; Druck maßstabstreu; Bemusterung ≤ 0,5 mm; `fusion_abgleich` ohne Abweichung. **Blockiert bis E12, E14, E18** |
| **2 Bibliotheken + Prüfung** | Bibliotheksdienst mit Einträgen für Material, Kante, Beschlag (Blum, Häfele, Peka), Geräte und Spülen (Blanco), je mit Quelle und Lizenz. Prüfregister KOL, ABS, GER, ANS, FER, VOL. Anschlussplan. Aufmaß-Import | Jeder genutzte Eintrag hat Quelle und Status; je Regel ein roter und ein grüner Testfall; beide Küchen geprüft, der Mensch hat die Befunde bestätigt |
| **3 Bausteine + Planer** | Bausteine Unterschrank, Hochschrank, Arbeitsplatte, Sockel, Passleiste, Schubkasten (Herstellerregeln) und Geräte; `teile_ableiten`; Planer für Zeile und Nische; Präsentation und Montage | Die Teile aus dem Kern sind gleich denen aus Fusion (Golden Master), für beide Küchen; der Planer findet die gebaute Nischenküche unter seinen Varianten (gleiche Modulfolge, Breiten ±1 mm). L, U und Insel nur bei F13 = ja (CP-SAT-CLI), sonst im SaaS |
| **4 Geometrie** | DXF R12 je Teil mit Layer-Preset, STEP für Quader, GLB/USDZ-Vorschau; echte Bohrungen im STEP nur über Sidecar | Ablösekriterium §5.11 erfüllt; DXF besteht ezdxf-audit und Re-Import. **Startet erst, wenn F2, F3 oder F12 es verlangen** |
| **5 App + Werkzeuge** | ALFA-Modul mit Stores, Adaptern, Ablage (Dateiordner per Bookmark) und Assistant-Tools; `kitchen-mcp` vollständig; Skills schlank | Claude plant eine Küche nur über die Werkzeuge; Fusion nur noch für Rendering und Sonderformen. **Blockiert bis E1, E2, E12, Design-Bögen (§2.5) und AMFI-Test** |
| **6 Werkstatt + SaaS** | CNC-Pilot, Kantenliste, Bestellung per OCI, Kern als Dienst auf Linux | Werkstatt gibt ein Programm frei; derselbe Golden Master (kanonisches JSON, Zeichenliste) auf macOS und Linux. **Blockiert bis E15, F2, F3** |

## 5.13 Entscheidungen und offene Fragen

Entscheidungen (Fortsetzung von §4):

| Nr | Frage | Optionen | Beleg |
|---|---|---|---|
| E11 | Paket- und Modulname | `Kitchen` (Paket) + Editoren-Modul in ALFA (Vorschlag) · andere Namen | §5.9, §1.4, E1 |
| E12 | Abhängigkeiten über GRDB hinaus | Paket `Kitchen` als Abhängigkeit (Vorschlag) · als Kopie; MCP-SDK nur im Executable | §5.9, §1.3 |
| E13 | B-Rep-Weg für STEP mit echten Bohrungen | Fusion bleibt · Sidecar build123d/OCCT (nur SaaS/CI) · OCCT in der App | §5.9, RC 1, RS 1 |
| E14 | Render-Weg für Planvorlagen | CoreGraphics + WKWebView für einseitige Blätter (Vorschlag, nach Test) · Typst-Helfer · beides | §5.8.1, RS 3 |
| E15 | CNC-Ausgaben | keine · DXF-Presets · MPR-Pilot | RF 8 |
| E16 | Partnerprogramme für die SaaS (Blum, HOMAG/tapio) | jetzt anfragen · später | RF 4, RF 9 |
| E17 | Vertriebsweg der App | Developer ID zuerst (Vorschlag) · Mac App Store | RS 8 |
| E18 | Sprache der Schema-Feldnamen | deutsch mit `CodingKeys` auf englische Swift-Properties · jetzt auf Englisch umstellen (billigster Zeitpunkt, deutsche Titel im Schema) | §1.4, §5.9 |

Offene Fragen (zusammengeführt aus RF 9, RP (d), RS, Prüfbericht):

| Nr | Frage | Wer klärt |
|---|---|---|
| F1 | Normoriginale DIN EN 1116, DIN 18015-2 (Tabelle 2) und DIN 18040-2 beschaffen; Zugang über DIN Media oder die Kammer? | Owner |
| F2 | Welche Werkstatt(en), welche Säge, welches BAZ, welche Software (Cut Rite, intelliDivide, Ardis, imos, PaletteCAD …)? Gibt es Beispieldateien (Teileliste, DXF, MPR, Etikett)? | Owner + Werkstatt |
| F3 | Will die Werkstatt CNC-Daten von uns oder Listen, Zeichnungen und STEP? Wer haftet? | Owner + Werkstatt |
| F4 | Konstruktionsregeln der Werkstatt: System 32, Verbinder, Rückwandnut, Kantenstärken, Plattenformate | Werkstatt → Setup |
| F5 | Etikettendrucker (Typ, Etikettengröße), gewünschte Felder, Data Matrix nötig? | Werkstatt |
| F6 | Händler für Beschläge; gibt es OCI oder einen Shop-Import? | Owner |
| F7 | CAD-Daten von Peka (Service-Seite) und Blanco: Formate und Nutzungsbedingungen | Recherche/Anfrage |
| F8 | Elektro und Gas nur als Hinweis; wird überhaupt mit Gas geplant? (TRGI nicht recherchiert) | Owner |
| F9 | Ellenbogenhöhe und Händigkeit im Briefing erfassen? (Regel ERG-01) | Owner |
| F10 | RoomPlan-Genauigkeit: 3–5 Küchen gegen Lasermaße testen | Stufe 2 |
| F11 | `nische-2460`: OK Arbeitsplatte 885 oder 910? (im Beispiel als offene Frage mit Annahme 910) | Owner |
| F12 | Muss STEP Bohrungen und Nuten als echte Geometrie enthalten, oder reichen Quader plus Bearbeitungsliste? | Owner + Werkstatt |
| F13 | Dürfen native Hilfsprogramme in der Desktop-App laufen (Typst, PackingSolver, Solver)? Python nur im SaaS? | Owner |
| F14 | Volumen: Küchen und Möbel pro Jahr (entscheidet über Stufe 4 und 6) | Owner |

## 5.14 Quellen

Recherchen (Beilagen mit allen URLs): RF, RC, RP, RS, RN in `recherche/`. Unabhängige Prüfungen: `recherche/pruefbericht_v0_1.md` (zu Version 0.1) und `recherche/nachpruefung_v0_2.md` (zu Version 0.2). Ihre Befunde B1–B11 und C1–C21 sind eingearbeitet, mit zwei Ausnahmen:
- Ein eigenes Schema für Bestellpositionen fehlt; Stufe 1 bildet die Bestellliste aus Teilen und Bibliothek.
- Das Prüfskript vergleicht Negativfälle über Mindestmarker statt über exakte Mengen; zusätzliche Befunde werden angezeigt, aber nicht bewertet.

Direkt zitiert:
- Strangler Fig: https://martinfowler.com/bliki/StranglerFigApplication.html
- Characterization test / Golden Master: https://en.wikipedia.org/wiki/Characterization_test
- Skills-Grenzen der API: https://platform.claude.com/docs/en/api/skills-guide
- Voyager (Fähigkeiten als Code-Bibliothek): https://arxiv.org/abs/2305.16291
- ExpeL (Lernen aus Erfahrungen): https://arxiv.org/abs/2308.10144
- Swift 6 (Foundation auf allen Plattformen, statisches Linux-SDK): https://www.swift.org/blog/announcing-swift-6/
- OCCT-Lizenz (LGPL 2.1 + Open-CASCADE-Ausnahme): https://occt3d.com/dev/content/open-cascade-technology-changes-its-license-gnu-lgpl/index.html
- Peka Smart Storage (04/2023): https://peka.com/tradepro/shopen/artikel/allgemein/Brochure-Smart-Storage-peka-EXP-ENG.pdf
- Peka Montageanleitung Pleno Maxi: https://peka.com/tradepro/shopes/artikel/allgemein/Montageanleitung_Hochschrank_Pleno_Maxi_peka_950.0828.MA.pdf
- Blanco-Ausschnittschablone (Beispiel): https://cdn.blanco.com/assets/hlr-system/TKD/PDF-Dokumente/141536_Schablone_STYLE.pdf
