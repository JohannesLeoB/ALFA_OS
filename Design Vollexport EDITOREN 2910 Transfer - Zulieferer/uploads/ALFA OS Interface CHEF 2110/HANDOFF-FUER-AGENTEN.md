Export: 19.10.2026

# Handoff für Agenten · Zopf entwirren · Stand 19.10.2026, 21:30 MESZ
Auftrag Johannes: „So dass wir quasi "10 schritte vorher starten udn nachziehen und durchkämmen können, was noch an knötchen im Zopf ist“. Diese Datei protokolliert, was entstanden ist, was unsauber ist, was fehlt und was liegen blieb. Ergänzt `HANDOFF-SESSION-4.md` (Chronik, Johannes' Worte nach Themen); beide lesen. Wortlaut von Johannes steht nur in `entscheidungen.md`; hier stehen Verweise.
Ablage: Projektordner statt Temp-Verzeichnis, weil CLAUDE.md alle Übergaben im Projekt verlangt und das Dateisystem nur das Projekt kennt.

## 0 · Startregeln
1. Belegpflicht: jede Aussage mit Datei:Zeile oder Wortlaut aus `entscheidungen.md`, sonst `set-by-design`.
2. Keine ZIP vor Johannes' „raus“. Hülle genau einmal (`alfa-shell.js`, `ALFA Shell.dc.html`, `alfa-bausteine.js`).
3. Messen statt „lädt fehlerfrei“: Übergänge abschalten (`*{transition:none!important;animation:none!important}`), Bewegung nur mit echter Maus bestätigbar.
4. `run_script` bricht nach 30 s ab, `eval_js` nach 10 s: große Läufe teilen. `pruefung.js` einzeln starten.
5. Suchwerkzeug `grep` meldet bei Pfad „.“ teils „No matches“: Gegenprobe mit `run_script` und `readFile`.
Suggested skills: `writing-for-agents` (Dokumente nachziehen), `Frontend design` (Konto-Wähler, Assistent, Entwürfe), `diagnosing-bugs` (Messabweichungen), `Handoff to Claude Code` erst nach „raus“.

## 1 · Dateikarte (nur was zählt)
- Seiten: `ALFA Mail.dc.html`, `ALFA Einstellungen.dc.html` (je eigene Logik), `ALFA Shell.dc.html`, `ALFA Bestaetigen.dc.html`, `alfa-bausteine.js` (gemeinsam), `alfa-shell.js`, `alfa-theme.css`.
- Sichtbögen: `ALFA Entscheidungen` (1 Wach, 2 Freigabe Orange, 3 Kacheln, 5 Mehrfachauswahl/Farbsystem, 6 designSet-Liste, 7 Assistent, 8 Konto-Wähler), `ALFA Designsystem`, `ALFA Tokenbogen`, `ALFA Huelle`, `ALFA Dienste`, `ALFA Farbsystem`.
- Werte: `TOKENBOGEN.json` (Quelle), `contract/` (Vertrag nach Brief v9, 9 Dateien), `lieferung-an-code/` (akte, bauteile, mechanik, decisions, werte-abgleich, settings-sections, motion-springs, pruefung.js, fonts).
- Werkzeuge: `contract-build/` (validate.js, check.js, diff.js, t1-tokens.js, t2-components.js, t4-texts.js, t7-akte.js, `previous/<stamp>/` = Basis je Block, README.md).
- Code → Design: `DESIGN/brief/` (BRIEF.txt v9, Schemas, validate.py, check_contract.py, diff_contract.py, examples/, tokens-gegen-schema.txt).
- Berichte: BREAK-UI-BERICHT, KONTRAST-PROTOKOLL, TRENNUNG-BERICHT, TODO-ABGLEICH (A1 bis A22 + Nachträge), BRIEF-V9-ABGLEICH, HANDOFF-SESSION-4, ABNAHME (12 Zeilen), AUDIT-BERICHT.

