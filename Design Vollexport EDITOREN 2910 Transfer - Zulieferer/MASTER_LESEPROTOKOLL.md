# Leseprotokoll Master „ALFA OS Interface CHEF 1610-handoff 1810“ (Export 18.10.2026)
Angelegt 19.10.2026 auf Johannes' Rüge: Master nicht voll gelesen. Dieses Protokoll nennt je Datei Zeilen gelesen / Gesamt. Nichts wird als gelesen gemeldet, was hier nicht steht.

## Gelesen ganz
| Datei | Zeilen |
|---|---|
| ABNAHME.md | 37/37 |
| AUDIT.md | 62/62 |
| CLAUDE.md | 11/11 |
| RUECKGABE-AN-CODE.md | 97/97 |
| UEBERGABE-NAECHSTER-CHAT.md | 62/62 |
| entscheidungen.md | 269/269 |
| ALFA Tokenbogen.dc.html | 57/57 |
| ALFA Einstellungen.dc.html | 25/25 (eine Zeile von mir gekürzt gesehen: data-props, 2509 Zeichen) |
| ALFA Bestaetigen.dc.html | 106/106 |
| ALFA Huelle.dc.html | 113/113 |
| ALFA Designsystem.dc.html | 121/121 |
| ALFA Entscheidungen.dc.html | 95/95 |
| ALFA Dienste.dc.html | 139/139 |
| ALFA Farbsystem.dc.html | 155/155 |
| ALFA Shell.dc.html | 243/243 |
| alfa-shell.js | 77/77 |
| alfa-theme.css | 14/14 |
| ALFA Mail.dc.html | 1093/1093. Einschränkung: das Lesewerkzeug kürzt einzelne überlange Zeilen in der Anzeige (Z. 74 Kachelzeile Ende, Z. 231 Personenzeile Ende, Z. 358 data-props Ende; je Hinweis „line truncated“). Diese Restzeichen habe ich nicht gesehen. |

| TOKENBOGEN.json | Z. 1–2000 roh gelesen (Anfang der Session); gesamte Datei zusätzlich als Liste aller 349 Werte und aller 321 Tokens mit Beschreibung, Beleg, Status, formerName, where vollständig gelesen (Skriptausgabe, nicht Rohtext). Gelesen: Farben, Schatten, size, radius, spacing, typography, motion, component, confirm, count, opacity. Stack/lacquer/glass nur gekürzt gesehen. |
| lieferung-an-code/motion-springs.json | 435/435 |
| uploads/SKILL.md (break-ui) | 176/176 |
| design-system/alfa-ds.css | 247/247 |
| design-system/alfa-ds-tokens.js | 153/153 |
| lieferung-an-code/akte.json | 189/189 |
| lieferung-an-code/decisions.json | 105/105 |
| lieferung-an-code/settings-sections.json | 109/109 |
| github.md (Master) | 20/20 |
| uploads/AN-DESIGN-LIEFERUNG-15.md | 46/46 |
| uploads/CATALOG.md | 136/136 |
| README.md (Export) | 23/23 (zu Beginn der Session) |

## Weitere Befunde (akte.json, decisions.json, AN-DESIGN-LIEFERUNG-15.md)
- Der Master führt nur Mail und Einstellungen als App-Ansichten (akte.json seiten). Editoren (Moodboard, Aufmaß, Atelier, Planvergleich, Konfigurator) sind im Master nicht enthalten; sie sind eigene Entwürfe auf der Hülle. Dienste und Farbsystem sind „Referenzbogen“ bzw. „Vorschlag, nicht entschieden“: Farben daraus nicht übernehmen.
- Freigabe Orange (vorläufig abgenommen): confirm.*, confirmHold/Release, color.dark.onSignal #0d0d0d, size.trailingTextInset 12.
- Der Master hält 78 Tokens „von-design-gesetzt“ offen; keine Werte aus ihnen als „entschieden“ ausgeben.
- Widersprüche im Master selbst (nicht von mir zu lösen): focusRingOffset 2 (alfa-theme.css:6) gegen 1 (Bestaetigen); weight.semibold 600 gegen gelieferte Schnitte 300/400/500; Menüzeilenradius 8 (Mail Z. 350) gegen radius.contextMenu-Kommentar „Zeile 12 + Rand 4“.
- Code übernimmt Maße von Design (17.10.). Tokens kommen nur von Design.

