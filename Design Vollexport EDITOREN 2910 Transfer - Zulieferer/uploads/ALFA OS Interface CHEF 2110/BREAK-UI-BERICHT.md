Export: 19.10.2026

# Break-UI-Bericht · Teillauf · 19.10.2026
Nach `uploads/SKILL.md` und `uploads/CATALOG.md`. Johannes 18.10.: „Zuerst prüfen“. Johannes 19.10.: „go!“ → Funde behoben (Stand unten). Messung mit Prüfung nach dem Beheben.

**Gemessen:** ALFA Mail, Prop `dataset` = „Schlimmster Fall“ (Daten schon vorhanden: ALFA Mail.dc.html `worstMsgs()`, `dataDrafts()`), Bahnen 280 / 896 / 280, Übergänge aus, DOM-Messung (Rand von Text gegen Bahn/Karte, Überlauf-Stil, `title`). Bild: `screenshots/breakui-worst-1512.png` (Vorschau nur 914 px breit, rechte Bahn dort abgeschnitten).
**Nicht gemessen:** Einstellungen, Dienste-Karten, Entwurf mit 12 Empfängern, `dataset` Eine / 1.284, Leer-Zustände, 320 px, Zoom 200 %, RTL-Ausrichtung, Dunkel. Alles unten mit „abgeleitet“ ist aus Stil gelesen, nicht im Bild gesehen.

## Teil 1 · Was kaputt ging
| # | Schwere | Feld | Wert | Was passiert | Fix | Fundstelle |
|---|---|---|---|---|---|---|
| 1 | Broken | Mailtext (Lesen) | URL ohne Leerzeichen: `https://example.com/projekte/2026/kueche-hansen/fronten/muster/9f8e7d6c5b4a?ansicht=…` | Zeile läuft 68 px über die Karte, wird von `overflow:hidden` abgeschnitten, Rest nicht lesbar, kein Umbruch | `overflow-wrap:anywhere` am Textblock | ALFA Mail.dc.html:173 (`white-space:pre-wrap`), Zitat :181 gleich |
| 2 | Fragile | Betreff in Mailzeile (Mitte) | 150 Zeichen „Re: AW: Re: Fronten Küche …“ | Gekürzt mit Ellipsis am Zeilenende (gemessen: Eltern `text-overflow: ellipsis`, Spanne 994 px). Kein `title`, Volltext nur durch Öffnen | `title` mit Volltext. Lesen-Kopf bricht um (Zeile 162 `overflow-wrap:anywhere`) | ALFA Mail.dc.html:80–82 |
| 3 | Ugly | Kartenkopf rechts | „An Aleksandra Wiśniewska-Kowalczyk“ + E-Mail 64 Zeichen | Spans `overflow:hidden`, Name 10 px, E-Mail 132 px über der Kante → abgeschnitten, kein `title` (gemessen: `title` leer) | `title` mit Volltext; Mitte kürzen für Adressen (Anfang bleibt, wie `…@…` der linken Bahn) | ALFA Mail.dc.html:137 |
| 4 | Ugly | Empfängerliste | 12 Empfänger, Montgomery III, 64-Zeichen-Adresse | Zeilen 25–75 px zu breit, geclippt; Namen und Adressen ohne `title` | `min-width:0`, Ellipsis, `title` | ALFA Mail.dc.html:158 (Empfängerliste Lesen), :229 (Vorschläge, `title` dort vorhanden) |
| 5 | Ugly | Anhang-Chip (Karte) | „Angebot Einbauschrank Flur — FINAL (überarbeitet) v12 [freigegeben von Hausverwaltung].pdf“ | Chip 588 px breit in 280er-Bahn; Name wird am Ende gekürzt, `.pdf` und Fassung (v12) gehen verloren; `title` ist da (gemessen) | Mitte kürzen („Angebot Eins…v12 […].pdf“) | ALFA Mail.dc.html:100, :186, :251 |

Geprüft, aber ohne Fund: Initialen (AW, J, ĐH, 王, نع, 🦊, CM, SS) stimmen alle, auch Emoji und Suffix „III“ (CM). Angehängte Chips der Zeile enden mit Ellipsis und tragen `title`. Linke Bahn kürzt die lange Absenderadresse in der Mitte („aleksandra.wisni…k.example.com“).

