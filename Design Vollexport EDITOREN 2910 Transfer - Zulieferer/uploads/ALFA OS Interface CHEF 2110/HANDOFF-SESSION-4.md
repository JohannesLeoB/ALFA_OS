Export: 19.10.2026

> Ergänzung: `HANDOFF-FUER-AGENTEN.md` (Zopf-Protokoll: Tokens, Bauteile, Lücken, Ledger, 10 Schritte).

# Übergabe an die nächste Design-Session · Stand 19.10.2026, abends (MESZ)
Diese Datei gilt vor `UEBERGABE-NAECHSTER-CHAT.md` (Hauptteil veraltet, nur Anhang brauchbar) und vor `PROMPT-NAECHSTE-SESSION.md` (ersetzt). Belegpflicht (CLAUDE.md) gilt weiter: Jede Aussage mit Datei, Zeile oder Johannes' Wortlaut aus `entscheidungen.md`, sonst Status `designSet`. Keine ZIPs vor Johannes' „raus“.

## 0 · Lesereihenfolge
1. `CLAUDE.md` (drei STOP-Regeln) · 2. diese Datei · 3. `entscheidungen.md` (alle Worte von Johannes, nach Datum) · 4. `ABNAHME.md` (12 Zeilen, keine darf ⏳ bleiben für „fertig“) · 5. `TODO-ABGLEICH.md` (22 Altlasten A1 bis A22 + Nachträge) · 6. `BRIEF-V9-ABGLEICH.md` (Code-Auftrag Vertrag) · 7. `TRENNUNG-BERICHT.md`, `BREAK-UI-BERICHT.md`, `KONTRAST-PROTOKOLL.md` · 8. `contract-build/README.md` · 9. `github.md`.

## 1 · Wer hat was gemacht (zeitlich)
| Sitzung | Zeit | Ergebnis |
|---|---|---|
| S1 „ALFA · 02 · MAX“ | 11. bis 13.10. | Hülle als 1:1-Bogen, Blob-Menü, Mail und Einstellungen als Seiten, Tokenbogen, 56er-Raster, Entscheidungsrunden (entscheidungen.md Abschnitte 11.10., 12.10., 13.10.) |
| S2 | 14. bis 17.10. | Hülle ausgelagert (alfa-shell.js, ALFA Shell), Designsystem 15.10., Bestätigen-Pille („Radieren“), Geist lokal, Kacheln, Farbsystem-Vorschlag, Auftrag „alles ALTE entfernen“ (17.10. 18:47) |
| S3 (V-2) | 18.10. erster Chat | ALFA Designsystem neu (liest TOKENBOGEN.json), Werteabgleich, Freigabe Orange, Zeitstempel MESZ |
| S3b (V-1) | 18.10. zweiter Chat bis 19.10. 01:00 | Orb im Blob, Ebenen `layer.*`, Federn gegen Apple (Sekundärquellen), Status englisch, `bauteile.json` (75), `mechanik.json`, Textstile (designSet), Kontrast Einstellungen, Übergabe 00:40, Prompt 01:00 |
| S4 (diese) | 19.10. 01:00 bis abends | siehe Abschnitt 2 |

