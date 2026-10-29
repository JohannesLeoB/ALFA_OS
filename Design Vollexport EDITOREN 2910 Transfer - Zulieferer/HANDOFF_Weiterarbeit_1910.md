# Handoff Weiterarbeit · ALFA OS Editoren · Stand 19.10.2026

Ablage im Projekt statt `$TMPDIR` (das Werkzeug schreibt nur ins Projekt). Nichts wurde geliefert, kein ZIP, kein Export (Regel 4).
Dieses Dokument wiederholt nicht, was schon steht. Verweise: `HANDOFF_Editoren_1810.md` (Abschnitte 8a bis 8q), `MASTER_LESEPROTOKOLL.md` (was vom Master gelesen ist), `NACHFOLGE_PROMPT.md` (Regeln 1 bis 8 und Lesereihenfolge), `github.md` (Repo-Verknüpfung).

## 0 · Regeln, die gebrochen wurden (nie wieder)
1. „Gelesen“ nur melden mit Zeilen gelesen / Gesamt je Datei. Gleiche Dateien (Byte-Vergleich) beweisen keine Übernahme. Johannes 19.10.: „Das darf NIE passieren!“
2. Der neueste Master gilt. Aktuell liegt nur Export 18.10. vor; Johannes hat Teile eines neueren Stands (19.10.) eingefügt.
3. Keine Annahme als Beleg ausgeben (Menübreiten, „alle anderen liegen auf Token-Werten“ war nicht geprüft).
4. Regel 5: keine Stapelkarten. Die rechte Bahn der Editoren ist eine Karte mit Reiterleiste.

## 1 · Fragen an Johannes, unbeantwortet
| Nr | Frage | Beleg |
|---|---|---|
| F1 | Signalrot: Master nutzt es für Fehler und Destruktives, Warnungen sind ink-2 (Mail Z. 1043, AUDIT.md §2.5). Editoren nutzen Signalrot für Warnungen (Konfigurator „Prüfung“, Aufmaß „nicht kalibriert“, Foto-Check, Durchgang, Planvergleich-Funde). Angleichen? Planvergleich ist von dir gesehen. | 8l, 8n |
| F2 | Menüzeilenradius 8 (Mail Z. 350) oder 12 (radius.contextMenu-Kommentar). Master widerspricht sich. | 8l |
| F3 | Eigene Bauteile der Editoren ins Mastersystem? Kontextleiste (40 hoch), schwebende Palette (Radius 12), Ebenenfeld links unten, Kachelraster. Formular wurde geschlossen; du hast gesagt: „trage deine Bauten da aber noch nicht ein“. Bleibt also Entwurf. | 8m |
| F4 | Reiterleiste statt Kartenstapel in allen Editoren bestätigen. | 8m |
| F5 | Planvergleich: Ausrichtung der Pläne (Raster, Passmarken, OCR) und Schwelle ab wann ein Fund gilt: „unbekannt“. Ausgabe PDF und Excel ist beantwortet, Architektur „Code-Sache“. | 8, 8b |
| F6 | „In Kopf bitte“ (Kommentar zur Werkzeugliste): Kontextleiste oder nur festhalten? Unklar. | 8b |
| F7 | Ersatzname für Dateiendungen `mykaufmass.json`, `mykcad.json` und Gewerk `mykilos` (Repo-Regel: „myk“ verboten). | 8c |
| F8 | Aufmaß-Menü 140 breit ja oder nein: Annahme wurde auf 168 bis 280 geklemmt. | 8p |
| F9 | Hub: gemeinsame Materials/Creative-Dateien und Datenbanken für alle Editoren. Bedienung unbekannt. Soll der Hub als eigener Bogen entworfen werden? | 8 |

## 2 · Master: nicht oder nur teilweise gelesen
- Neuer Stand 19.10. (Brief v9, Status `designSet`): liegt nicht vor. Erwartet: `TOKENBOGEN.json`, `alfa-theme.css`, `alfa-shell.js`, `ALFA Shell.dc.html`, `ALFA Mail.dc.html`, Vertragsordner `contract/`. Danach alles vollständig lesen, Editoren abgleichen.
- `werte-abgleich.json` (23960 Z.): NICHT gelesen, nur Struktur ausgegeben (Schlüssel zusammenfassung, werte 1923, logik, rolleTemplate).
- `TOKENBOGEN.json`: Rohtext nur Z. 1 bis 2000; alle Tokens als Skriptliste gelesen. `stack`, `surface` (Lack, Glas) nur gekürzt.
- `ALFA Mail.dc.html`: Z. 74, 231, 358 zeigt das Werkzeug gekürzt.
- Altcode (Repo `JohannesLeoB/ALFA_OS`): 42 Domain-Dateien gelesen, nicht gelesen: `LeicaDistoBluetoothAdapter`, `LaserDiagnoseScanner`, Moodboard-/Papers-Typen, Feature-Verzeichnis `alfaos/Kit` (84 Dateien), Rest `Domain` (98 Dateien). SwiftUI-Views liegen nicht im Repo: Bedienabläufe unbekannt.