## 2 · Was entstanden ist (S4, 19.10.)
- Trennung Mail/Einstellungen; `alfa-bausteine.js` (`window.AlfaBausteine`, Mixin). Alt gegen neu 0 Abweichungen bei 1512 × 982 (hell/dunkel Ausgangszustand, 15 Zustände dunkel).
- Break UI Teil (Mail Schlimmster Fall; Einstellungen Schlimmster Fall; Eine/1.284 Mail): behoben URL-Umbruch, `title`, Mittekürzung Anhänge, Signatur-Auswahl.
- Kontrast: Mail 17 Zustände, Einstellungen 7, hell und dunkel; behoben `pickRow`, `opacity.cardMetaDeep`.
- Menü: Fokus 1; menu-row Radius 12 / Innenabstand 12; `menuW` mit Lücke.
- Textstile → Apple (Feld `apple`), `design-system/` gelöscht, Proben 7 A/B raus, Status auf `approved | approved-provisional | set-by-design` vereinheitlicht.
- Einstellungen neu: Konto-Formular (8 Felder), Entfernen-Pille für Konto und Vorlage, Signatur anlegen, Sync-Rückmeldung (`Verbindung steht.` / `Fehler: …`).
- Mail neu: Konto-Wähler (Klick auf „Postfach“, Kopf entfaltet Marken, `acctOpen`, `account`).
- Vertrag `contract/`: 399 Token-Definitionen (342 Pfade), 78 Bauteile, 191 Elemente (data-id in vier Bögen), 291 Texte, 3 Ansichten, 5 Blöcke in `changes.json`. P1 valid, P2 consistent, P3 log matches (JS-Ports, keine Original-Skripte).
- Entwürfe: Assistent-Zustände (ALFA Entscheidungen 7), Konto-Wähler (8).

## 3 · Tokens: nicht sauber
Zählung `contract/` (nach Dateien): 320 `set-by-design`, 54 mit `source`, 17 `approved`, 8 `approved-provisional`.
1. **213 Tokens ohne Status in `TOKENBOGEN.json`**: der Vertrag setzt sie pauschal auf `set-by-design` (Brief erlaubt es), die Quelle trägt das nicht. 212 davon ohne `where`. Fix: `where` je Token aus den Bögen belegen oder Wortlaut von Johannes suchen; dann `TOKENBOGEN.json` angleichen.
2. **101 Tokens mit `where` auf alte Zeilen** (`ALFA Mail.dc.html:987`, `…:212`, `ALFA Shell.dc.html:197` usw.). Seit der Trennung falsch (Brief W-08). Fix: Skript, das je Token die Fundzeile im Quelltext sucht.
3. **Zählweisen**: 368 (Prompt 18.10.), 350 (`$value`-Zählung der Quelle), 370 (pruefung.js), 399 Definitionen / 342 Pfade (Vertrag). Eine Zahl wählen, überall gleich schreiben (W-01).
4. **Zustands-Tokens fehlen**: alle 78 Bauteile haben Zustände mit leeren `tokens`.
5. **Literale ohne Rolle**: `pruefung.js` prüft Wertgleichheit, nicht die Rolle. Bekannte Literale: 5 px Versatz der Konto-Rundungen (Mail-Logik `5 * (k + 1)`), `margin-right:-3px` an der Entfernen-Pille, `width:96px` an dieser Pille (Einstellungen), `margin-left:-8px` am „Postfach“-Knopf, 28 px Höhen ohne Maßbezug, 320 ms und 160 ms Animationen des Wählers. Fix: Tokens `size.account*`/`motion.account*` anlegen oder auf bestehende zurückführen.
6. **Neue Tokens ohne Wortlaut**: `opacity.cardMeta` 0,72, `opacity.cardMetaDeep` 0,95, `size.accountFanWidth` 220, `size.accountClosedWidth` 260, `motion.transition.{stack,fold,blobFlight}` (nur gleichnamige Paare).
7. **45 `motion.duration`-Tokens ohne gleichnamige Kurve**: Zuordnung Dauer ↔ Kurve fehlt (nicht erfinden; aus `mechanik.json` und Quelltext belegen).
8. **`TOKENBOGEN.json` Kopf** nennt „Stand 18.10.2026“, Änderungen vom 19.10. (cardMeta, Fokus 1, `apple`, `size.account*`, Status) nicht im Text.