## 2 · Was S4 (ich) getan hat, belegt in den Berichten
1. **Break UI** (nur Bericht, dann „go“ → behoben): `BREAK-UI-BERICHT.md`. 4 Funde behoben (URL-Umbruch, `title` für Betreff und Kartenkopf, Anhangnamen mittig gekürzt, Signatur-Auswahl in Einstellungen). Fund 4 (Empfängerliste) war Fehlbefund. 320 px, Zoom 200 %, RTL **gestrichen**: nicht von Johannes, stammen aus uploads/SKILL.md.
2. **Trennung Mail/Einstellungen**: `ALFA Mail.dc.html` und `ALFA Einstellungen.dc.html` haben je eigene Logik; gemeinsam einmal `alfa-bausteine.js` (`window.AlfaBausteine`: Symbole `P`, Ebenen `LEVELS`, `csOf`, `row`, `notice`, `tb`, `mi`, `menuW`, `menuX`, `openMenu`, `toastIt`, `mem/setMem/lay/grow`, `ovAnim`, `ini/mid`). Gemessen alt gegen neu bei 1512 × 982: Ausgangszustand hell und dunkel 0 Abweichungen, 15 Zustände dunkel 0. Danach die Dateien v2 an die Stelle der alten gesetzt. **Markup der Bausteine steht je Seite doppelt** (Kind-DCs nicht gebaut, Entscheidung offen).
3. **Kontrast** (`KONTRAST-PROTOKOLL.md`): Mail 17 Zustände, Einstellungen 7, hell und dunkel. Funde behoben: Mehrfachauswahl (gewählte und geöffnete Zeile 1:1) in `pickRow`; tiefe Kartenköpfe 3,5:1 → `opacity.cardMetaDeep` 0,95.
4. **Blob über Menü** im Bild gemessen (z 6 über 5); Toast überlappt in Ruhelage nicht. Seitlich gedockt **nicht gemessen**.
5. **Textstile** → Apple (Feld `apple` je `typography.textStyle.*`, Quelle Apple HIG macOS Typography Tabelle + WWDC20 10175). Dynamic Type unter macOS: **kein Beleg**.
6. **Aufräumen**: `design-system/` gelöscht (von keiner Datei geladen; 17.10. „Alles ALTE … entfernt“). Proben 7 A/B in ALFA Entscheidungen entfernt. ALFA Huelle und ALFA Farbsystem bleiben.
7. **Assistent**: Zustände Ruhe, Eingabe, Denkt, Verlauf, Fehler als **Entwurf** in ALFA Entscheidungen 7. Nicht in ALFA Shell gebaut, nicht abgenommen. Texte „Denkt …“ und Beispielantwort von mir.
8. **Fokusring** 1 und **menu-row** Radius 12 / Innenabstand 12 (Johannes: „fokusring“, „einberstanden, bitte setze das so um.“). `menuW` rechnet jetzt auch die Lücke vor der Zusatzspalte (vorher Zeile „Mail in Projektordner sichern“ 6 px zu schmal).
9. **GitHub-Sync** (`github.md`): Repo unverändert gegenüber dem Stand 18.10.; neu `DESIGN/brief/` (Brief v9 von Code, 19.10.). Kopie unter `DESIGN/brief/`. **Falle:** `github_copy_files` mit `path_prefix` entfernt den Präfix; ich habe die Dateien von Hand zurück nach `DESIGN/brief/` verschoben.
10. **Brief v9 / Vertrag `contract/`** (`BRIEF-V9-ABGLEICH.md`, `contract-build/`): 9 Dateien (4 Token-Dateien, Resolver, components, views, texts, changes). P1 valid, P2 consistent, P3 log matches **mit eigenen JS-Ports** (kein Python im Projekt). T5 in den Bögen gebaut: L-008 Konto hinzufügen (Formular), L-009 Konto-Wähler in Mail, L-010 Signatur anlegen, L-012 Rückmeldung nach „Jetzt abgleichen“, L-013 Entfernen mit Bestätigen-Pille. L-011 Logos **nicht** (Material fehlt).
11. Johannes' Fragen/Antworten dieser Sitzung stehen in `entscheidungen.md` (Abschnitt 19.10., Einträge ohne Uhrzeit, ab „erst trennung …“).