## Teil 2 · Entscheidungen für Johannes
- Betreff in der Zeile: 1 Zeile mit Ellipsis (heute) oder 2 Zeilen? Empfehlung 1 Zeile, `title` ergänzen.
- Kürzen in der Mitte für Adressen und Dateinamen (Anfang und Ende bleiben)? Empfehlung ja, wie links schon.
- URL im Mailtext: umbrechen (`anywhere`). Empfehlung ja, kein Scrollen im Text.
- `dataset` „1.284“: virtualisieren oder paginieren? Empfehlung virtualisieren. Heute nicht gemessen.

## Teil 3 · Was hielt
Initialen, Bahnbreiten, Kopf mit langer Adresse links, Betreff im Lesen-Kopf (umbrechend), Anhang-Chips der Zeile (Ellipsis plus `title`), „Kein Betreff“/„Kein Text“ ohne Leerzeile (Jo-Zeile im Bild).

## Stand
Toggle: Prop `dataset` (Demo / Schlimmster Fall / Eine / 1.284) an ALFA Mail und ALFA Einstellungen. Nichts behoben. Zu klären: „fix all“ oder „fix 1, 3“. Rest der Fälle (Einstellungen, 320 px, Zoom, RTL, Leer/Eine/1.284) braucht einen zweiten Lauf.

## Behoben 19.10. (ALFA Mail.dc.html, Schlimmster Fall, 1512 × 982, Übergänge aus)
- 1 URL im Mailtext: `overflow-wrap:anywhere` am Text und am Zitat. Gemessen: Textblock scrollWidth = Breite (240), vorher 68 px drüber. ✅
- 2 Betreff in der Zeile: `title` mit Volltext. ✅
- 3 Kartenkopf: `title` mit Name · Adresse am Titel, Metazeile mit Volltext. ✅
- 4 Empfängerliste: **Fehlbefund zurückgenommen.** Die Zeilen kürzen mit Ellipsis (Spanne 157 px in der Bahn) und tragen `title` schon (ALFA Mail.dc.html Zeilen mit data-part="recipient-row"). Meine erste Messung hat die Textknoten innerhalb der Ellipsis-Spanne gezählt. Dasselbe galt für den Kartenkopf (kürzt per Ellipsis, es fehlte nur das `title`).
- 5 Anhang-Chip in Karte und Entwurf: Name in der Mitte gekürzt (`mid`, 34 Zeichen), `title` voller Name · Größe. Gemessen: alle 11 Chips der Karte enden bei 1480, Bahnkante 1496. ✅
- Entscheidungen aus Teil 2 (Betreff 1 Zeile, Mitte kürzen, URL umbrechen): wie empfohlen gebaut; von Johannes nur mit „go!“ gedeckt.
## Nachtrag 19.10. (Einstellungen und Datensätze)
- Einstellungen, Datensatz Schlimmster Fall, hell und dunkel, alle Gruppen und 7 Kartenstapel: 1 Fund. Block „Signatur“ (jetzt über Ich erreichbar): die Kontoauswahl zeigte die 64-Zeichen-Adresse ungekürzt, 372 px über die Bahn. Behoben in ALFA Einstellungen: Auswahlknopf schrumpft (max. 60 %), Text mit Ellipsis, `title` voller Wert. Gemessen danach: alle Auswahlknöpfe enden 8 vor der Bahnkante.
- Mail, Datensatz „Eine“: 1 Zeile, Zähler 1, kein „1 Nachrichten“, kein Platzhalter. ✅
- Mail, Datensatz „1.284“: 60 Zeilen gerendert, Rest als Platzhalter (107.712 px), Zähler 899 ungelesen; kein Virtualisieren, Laden in 120er-Schritten beim Scrollen. Scroll-Verhalten nicht gemessen.
- 320 px, Zoom 200 %, RTL: **nicht von Johannes**. Sie stehen in uploads/SKILL.md Phase 4 (Web-Prüfliste des Skills). Johannes 16.10.: Mindestfenster „interessiert mich auch wenig“, er nutzt Fullscreen; macOS-App hat keinen Browser-Zoom; zu RTL gibt es kein Wort von ihm. Gestrichen aus der Liste, nicht geprüft.
- Weiter nicht geprüft: Dunkel in Mail mit Schlimmster Fall.