## 4 · Bauteile, Mechaniken, Farben, Größen, Positionen: was fehlt
- **Bauteile ohne Maße** (29): account-mark, account-switch, area-page, assistant, blob, card, card-content, card-overview, card-stack, chip-remove, connection-status, content-state, filter-capsule, handle, inline-confirm, lane, lane-content, lane-strip, mail-signature, menu, message-header, notice, recipient-field, row-actions, safe-area, scroll-line, search-tape, settings-tiles, suggestion-list. 49 haben Höhe oder Radius.
- **Mechaniken**: 0 Bauteile mit `mechanics` im Vertrag. `mechanik.json` (Quelle, 18.10.) beschreibt Blob, Bahnen, Scroll, Stapel, Menü, Toast, Bestätigen, Kachel, reducedMotion; nicht in den Vertrag übersetzt.
- **Muster (7) mit `flow`**: anchored-menu, blob, card, card-stack, confirm-pill, lane, toast. Flows von mir aus dem Code abgeleitet, nicht gegen Bild oder `mechanik.json` geprüft; `card-stack` und `card` überschneiden sich.
- **Ebenen**: `layer` je Bauteil nach Namen zugewiesen (Blob, Menü, Toast, Handle, Sync, Safe-Area, Bahn), Rest `layer.lane`; nicht gemessen. Notch-Ebene 7 nicht im Bild gemessen. Blob seitlich gedockt über Menü/Toast nicht gemessen.
- **Farben**: Farbleiter nie gewählt (Johannes 13.10.), `ALFA Farbsystem` Vorschlag; Fremdinhalt-Farben (`sheet*`) fest weiß; Glas/Lack-Flächen als Tokens da, nicht gerendert („Glas später“); `color.mood` nur für Stapel und Typen. Kontrast nicht gemessen: Hover, Fokusring, Symbole ohne Text, `lightGray`-Untergrund, Konto-Wähler neu.
- **Größen/Positionen**: Fensterhöhe 244 (Code, Master ohne Token), `windowMin` und Blob-Auslauf nur im Code; Toast-Position 8 über Kartenfuß (Wert in Logik), Menüposition (`menuX`) als Rechnung, nicht als Token; Assistent: Vollansicht, Eingabe-Wachstum, Verlauf-Scroll, Menüeintrag fehlen; Konto-Formular ohne eigenes Layout (nutzt Zeilen); Logos 7 von 10 Diensten.
- **Texte** (`contract/texts.json`): 291, davon 42 mit Element; 177 von 191 Elementen ohne `textKey`; 0 englische Fassungen (`en`); 71 dynamische oder zusammengesetzte Texte fehlen (Liste im t4-Lauf: `notes.gaps`); Shell nur 11 Texte (Bereichsnamen und Gruppen stehen in `GROUPS`/Logik, nicht erfasst); Schlüssel erzeugt (Element-Id oder Art + Zähler), keine sprechenden englischen Namen.
- **Ansichten** (`views.json`): 18 Aktionen (shell 4, mail 6, settings 8); `states` und `textKeys` knapp; Zustände Fehler/Leer/Laden nicht als Aktionen.
- **Elemente**: 191 Ids erzeugt (Bauteil + Handlername), 67 mit Zähler-Suffix `-n`; für Menschen schwer lesbar. Fix: Ids von Hand für die 40 wichtigsten benennen (Sendeknopf, Suche, Neue Mail, Archivieren …), dann alles andere erzeugt lassen.