## 3 · Was Johannes wann gesagt hat (Kern, Wortlaut in entscheidungen.md)
- **Regeln:** „Hülle nur einmal“ (13.10.), Entwurf ist die Wahrheit, Code übernimmt Maße („CODE HAT NICHTS ZU SAGEN WAS MAßE ANGEHT“, 17.10.), alles strikt englisch bei Namen (13.10.), keine Mono (15.10.), keine farbigen Kanten (17.10.), Tooltips = System (17.10.), kein Liquid Glass fürs Erste (18.10.), keine ZIPs vor Freigabe, Zeitstempel deutsche Zeit (18.10. 21:18), Export-Datum in jeder Datei (18.10.), „Break UI“ erst prüfen (18.10.).
- **Raster und Maße:** 56er-Raster, 4er-Leiter; Ruhe 280 links = rechts („Bitte vereinheitlichen auf 280“, 15.10.), Mitte wächst; Blob 56 × 40; Wach 124 oder Schritt 280 (17.10.); Mindestfenster nachrangig, Fullscreen (16.10.); Spalten nicht „per Hülle“ sperren, Sperre je Ansicht später (17.10.).
- **Blob und Assistent:** Blob weicht nicht aus („Ich muss den BLOB ja klicken können“, 18.10.), Orb im Blob freigegeben (18.10.), Assistent später Vollansicht und Menüeintrag „folgt“ (16.10.), „Assistent … als Tod Do merken“ (18.10.).
- **Falten:** Symbol in gefalteter Bahn öffnet genau diesen Eintrag; Klick auf freie Fläche = letzter Zustand; Doppelklick = Ruhemaß (18.10.). Menü: „Diagonale Toleranz“ (18.10., nicht gebaut).
- **Kacheln:** nur bei Integrationen, Form wie vorher, Einrasten wie „Walze“, Gruppentitel im Kopf, Ruhe ohne Kante, Haarlinie nur beim Scrollen (17./18.10.). Höhe 112 (laut Brief, Wortlaut fehlt).
- **Bestätigen:** Halten 1 s, Radieren, Zittern; Klick-Modus gestrichen; Pille „Freigabe Orange“ vorläufig abgenommen (17./18.10.).
- **Farbe:** Farbleiter noch nicht gewählt (13.10. „es gibt noch keine“); keine wow-Farben auf Fremdinhalt (16.10.); Farbsystem-Vorschlag offen.
- **Mail:** Mehrfachauswahl jetzt (13.10.), Signaturen in Einstellungen anlegen, in Mail nur wählen (13.10.), kein Impressum an jede Mail (13.10.), Konten über Mail-Konten als Integration (15.10.).