## 3 · Neue Master-Werte (19.10., aus Johannes' Text), noch nicht eingebaut
`size.menuMinWidth` 168 und `size.menuMaxWidth` 280 (nur diese zwei sind eingebaut: Klemme in `openMenu`/`openMenuAt`). Offen: `size.focusRingOffset` 1 (alfa-theme.css fehlt), `layer.*` (lane 1, handle 2, syncButton 3, toast 4, menu 5, safeArea 7, inLane.overview 2, inLane.toast 3), `scale.pressTile` 0,98, `opacity.cardMeta` 0,72 und `cardMetaDeep` 0,95, `typography.textStyle.*`, `typography.tracking.*` (control 0,01, mark 0,06, markSmall 0,04, orbInitials 0,08, title −0,02), `shadow.*.stackFront/stackBack`, `motion.duration.scrollLineIn/Rest/Out` (320/420/900), `size.reelTopOffset` 8, `size.settingsTileHeight/MinWidth` 112, `size.tileHoverLift`.

## 4 · Offene Fehler, Lücken und Annahmen in den Editoren
Moodboard, Aufmaß, Atelier, Planvergleich, Konfigurator (je `ALFA …dc.html`; Vorgängerfassungen `… v1`).
- **Ineffektiver Code:** In Atelier, Aufmaß, Konfigurator, Moodboard steht `stackCards0` mit Kartenstapel-Logik, `stackCards()` überschreibt sie auf eine Karte. Korrekturen daran (Köpfe 8, 5 Stufen, Schatten) sind wirkungslos. Entscheiden: entfernen.
- **Hülle vs. Master:** Blob-Menü-Gruppen der Editoren enthalten „Kreativ“ (Moodboard, Aufmaß, Atelier, Planvergleich, Konfigurator). Master kennt nur Kommunikation/Mail und Kern/Einstellungen. Vertrag nennt zusätzlich Heute, Projekte, Katalog, Werkstatt, Studio (INHALT.json). Zuordnung der Editoren zu „Studio“ unbekannt.
- **Attrappen:** Foto selbst (Platzhalter), Laser-Bluetooth, Ausgabe PDF/SVG/DXF/DWG/HTML, Projektdatei, Vorlagen laden, Hub-Quellen (Aufmaß). Render, Engines außer Firefly manuell, Bildquellen (Atelier). 3D, DXF/SVG real, Preise (Katalog fehlt) (Konfigurator).
- **Aufmaß:** Ebenenfarben im Altcode sind Token-Namen (critical, cash, positive, drive, tasks, personal, team1 bis 3, brand), Entwurf nutzt eigene Farben. Schriftgröße je Ebene Standard 9 fehlt. DIN-Zuordnung der Symbole unbekannt.
- **Atelier:** Obergrenze der Ebenen unbekannt. Ebenenfarben eigene. Slot-Farben aus Namen abgeleitet (Ultramarin, Terracotta, Salbei, Ocker, Graphit, Taube). Wortlaut der Prompt-Verbote unbekannt. „Nur ein Master je Skizze“ ist Annahme.
- **Konfigurator:** Nischenmaße unbekannt für Wärmeschublade, Kaffeevollautomat, Kochfeld, Dunstabzug; Richtwerte für Backofen, Mikrowelle, Kühlschrank, Geschirrspüler. Fachhöhen der Vorlagen (800/1260/560) nicht abgebildet. Entwurfsideen ohne Altcode-Beleg: Passblende bis 150, Zeile gegen Wand, Wandschränke über Zeile, Fächerhöhe, Gerät-Modulbreite. Plattenstärke 40, Überstand 20, Zuschnittmaße (19/8/16/655/970) sind Annahmen.
- **Planvergleich:** Palettenkarten (Baudokumentation, Kommentare, Ebenenfilter, Zeichentools) und Werkzeugkopf (Maße, Foto-Canvas auf Blattuntergrund, DWG/DXF/SVG/HTML, Laser, DIN-Symbole) nicht gebaut. Kachelraster „Pläne“ ist nur Platzhalter ohne Vorschau. Rechte Bahn hat „Funde“ und „Ebenen“ als Reiter. Kein Altcode für Planvergleich; nur Plan-Sammler (pdf, jpg, png, heic, tiff, webp; keine dwg/dxf).
- **Moodboard:** Altcode nicht gelesen (kein Typ gefunden). Drehgriff 11 px und −26 px ohne Token. Raster-Overlay mit fest `rgba(179,65,46,…)` statt Token. Eigene Listenzeilen 44 hoch.
- **⌘-Kürzel:** nur noch in der Hilfeliste „Kurzbefehle“ (je ein Menü pro Editor, drei Stellen). Johannes 13.10.: „Habe ich gesagt, ich will irgendwelche cmd+X oder sowas auf der UI?“ Entscheiden, ob die Hilfeliste bleibt.
- **Fest eingestellte Breiten** der Kontextleisten-Felder (56 bis 220 px) ohne Token.
- **Rollenprüfung** (Wert gleich ≠ Bedeutung gleich) und Dunkelmodus der Editoren: nicht geprüft. Kein Worst-Case-Schalter in den Editoren (der Master hat `daten`).
- **Stilllegen/Aufräumen:** `ALFA Bestaetigen.dc.html` im Projekt (13665 Z.) weicht vom Export (10432 Z.) ab, unangetastet. Ältere Fassungen: `ALFA Moodboard v1`, `ALFA Atelier v1`, `ALFA Aufmass v1`. `image-slot.js` im Projekt wird nur vom Atelier-Katalog-Rest genutzt.