## 5 · To-do-Ledger
**Erledigt (belegt)**: Trennung; Break-UI-Funde 1 bis 3, 5 + Signatur-Auswahl; Kontrast-Funde (2); L-015 Fokus 1, L-016 Menüzeile 12/12; W-03, W-04, W-05, W-06, W-07 (Namenssuche); Status-Umbenennung; Textstile `apple`; design-system/ gelöscht; Proben 7 A/B raus; `INHALT.json` Gruppen.
**Schlampig erledigt (nachbessern)**:
1. T2 Bauteile: Zustände leer, Maße zur Hälfte, Muster-Flows geraten, `category` per Regex, `layer` per Name.
2. T4 Texte: Regex-Extraktion, Gaps, Schlüssel erzeugt, kein `en`.
3. W-07: 47 Felder nach erstem Wort gesucht (31 „im Bogen“ können Fehltreffer sein, z. B. „Name“, „Telefon“).
4. W-01/W-02: `akte.json` zählt neu, Begleitdokumente (UEBERGABE, PROMPT-alt, AUDIT.md, RUECKGABE-AN-CODE) nennen teils alte Zahlen und Bezeichner.
5. L-008 Konto-Formular: Felder aus abgeschnittener Quelle (`INHALT.json:1063`), Anbieterliste nur Johannes' drei Beispiele, keine Port-Prüfung, Passwort liegt im Zustand, Konto hat keine E-Mail-Adresse; kein Sheet nach Brief („Konto-Sheet“).
6. L-010 Signatur: nur das eigene Konto mit Beispieltext, Konten sonst leer; Wählen in Mail unverändert (Menü „Signatur anhängen“ im Entwurf).
7. L-012: Rückmeldung nur als Zeilentext, nicht als Hinweiskarte; kein Zeitverlauf.
8. L-013: Fragetext gekürzt („Konto entfernen?“, Johannes-Quelle länger: „… wird aus der App entfernt. Die Mails bleiben beim Anbieter“); Wrapper-Hack `margin-right:-3px`; Vorlagenname „Vorlage n“ von mir.
9. Assistent-Zustände: nur gezeichnet; Texte „Denkt …“ und Beispielantwort von mir.
10. Konto-Wähler: gebaut, Klickfolge/Esc/Kontrast ungeprüft; Verifier fand einen Fehler (Adresse), behoben, danach nicht neu durchgeklickt.
11. Prüfer: P1 bis P3 nur als JS-Ports; Original-Python nie gelaufen.
**Ausstehend (Design kann)**: Zeilen 5.1 bis 5.11 beheben; `werte-abgleich.json` per Skript (T7), W-08 bis W-10; Mechaniken in den Vertrag; Zustands-Tokens; englische Namen unter der Oberfläche (Prop-Werte System/Geist/Ring, Zustandswörter `lädt`, `leer`, `nicht erreichbar`, Dienstzustände, `kind: "setting"`, deutsche `data-state`-Werte) mit Texten in `texts.json`; Assistent in `ALFA Shell` bauen (nach Sicht); Diagonale Toleranz (nicht baubar ohne Ziel, `TODO-ABGLEICH` A4); Kachelnamen (A9); Logos (A10) mit Material.
**Ausstehend (nur Johannes)**: Sperre je Ansicht; Farbleiter; Fensterhöhe; Reife (baut Code `set-by-design`?); Maßband-Lupe liefern; „Blob anheften“ erklären; Logos; Kachelnamen; Kind-DCs; Systemfrage iOS/iPadOS/Web; Wahl/Abnahme Konto-Wähler und Assistent; „raus“.