## 4 · Offen: nur Johannes kann es (nach Lesen der Code-Dokumente korrigiert, 19.10. abends)
Quelle der Antworten: Code-Gedächtnis im Repo (`.claude/memory/stand.md`, `app-huelle.md`, `app-mail.md`, `app-konten.md`, `design-ist-das-ziel.md`, `entscheidung-wortlaut-herkunft.md`), Brief `DESIGN/brief/BRIEF.txt` und `uploads/AN-DESIGN-LIEFERUNG-15.md`. Zitate sind Code' Mitschrift von Johannes' Wort, nicht mein eigenes Protokoll; wörtlich bestätigen lassen, wenn es sicher sein muss.
**Schon beantwortet (hatte ich fälschlich als offen geführt):**
- Kachelhöhe Integrationen: „112“ (Johannes 19.10., Fragerunde laut stand.md).
- Mehrere Mail-Konten: „Design muss liefern, bitte "temporärbauteil" vorsehen udn Design um Nachlieferung erreichen. Tendenziell "wähler" aber checke auch ncohmal die designs!“ (19.10., Code-Mitschrift). **Code hat das Bauteil nicht, Design muss es entwerfen** (Johannes 19.10.: „Falsch! Code hatte das bauteil nciht … sonst müssen wir es entwerfen“). Johannes 19.10. zum Entwurf: „Ich möchte lieber auf "Postfach" klicken und dort auswählen. Ein wirklich "schmal" gehaltenes Auswahlelement …“. Gebaut in ALFA Mail (Kopf der linken Bahn entfaltet sich, Marken fächern auf) und gezeichnet in ALFA Entscheidungen 8; nicht abgenommen, im Bild nur Zustände zu / drei Konten zu / offen gesehen, Klickfolge und Esc nur per Code gelesen, nicht mit Maus.
- Fokusring-Abstand: „Design entscheidet“ (19.10.) → 1 ist gedeckt.
- Kartenstapel: „Beide als Einstellung“ (8a gestaffelt, 8b Turm, Vorgabe 8a) (19.10.).
- Firmendaten und Impressum: „Nutzer trägt ein“ (19.10.).
- Lücken bereits mit Design geklärt: „Nein, alle offen“ (19.10.): alle L- und W-Punkte des Briefs bleiben Aufgabe von Design.
- Umfang: „es geht hier um Mail und Einstellungen als HUB - Projekte etc definiere ICH später“ (19.10.): zu Projekte, Heute, Kataloge, Warenkorb nichts bauen, nichts vorschlagen.
- Namen: „Unter der UI alles englisch, ASD-STE100; UI-Texte zentral als Sprachsystem DE/EN umschaltbar“ (18.10.) → deutsche Prop-Werte (System/Geist/Ring), Zustandswörter als Schlüssel und `kind: "setting"` gehören **unter die Oberfläche**: englisch. Sichtbare Wörter stehen in `contract/texts.json` (de, später en). Noch nicht umgesetzt (siehe 5).
- Statusnamen: Brief T1 verlangt `approved`, `approved-provisional`, `set-by-design`; am 19.10. in TOKENBOGEN.json, pruefung.js, akte.json, mechanik.json, decisions.json, Designsystem, Entscheidungen umbenannt.
- Master-Regel: „Der neueste Design export ist immer der geltende. er muss nur vollständig sein.“ (18.10.); „DTCG nutzen“; „Master zieht mit Datum immer mit“.
**Wirklich offen, nur Johannes:**
- Sperre je Ansicht (13./17.10. „ENTSCHEIDE ICH SPÄTER“), Rollen/Gating „später“ (13.10.).
- Farbleiter (13.10. „es gibt noch keine“), Farbsystem-Vorschlag.
- Fensterhöhe: Code hat 244 selbst gewählt, Fenster 896 breit, „Höhe nach Bildschirm-Seitenverhältnis (Johannes 19.10.)“ (stand.md); Master 1810 hat dazu kein Token. Von Code an Johannes gestellt.
- Reife, ab der Code baut („freigegeben/approved-provisional oder auch set-by-design?“) und Freigabe neuer golden.txt-Zeilen: Frage von Code an Johannes. Betrifft die 103 `set-by-design`-Tokens.
- Maßband-Lupe (13.10.) liefern; was „Blob anheften“ meint (17.10., vermutlich Andocken am Rand oder Karten-Pin; ungeklärt); Logos für 7 Dienste (Material); Kachelnamen/Rechtsbündigkeit (17.10. Fragen); Systemfrage iOS/iPadOS/Web (11.10.); Kind-DCs ja/nein; „raus“.
**Neue Lage bei Code (stand.md, 19./20.10.):** Code baut seit 19.10. Hülle, Bauteile, Einstellungen, Mail aus dem **Master 1810** (nicht aus unseren Änderungen vom 19.10.); Test rot an 6 Stellen durch Master-Änderungen. Ein neuer Export bräuchte „raus“. Code-Arbeitsweise: nur Sonnet-Stränge, Lead = Opus; Code lehnt alles ab, was der Master nicht zeigt („Was der Entwurf nicht zeigt, baut Code nicht“).