## Befunde ALFA Mail.dc.html (alle Z. gelesen)
- Symbolknopf Liste/Kopf: Hover Farbe ink + Ring ink-3, Übergang color,box-shadow 160 ms (Z. 18). Karten-Kopf-Symbolknopf: Hover Hintergrund var(--c-hover) (Z. 147).
- Textknopf: 24 hoch (Suchfeld, Z. 41), 28 hoch (Hinweise, Z. 56). Schrift 11.5/500, Ring line-strong, Hover Fläche. Destruktiv: Ring und Schrift signal (Z. 111).
- Eingabe in Karten-Zeilen: ohne Rahmen, rechtsbündig, Innenrand rechts 12 (Z. 288). Eingabe-Feld in Liste: Unterstrich 1 px ink (Z. 39).
- Karten-Hinweis: Radius 8, Hintergrund well, Marke 28 mit Ring in Zustandsfarbe, Abstand 20 (Z. 54).
- Kartenstapel: article Radius 20 20 0 0, Schatten c.sh, Kopf 44 mit Linie, Fuß 44 (Z. 136–302).
- Kopf-Leiste rechts: Befehle links, Hinweis Mitte, Mehr/Übersicht/Falten/Größe rechts; Schaltflächen fallen nach Priorität in „Mehr“ (Z. 1018–1050). Beschriftung erst ab Kartenbreite 300 (Senden), Bruchstellen 440/480 (TOKENBOGEN size.breakpoint*).
- Schriftgrößen 11.5 und 13; Gewicht 300/400/500, 600 nur Absender ungelesen und Menüwahl.
- Tastenkürzel: Mail hat Tasten (cmdKey Z. 633–647: ⌘N, ⌘↩, ⌘S, ⌘P, ⌘R, ⌘⇧F, Entf, E) und zeigt sie nur in den Einstellungen als Liste „Tastenkürzel“ (Z. 767); nirgends als Beschriftung auf Knöpfen/Menüs.
- Menü Radius 16, Rand 4, Zeile 28 hoch, Radius 8 (Z. 346). Toast 28 hoch (Z. 336), Rückgängig 4000 ms.
- Settings-Kachel 96 hoch Radius 12 (Z. 74). Übersichtskachel Radius 12, Hover 320 ms.
- Daten-Schalter `daten` (Demo, Eine, 1.284, Schlimmster Fall) ist im Master vorhanden (break-ui).
- Props-Standard: oberflaeche flach, grund weiß, schrift Geist, griff Haarlinie, assistentGesicht Augen.
- Signal (Rot) im Master: Fehlerzustand (failed, unreadable), destruktive Knöpfe, Fehler-Hinweis. Nicht für Warnhinweise, die „warning“ nutzen ink-2 (Z. 1043: kind warning → ink-2).

## Offen (noch nicht gelesen, Stand dieser Zeile)
 INHALT.json 1226 Z.; werte-abgleich.json 23960 Z. (445 KB, maschinell erzeugt, nur Struktur); stack/surface-Details im TOKENBOGEN nur gekürzt.

## Regeln aus dem Master, die die Editoren betreffen (Beleg)
1. Keine Zahlen in Ringen (AUDIT.md §2.5; entscheidungen.md 13.10.). Keine ⌘-Kürzel auf der UI („Habe ich gesagt, ich will irgendwelche cmd+X oder sowas auf der UI?“, entscheidungen.md 13.10.; AUDIT.md §2.5). Farbe nie auf Aktionen, Signalrot nur für Destruktives (AUDIT.md §2.5). Fremdinhalt nie eingefärbt. Tooltips = System-title. Keine farbigen Kanten („NIEMALS never ever diese farbigen kanten“, 17.10.). Keine Mono-Schrift.
2. Namen in Code und Tokens englisch (13.10.: „alles strikt englisch“). Maße gibt Design vor, Code übernimmt (17.10.).
3. Jeder Wert braucht einen Token (ABNAHME Nr. 1). Werte „von Design gesetzt“ müssen so markiert sein.
4. Hülle nur einmal (CLAUDE.md): jeder Token, Wert, Layer, Hover „MUSS zwingend und IMMER unaufgefordert“ in alle Bereiche der Schablone nachgezogen werden.
5. Belegpflicht: jede Aussage mit Quelle, Zitat, Zeile (CLAUDE.md).
6. Keine ZIPs/Downloads ohne Freigabe (CLAUDE.md).
7. Weitere Bahn-Ideen von Johannes (11.10.): Spalten können Widgets, Toolset-Paletten, Inspector-Panels in den Seitenspalten bei den Editoren tragen und horizontal zerschnitten werden.

## Verstöße der Editoren gegen diese Regeln (Stand vor Korrektur, 19.10.2026)
- ⌘-Kürzel in Menüs und Tooltips (Kurzbefehle-Menü „⌘ + Rad“, „⌘0“, „⌘Z“, Tooltips „Rückgängig (⌘Z)“) in Moodboard, Atelier, Aufmaß, Konfigurator, Planvergleich.
- Signalrot für Nicht-Destruktives (Warnungen, Prüfhinweise, Kalibrierstatus, Planvergleich-Funde, Durchgangsmaß).
- Eigene Hex-/Oklch-Farben in Ebenen, Slots, Zonen, Materialien (Inhaltsfarben, keine Tokens).
- Farbige Ebenenpunkte in der Ebenenliste (kleine Kreise): keine Kante, aber Farbe auf Bedienelement.

## Befunde design-system/*, SKILL.md
- design-system/* ist die ersetzte Farbleiter „Stahl“ (Kommentar in beiden Dateien, Johannes 16.10.). Nicht übernommen. Es enthält Ebenen z: lane 1, grip 2, sync 9, blob 10, safe 30, toast 40 (alfa-ds-tokens.js, Z. z). Editoren: Toast 40, Menü 50, Palette 6, Flyout 8: Palette und Flyout haben keinen Token.
- SKILL.md ist der Prüfablauf „break-ui“ (Worst-Case-Daten, Umschalter Demo/Worst case). Mail trägt den Schalter `daten`. Die Editoren haben keinen Worst-Case-Schalter.
