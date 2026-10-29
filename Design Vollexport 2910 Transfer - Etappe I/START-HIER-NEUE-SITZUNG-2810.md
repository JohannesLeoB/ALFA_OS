# START HIER · Übergabe an eine neue Design-Sitzung · 28.10.2026 abends
Arbeitsstand, nicht freigegeben. Ersetzt START-HIER-ZWEITES-KONTO.md (24.10.). Lies diese Datei ganz, dann CLAUDE.md, dann die letzten 80 Zeilen von entscheidungen.md.
Nachtrag 29.10.2026: Stand und Papercuts in ETAPPE-2910.md; überholte Dateien (u. a. an-code-briefe-2810/, _states-probe.json, GEGENLESE-v14.md) liegen in ARCHIV/ (Liste ARCHIV/INHALT.md).

## 0 · Erste Handgriffe
1. Liegt ein ZIP in `uploads/`: entpacken und jede Datei an denselben Pfad im Projektstamm legen (auch `CLAUDE.md`, `contract/`, `contract-build/`, `lieferung-an-code/`, `material/`, `DESIGN/`). `support.js` nicht überschreiben.
2. Prüfen, dass im Stamm liegen: 9 Bögen `ALFA Bestaetigen | Designsystem | Dienste | Einstellungen | Icon | Mail | Shell | Tokenbogen | Widgets .dc.html`, `alfa-shell.js`, `alfa-bausteine.js`, `alfa-theme.css`, `TOKENBOGEN.json`, `entscheidungen.md` (531 Zeilen), `github.md`, `contract/` (LIEFERUNG, components, texts, changes, views, base.tokens, theme-*.tokens, akte, PRUEFUNG.txt).
3. Prüflauf (Abschnitt 4) einmal laufen lassen und das Ergebnis wörtlich melden. Erwartet: P1–P3 ohne Fund, P3 „821/821“ oder höher, P4 „items: 37 of 44 done“, „delivery: complete“, pruefung.js grün.
4. Mail, Einstellungen, Dienste ansehen (Bildschirmfoto, nicht nur Konsole). Erst dann weiterarbeiten.
5. Johannes hängt wieder an: lokalen Ordner `ALFA_OS` (Code-Repo), GitHub `JohannesLeoB/ALFA_OS` (main).

## 1 · Regeln (CLAUDE.md + Ansagen von Johannes, gelten immer)
- **Hülle nur einmal:** Alles Übergreifende (Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände, Radien, Bewegung, Mouseover) sofort und vollständig in ALLEN Bögen gleich.
- **Belegpflicht:** Keine Aussage, Zahl, Frage, Änderung ohne Quelle mit Datei:Zeile. Fehlt der Beleg, nicht behaupten.
- **Keine ZIPs/Downloads ohne Freigabe** „100 % sauber, darf raus“. Ausnahme: Briefe an Code, wenn Johannes sie ausdrücklich verlangt.
- **Suchen statt fragen:** Erst Projekt, lokales Repo `ALFA_OS`, GitHub (`.claude/memory/`, `DESIGN/`, `Sources/`, `App/`) durchsuchen. Eine Frage ohne Suche ist ein Fehler.
- **Ansehen, nicht nur prüfen:** Nach jeder Bogenänderung Bildschirmfoto machen und hinsehen (Johannes 28.10.: „Angesehen … habe ich nicht … schlechte arbeitsmoral“). Menüs aufklappen, Zustände durchklicken.
- **Jüngere Ansage gilt**, bis Johannes sie ändert (28.10.).
- **Vertrag nur über Werkzeuge** (`contract-build/apply.js`, `lauf.js`), nie von Hand an `contract/*.json`. Ausnahme bisher: `alfa-theme.css` für neue Themenfarben (Werkzeuglücke, siehe 3.6).
- **Keine Farbwelten.** Farbbögen gesperrt.
- **Nichts erfinden:** Keine Demo-Texte als echte Daten, keine Untertitel ohne Quelle, keine Funktionen, die der Anbieter nicht kann (Johannes 28.10.: Mail-Funktionen nur, wenn der Provider sie technisch kann).
- **Antworten:** kurz, Deutsch, Klartext statt Kürzel („N20 Menüeinträge ohne Funktion“, nie nur „N20“). Jede Ansage sofort eine Zeile in `entscheidungen.md`.

## 2 · Stand
- Lieferschein `contract/LIEFERUNG.json` (Brief v14): 37 von 44 erledigt. Offen: N27 Katalog der Dienste, N28 Verwalten je Dienst, N29 Mitteilungen, N30 Dateiorte, N31 Fehlerbericht, N33 Herkunft der Kontakte (alle warten auf Daten von Code). Frage: N15 Aus Projektordner (Code speced).
- Brief an Code mit allem, was Design braucht: `lieferung-an-code/AN-CODE-2810.md` (A1–A10, B1–B3, C1–C2, D0 Entscheidungen). Kopie im Ordner `an-code-briefe-2810/` (für ZIP).
- Heute entschieden (entscheidungen.md, Ende): T6 keine Stapelwahl in Einstellungen; N20 Mail-Funktionen real + gängig, Formatleiste mit Zitat und Format entfernen, „Notiz anfügen“ raus, alles nur bei Fähigkeit des Providers (ALFA Mail `CAPS`, `can(f)`, Tweak `provider`); N26 Einstellungen bleiben nach Thema; N35 Meldung in der Bahn der Handlung, unter Menü und Blob; Absendername je Postfach (Einstellungen `senderRow`); Assistent ohne „Ohne Projekt“.
- Logos: `material/icons/` (google.svg, clickup.svg, claude.svg, airtable.png zugeschnitten, sevdesk.png, clockodo-kreis.png, dhl.svg, happa.svg, mailkonten.svg), Originale `material/logos/`.