## 5 · Offen: Design kann es tun
- Konto-Wähler (ALFA Mail Kopf links, ALFA Entscheidungen 8): Kontrast hell/dunkel, lange Adressen, Klickfolge und Esc mit echter Maus, Abnahme durch Johannes. Tokens `size.accountFanWidth` 220 und `size.accountClosedWidth` 260 (set-by-design) neu.
- **Namen unter der Oberfläche englisch** (Johannes 18.10.): Prop-Werte `System/Geist/Ring` → englisch, Zustandswörter der Logik (`csOf`, `lädt`, `leer`, `nicht erreichbar`, Dienstzustände) → englische Bezeichner mit Text über `texts.json`, `kind: "setting"` und deutsche `data-state`-Werte prüfen. Nicht begonnen.
- `werte-abgleich.json` per Skript neu erzeugen, W-08 bis W-10 (Brief T7). Skript `contract-build/t7-akte.js` setzt bisher nur Tokenzahl, Bytes, `answered`.
- Vertrag nachschärfen: Zustands-Tokens je Bauteil (heute leer), Maße der 27 Bauteile ohne Maß, `mechanics`, Ids von Hand benennen, Texte: 71 dynamische erfassen, `en` ergänzen, mehr Aktionen in `views.json`, Grund je Änderung statt Sammelformel.
- Original-Skripte (validate.py, check_contract.py, diff_contract.py) laufen lassen: nicht möglich hier; Code muss gegenprüfen.
- ABNAHME-Zeilen 1, 2, 4, 6, 10, 11, 12 (⏳). Kontrast: Hover, Fokusring, Symbole. Break UI: Dunkel in Mail mit Schlimmster Fall, Scrollen 1.284, Datensätze in Einstellungen, Konto-Formular und Wähler bei 1512 × 982 messen.
- Assistent in ALFA Shell bauen, wenn Johannes die Entwürfe sieht.
- TOKENBOGEN.json: Kopfzeile sagt „Stand 18.10.2026“, Änderungen vom 19.10. (cardMeta, focusRingOffset 1, textStyle.apple) fehlen im Text.

## 6 · Widersprüche, Unsauberkeiten, Altlasten (S4 gefunden, nicht alle behoben)
1. **Statusvokabular (19.10. abends vereinheitlicht):** überall `approved`, `approved-provisional`, `set-by-design` (TOKENBOGEN.json, Vertrag, pruefung.js, akte.json, mechanik.json, decisions.json, Designsystem, Entscheidungen). In Markdown-Berichten steht „designSet“ noch als historisches Wort, ABNAHME 2a nennt alte Namen.
2. **Tokenzählung:** 368 (Prompt 18.10.), 370 (pruefung.js), 350 (Zählung nur `$value`), 397 Definitionen und 340 Pfade im Vertrag. `akte.json` sagt 397 und nennt beide; Übergabe/Prompt noch 368; `akte.json` offen-Liste „101 designSet“ vs. 87 (Prompt) vs. 103 (pruefung).
3. **Veraltete Dokumente:** `AUDIT.md` (Anweisung an fremde KI) Punkte 5, 7, 9, 10 beschreiben „eine Logikdatei“, `design-system/*`, `freigabe-orange`; `RUECKGABE-AN-CODE.md` Zeile „Struktur … teilen heute eine Logikdatei“; `UEBERGABE-NAECHSTER-CHAT.md` Hauptteil (Aufgabe 1 „größter Umbau“); `PROMPT-NAECHSTE-SESSION.md` (bereits ersetzt, siehe dort); `TRENNUNG-BERICHT.md` nennt „v2“-Dateien, die es nicht mehr gibt (Hinweis steht oben im Bericht). Nicht alles nachgezogen: bitte vor jeder Lieferung bereinigen (CLAUDE.md „bereinigen. und nie unreines versenden“).
4. **pruefung.js** prüft Wertgleichheit, nicht die Rolle; rgba, Grad, Deckkraft, Skalierung in Template-Styles nicht erfasst; neue Dateien `alfa-bausteine.js`, Berichte stehen in APP/DOKU, `contract/` nicht.
5. **Brief nennt Zeilennummern** (ALFA Mail:737, :759 …) des Exports 18.10.; für die getrennten Bögen falsch.
6. **ABNAHME 2d** nennt „Notch 7, Toast 4“ gemessen nur aus z-index; Notch nicht gemessen.
7. **Entscheidungen.md**-Einträge dieser Sitzung tragen keine Uhrzeit (Chat liefert keine); nur der Sync-Eintrag hat 16:35 MESZ.
8. **Johannes' Fragen ohne dokumentierte Antwort** (TODO-ABGLEICH): A9 Kachelnamen/Rechtsbündigkeit, A12 „Blob anheften“, A1 Maßband-Lupe, A16 Systemfrage iOS/iPadOS/Web (11.10. Frage 3).
9. **Fremd-KI-Audit** (Johannes 17./18.10.): nie gelaufen; ABNAHME-Ziel „fertig fertig“ nicht erreicht.
10. **Assistent-Text „Denkt …“, Konto-Wähler-Tooltip „Konto wählen · bis zu drei Konten“, „Vorlage 1“, `opacity.cardMetaDeep` 0,95, Fokus 1:** Design-Setzungen ohne Wort von Johannes (alle `designSet`).
11. **Verifier:** Der Hintergrund-Prüflauf nach den letzten Änderungen (Einstellungen: Konto-Formular, Pille, Signatur; Mail: Konto-Wähler) hat sich bis Redaktionsschluss nicht gemeldet; Mail wurde zuletzt nur per Skript, nicht im Bild geprüft.