## 6 · Zehn Schritte zurück: durchkämmen
Jeder Schritt endet mit einem prüfbaren Kriterium.
1. **Quellen frisch lesen**: CLAUDE.md, beide HANDOFF-Dateien, `entscheidungen.md` ab 18.10., Code-Gedächtnis im Repo (`.claude/memory/stand.md`, `app-*`). Kriterium: Liste „Johannes entschieden / offen“ stimmt mit HANDOFF-SESSION-4 Abschnitt 4 überein, Abweichung notiert.
2. **Zahlen und Namen vereinheitlichen**: eine Tokenzählung, ein Statusvokabular, alte Bezeichner (v2, design-system, eine Logikdatei, 368, designSet in Berichten) in den Berichten bereinigen. Kriterium: Suche nach den alten Wörtern liefert nur noch Historie mit Datum.
3. **Fundstellen reparieren (W-08)**: je Token mit `where` die Zeile im aktuellen Quelltext suchen und schreiben; Tokens ohne Beleg erhalten `where` oder werden als `set-by-design ohne Fundstelle` gelistet. Kriterium: `pruefung.js` meldet 0 Fehler bei Fundstelle für alle 213.
4. **Literale in Tokens führen**: Abschnitt 3.5 abarbeiten. Kriterium: Skript findet keine px/ms-Werte der neuen Teile außer Tokens, Rolle je Wert notiert.
5. **Mechaniken und Zustände in den Vertrag**: `mechanik.json` → `components.json` (`mechanics`, `states.tokens`), Flows der 7 Muster gegen Quelltext und Bild prüfen. Kriterium: P1 und P2 grün, jedes Muster mit gemessenem Zustandswechsel (Übergänge aus).
6. **Texte vervollständigen**: dynamische Texte als Schlüssel mit Platzhaltern, `en` für alle, sprechende Schlüssel für die 40 wichtigsten Elemente. Kriterium: 0 Gaps im t4-Lauf, jedes Element mit sichtbarem Text hat `textKey`.
7. **Ansichten ausbauen**: Aktionen aller drei Ansichten inklusive Zustände Fehler/Leer/Laden und Konto-Wähler. Kriterium: jede interaktive Fläche der Bögen hat eine Aktion oder steht als bewusst weggelassen im Bericht.
8. **Neue Teile messen**: Konto-Wähler, Konto-Formular, Entfernen-Pille, Signatur: Kontrast hell/dunkel, lange Adressen, Klickfolge mit echter Maus (Johannes), Gruppen und Datensätze. Kriterium: Protokoll wie `KONTRAST-PROTOKOLL.md`, Funde behoben.
9. **Englische Namen unter der Oberfläche**: Prop-Werte, Zustandswörter, `kind`, `data-state`. Kriterium: `pruefung.js` Regel „Name nicht englisch“ erweitert und grün; sichtbare Wörter nur aus `texts.json`.
10. **Vertrag und Bögen abgleichen, dann Johannes**: `diff.js` gegen Basis, Block mit sprechenden Gründen (≤ 120 Zeichen), P1 bis P3, Fremd-KI-Audit nach AUDIT.md vorbereiten, ABNAHME Zeile für Zeile. Kriterium: alle zwölf Zeilen ✅ oder offen mit Grund; Meldung „fertig“ nur bei zwölf ✅; Lieferung erst nach „raus“.

## 7 · Fallen
- `github_copy_files path_prefix` entfernt den Präfix (Dateien landen im Wurzelordner).
- `new Function` + `readFile` in `run_script` ersetzt Python (validate/check/diff).
- Beim Neuerzeugen des Vertrags nie die Hand-Änderungen überschreiben: `views.json`, `changes.json`, `base.tokens.json` (`$extensions`, `rules`), Resolver. Ablauf: Basis kopieren nach `contract-build/previous/<stamp>/`, erzeugen, `diff.makeBlock`, P1 bis P3, dann schreiben.
- Das Prüf-Fenster zeigt linke und mittlere Bahn bei 924 px gefaltet: Wähler dort erst nach `setMem({Lf:false})` sichtbar.
- Code baut aus dem Master 1810 (nicht aus 19.10.); Änderungen vom 19.10. kennt Code nicht, bis Johannes „raus“ sagt.