## 3 · Nacharbeiten (in dieser Reihenfolge)
1. **Entwurf: doppelte Bildlaufleiste** (ALFA Mail, Entwurfskarte): Karte scrollt, Textfeld scrollt zusätzlich. Textfeld mitwachsen lassen (auto-height), nur die Karte scrollt. Johannes fragen, ob so gewünscht — er hat noch nicht geantwortet. Danach ansehen.
2. **Sichtprüfung nachholen:** Dunkel-Modus (Mail, Einstellungen, Dienste) und ALFA Widgets — noch nicht angesehen. Kontrast hell/dunkel.
3. **Zustände je Bauteil (A6):** 81 Bauteile in `components.json` haben nur einen leeren Zustand „rest“. Je Bauteil aus der Logik auslesen (Werte je data-state-Zweig, style-hover/active/focus) und über `apply.js` (components[].states) eintragen. Probe: `contract-build/previous/_states-probe.json` (13 Teile aus festen Attributen ablesbar). Nicht per Suchen-Ersetzen.
4. **146 feste Zahlen in der Logik (A1)** auf Tokens umstellen, Bauteil für Bauteil, mit Sichtprüfung.
5. **Tooltip Abgleich-Knopf** sobald Code das Zeitformat liefert (C1): fest „Gerade abgeglichen“ ersetzen.
6. **Werkzeuglücke:** `apply.js` schreibt neue Themenfarben (colors) nicht in `alfa-theme.css`. Entweder t9 erweitern oder bei jeder neuen Farbe den Block in alfa-theme.css per Skript nachziehen und dokumentieren.
7. **Demo-Werte in Einstellungen** („vor 2 Minuten“, „9. Okt.“, „Projekte 412 von 1.280“) als Demo kennzeichnen oder aus Codes AreaReading-Beispiel nehmen, sobald geliefert.
8. **N37 Rest:** Entwurfskarte-Aktion im Assistenten, eigene Formen je ContentBlock (Code: `Sources/Assistant`).
9. **Hub zeichnen (N27–N31, N33)**, sobald Code die Daten liefert (A1–A7 im Brief). Nur Felder zeichnen, die Code nennt.
10. **Lieferschein und Akte** nach jeder Runde per `lauf.js` neu schreiben; where nur auf `*.dc.html:Zeile` (P4 prüft das).
11. **Vorlage an Johannes:** eine Seite mit Prüfergebnis, Bildschirmfotos, offenen Fragen. Kein Paket ohne Freigabe.

## 4 · Prüflauf (so, nicht anders)
```js
const AF=Object.getPrototypeOf(async function(){}).constructor;
const r=await new AF('io','opt',await readFile('contract-build/lauf.js'))({readFile,readFileBinary,saveFile,ls},{stamp:'JJJJ-MM-TTTHH:MM',write:true});
log(JSON.stringify({P1:r.P1,P2:r.P2,P3:r.P3,P3zahl:r.P3zahl,P4:r.P4,pj:r.pruefungJs}));
```
Vertragsänderung:
```js
const r=await new AF('io','spec',await readFile('contract-build/apply.js'))({readFile,saveFile,ls},{stamp:'…',reason:'… ≤120',texts:[[key,de,kind,element,en]],dropTexts:[key],tokens:{…},colors:{…},components:[…],renameTexts:[[alt,neu]],write:true});
```
Kopf von `apply.js` beschreibt alle Felder.

## 5 · Austausch mit Code
- Brief Code → Design: GitHub `DESIGN/brief/BRIEF.txt` (v14). Codes Gedächtnis: `.claude/memory/stand.md`, `spec-*.md`, Repo-`CLAUDE.md` („Next tasks“).
- Design → Code: `lieferung-an-code/` (AN-CODE-2810.md aktuell; ANTWORT-2810.md, ENTSCHEIDUNGEN-AN-CODE-2310.md, SPEC-NACHTRAG-2310.md, GEGENLESE-v14.md, TEXTE-ZUORDNUNG-2810.json für Textschlüssel).
- Textschlüssel im Vertrag sind Codes Schlüssel (206 umgestellt, `formerKey`); 28 mehrdeutig, 34 Beispieldaten, 173 neu mit Vorschlag.
- `github.md` bei jedem Lesen/Sync aktualisieren (Last sync mit echter Uhrzeit).

## 6 · Offene Fragen an Johannes
- Entwurf: Textfeld mitwachsen statt eigener Bildlauf? (3.1)
- Sonst keine; alles Weitere wartet auf Code.