## 7 · Werkzeuge und Fallen
- **Prüf-Fenster rendert keine Frames:** Messungen immer mit `*{transition:none!important;animation:none!important}`; Bewegung nur mit echter Maus bestätigbar. `eval_js` bricht nach 10 s ab; `run_script` nach 30 s (pruefung.js und große Läufe getrennt starten).
- **Instanz der Seiten im Browser holen:** über React-Fiber (`__reactFiber…` des `[data-part=area-page]`, hochlaufen, `stateNode.logic` mit `fromProps`). Damit `setState`, `openMenu`, `menuW` testen (Muster in den Berichten).
- **Vertragswerkzeuge:** `contract-build/validate.js`, `check.js`, `diff.js` (Ports), Erzeuger `t1-tokens.js`, `t2-components.js`, `t4-texts.js`, `t7-akte.js`; Basis für P3 in `contract-build/previous/2026-10-19T16-55/`. Aufruf-Muster: `new Function(code)(…)` in `run_script`. Reihenfolge: t1 → t2 → t4 → views von Hand → `diff.makeBlock` → validate/check/diff → schreiben.
- **data-id** stehen in den vier Bögen (Mail, Einstellungen, Shell, Bestaetigen); neue Elemente brauchen `data-id` UND Eintrag per t2, sonst P2-Fund.
- Tooling: ALFA Mail und ALFA Einstellungen sind Design Components mit eigener Klasse; gemeinsame Methoden über `AlfaBausteine.mixInto` (Seite setzt `AREA`, `CARDS`, `FANNED`).
- `github_copy_files path_prefix` entfernt den Präfix (siehe 2.9).

## 8 · Empfohlene Reihenfolge für die nächste Session
1. Johannes' Antworten zu Abschnitt 4 holen (eine Form mit Auswahlfragen, nur das, was dort steht).
2. Altlasten Abschnitt 6.1 bis 6.4 bereinigen (Status vereinheitlichen, Zahlen, AUDIT.md, RUECKGABE-AN-CODE.md, UEBERGABE, TOKENBOGEN-Kopf).
3. Verifier-Ergebnis oder eigene Bildprüfung der neuen Einstellungen-Teile und des Konto-Wählers.
4. Vertrag nachschärfen (Abschnitt 5), P1 bis P3 wiederholen, Block in `changes.json` anhängen.
5. Break UI und Kontrast Restlücken, danach ABNAHME Zeile für Zeile.
6. ZIP erst nach „raus“.