## 5 · Undefinierte Token / Bauelemente (kein Master-Gegenstück)
| Element | Wert | Wo |
|---|---|---|
| Kontextleiste | Höhe 40, Abstand 12, Innenrand 16 | alle Editoren |
| Werkzeugpalette (schwebend) | Radius 12, Innenrand 0 8 8, Schatten `--sh-float`, z-index 6, Handle 16 hoch | alle Editoren |
| Werkzeug-Flyout (Symbole, Fach-Typen) | Breite 232, Radius 16, z-index 8 | Aufmaß, Konfigurator |
| Ebenenfeld links | max. 42 % Höhe, Kopf 40 | Atelier, Aufmaß, Konfigurator |
| Kachelraster (Planvergleich, Atelier-Katalog) | Seitenverhältnis 4/3, Radius 8 | Planvergleich |
| Blatt (A3 quer) | 1400 × 990, Schriftfeld 15/24 | Aufmaß |
| Zoom | 1 bis 12 (Aufmaß, Altcode), 0,5 bis 4 (Planvergleich, eigene) | Editoren |
| Status-Pille unten links | 24 hoch, Innenrand 8 | Atelier, Aufmaß, Konfigurator |
| Welt-Beschriftungen | 11,5 / Zeilenhöhe 20, Kapsel 999 | Editoren |
Farben ohne Token: `LCOL`, `SLOT`, `ZCOL`, `MATC`, `TONE`, Ebenenpalette, Moodboard-Palette (`PAL0`). Keine Herkunft im Master (nur Mood-Farben coral, apricot, rose für Stapel und Typen).
Icons: Master `INHALT.json` symbole (Pfade 16er-Raster, Strich 1,3): Editoren verwenden eigene Pfade (`XP`, `FTI`, `P` mit Erweiterungen) für select, hand, pen, poly, rect, fill, erase, img, note, grid, dim, auto, persp, laser, ruler, eye, eyeoff, unlock, Fach-Typen (tuer, schub, regal, boeden, blende, geraet, spuele, muell, leer), Installationssymbole (11). Nicht im Master-Verzeichnis.
Schrift: Geist 300/400/500, 600 nur in der Mail (Master-Widerspruch). Editoren nutzen 500 und 400.

## 6 · Nächste Schritte (Reihenfolge)
1. Neuen Master (19.10.) laden, vollständig lesen, Leseprotokoll fortschreiben.
2. F1 und F2 von Johannes holen, dann Signalrot und Radius angleichen.
3. `alfa-theme.css`, Shell, Tokenbogen des neuen Standes übernehmen; Editoren auf `layer.*`, `scale.pressTile`, `opacity.cardMeta`, Fokusabstand prüfen.
4. `werte-abgleich.json` lesen (Struktur: zusammenfassung, werte, logik, rolleTemplate) und gegen die Editoren halten.
5. Rollenprüfung aller Editor-Werte (nicht nur px/ms).
6. `stackCards0` aus den Editoren entfernen (nach Freigabe).
7. Planvergleich: Palettenkarten und Werkzeugkopf (nach F5, F6).
8. Hub-Bogen (F9).
9. Altcode: noch nicht gelesene Dateien lesen; Moodboard, Planvergleich, Konfigurator-Fachhöhen nachziehen.
10. Worst-Case-Schalter in den Editoren (SKILL break-ui, CATALOG).

## 7 · Empfohlene Skills für die nächste Sitzung
Frontend design (nur für Editor-Entwürfe, im ALFA-Stil), break-ui (Worst-Case-Daten, liegt als `uploads/SKILL.md`), handoff, Make tweakable (nur auf Anfrage).
