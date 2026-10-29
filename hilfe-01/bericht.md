# HILFE-01 · Bericht

Abgleich Brief Werkstatt 29.10. (BR) gegen Editoren-Entwürfe (ED) und Archiv (AR). Stand 29.10.2026. Ergebnis **ungeprüft**.

Dateien: `abgleich.json` (51 Einträge), `leseprotokoll.md`, je Bereich Einzelheiten in `bereiche/*.md` (Offene Punkte, Neue Symbole, Bausteine). Die Regelprüfung aus `00-LIES-MICH.md` steht in `bereiche/lies-mich.md`.

## Zählung je Bereich

„Erfunden“ zählt die Einträge in `erfunden_ed`, nicht die Funktionen.

| Bereich | gezeichnet | teilweise | fehlt | erfunden |
|---|---|---|---|---|
| Projekte (P1–P11) | 0 | 0 | 11 | 8 |
| Bemusterung (B1–B4) | 0 | 0 | 4 | 4 |
| Aufmaß (Daten, A1–A8, A3.auto, A3.laser, Sammeleintrag „ohne“) | 1 | 10 | 1 („ohne“, keine Funktion) | 34 |
| Atelier (S1–S8) | 2 | 5 | 1 | 15 |
| Konfigurator (K1–K7) | 2 | 5 | 0 | 19 |
| Plan (L1–L5) | 2 | 2 | 1 | 29 |
| Moodboard (M1–M4) | 0 | 4 | 0 | 17 |

- Projekte und Bemusterung haben keinen Bogen in ED. Die ED-Gruppe „Kreativ“ nennt keine Bemusterung (`ALFA Planvergleich.dc.html:148`).
- Die Liste in `HANDOFF_Weiterarbeit_2110.md:39` betrifft nur Draws. Von den 29 erfundenen Plan-Einträgen stehen 14 dort. Aus allen anderen Bereichen steht nur ein kleiner Teil dort, und zwar nur dann, wenn das Element auch in Draws vorkommt.

## Die fünf wichtigsten Abweichungen

1. **Firmenname fest im Bogen.** BR: „Firmenname und Logo kommen aus der Firmenkonfiguration, nie fest.“ (`07-moodboard.md:41`, Regel `00-LIES-MICH.md:68`). ED: „Studio Brenner“ im Formatnamen und in den Beispiel-Logos (`ALFA Moodboard.dc.html:325`, `:344`, `:345`).
2. **Layer löschen.** BR: „Wird ein Layer gelöscht, bleiben seine Maße ohne Layer erhalten.“ (`03-aufmass.md:34`); AR stimmt mit BR überein (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/AufmassModell.swift:210`). ED verschiebt den Inhalt auf eine andere Ebene und verbietet das Löschen der letzten Ebene: „Mindestens eine Ebene“ (`ALFA Aufmass.dc.html:534`).
3. **Konfigurator-Kürzel.** BR: `or`, `fa`, `mu`, `wm`, `kf`, `le` …; „Ohne Breite gelten 600 mm.“ (`05-konfigurator.md:89–94`). ED: `r`, `b`, `m`, `g` …, Spüle 800 und Müll 450 als Vorgabebreite (`ALFA Konfigurator.dc.html:342`).
4. **Isometrie-Winkel.** BR: „Isometrie: 30°“ (`06-plan.md:13`); AR `isoWinkel = .pi / 6` (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/PlanProjektion.swift:59`). ED Draws: freie Regler, Azimut 0–355°, Elevation 0–90° (`ALFA Draws.dc.html:126`, `:147`, `:464`).
5. **Maßanker im Atelier fehlt.** BR: „Strecke ziehen, mm-Wert und Bezeichnung eingeben“ (`04-atelier.md:75`). ED: kein Werkzeug dafür, die Prompt-Geometrie hat kein Maß (`ALFA Atelier.dc.html:548`). AR schreibt Maße in den Prompt (`archive/before-rebuild:fundus/alpha/Sources/AlfaKit/Domain/Skizze/PromptKompilierer.swift:41`).

Weitere Abweichungen derselben Schwere stehen in `bereiche/*.md` unter „Fünf wichtigste Abweichungen“. Darunter sind „Maße ohne Kalibrierung mit Zahl“ (`03-aufmass.md:19` ↔ `ALFA Aufmass.dc.html:506`), „Tausenderpunkt“ (`03-aufmass.md:43` ↔ `ALFA Aufmass.dc.html:419`) und „Planvergleich Rand 88 statt 48“ (`06-plan.md:26` ↔ `ALFA Planvergleich.dc.html:213`).

## Regeln aus 00-LIES-MICH (Kurzfassung, Stellen in `bereiche/lies-mich.md`)

- Die zwei Entscheidungen von Johannes stehen in `00-LIES-MICH.md:114` und `:115`. Die Reihenfolge steht als Vorschlag in `:116`.
- ED hält nicht ein: Token, Textschlüssel, Firmenwerte als feste Texte (nur „Anrede“ ja), keine Erklärsätze (alle sechs Bögen), fehlender Wert bleibt leer, ein gemeinsames Editoren-Modul.
- ED hält ein: „Rückgängig statt Frage“. „Hängt an einem Projekt“ ja in drei Bögen, für Moodboard unklar.
- N20 (nie ausgegraut, nur für Mail entschieden): ED graut in Atelier, Moodboard und Draws aus.

## Grenzen dieses Ergebnisses

- In den Bereichen Projekte, Bemusterung und bei der Regelprüfung wurden die Bögen per Suche geprüft, nicht ganz gelesen. Erklärsätze außerhalb der gesuchten Muster können fehlen (siehe `leseprotokoll.md`).
- Gegen die Quellen geprüft wurden sieben Stichproben: Abweichungen 1–4 oben, Tausenderpunkt, Rand 88/48, `isoWinkel`. Alle trafen zu. Alles Übrige ist nicht nachgeprüft.
