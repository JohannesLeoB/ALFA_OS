# START HIER · Übergabe an eine frische Design-Session (zweites Konto) · 28.10.2026
Stand: Lieferschein 2026-10-28T15:40. Du übernimmst ein laufendes Projekt (ALFA OS: Mail und Einstellungen, Hülle Shell). Nichts davon ist dir bekannt. Lies diese Datei ganz, dann in der Reihenfolge unten. Dieses Paket ersetzt START-HIER-ZWEITES-KONTO.md (24.10., veraltet, nicht mehr enthalten).

## 1 · Import (dein erster Schritt)
- Kopiere JEDE Datei dieses Pakets an denselben Pfad in den Projektstamm (auch contract/, contract-build/, lieferung-an-code/, material/, DESIGN/, uploads/). **PROJEKT-REGELN.md ist der Inhalt von CLAUDE.md** (der Name ist im Paket gesperrt): lege ihn nach dem Import als CLAUDE.md in den Projektstamm, ohne die erste Kommentarzeile. **support.js nicht überschreiben**, wenn dein Projekt schon eine hat.
- Öffne ALFA Mail.dc.html und ALFA Einstellungen.dc.html; melde Johannes in drei Zeilen: lädt es, wie viele Bögen (soll 9), fehlt eine Datei in contract/ (soll 13 Dateien).
- Danach nichts bauen, bis Johannes „weiter“ sagt.

## 2 · Lesereihenfolge
1. CLAUDE.md = PROJEKT-REGELN.md (drei Stopp-Regeln, unten Abschnitt 3).
2. entscheidungen.md, die letzten 80 Zeilen (Wortlaut aller Ansagen von Johannes, mit Datum; neueste unten).
3. lieferung-an-code/START-CODE-2810.md, ANTWORT-2810.md, OFFEN-AN-CODE-2710.md (das ist die Liste, die auch Code bekommen hat).
4. lieferung-an-code/ENTSCHEIDUNGEN-AN-CODE-2310.md, SPEC-NACHTRAG-2310.md, ABLAUFPLAN-UEBERGABE.md.
5. DESIGN/brief/BRIEF.txt (Brief v14 von Code an Design: Teile T1 bis T10, Fragen N1 bis N43, Regeln A1 bis A6) und die Schemas dort.
6. uploads/RUECKGABE-AN-DESIGN-2710.txt (letzte Rückgabe von Code, 27.10.).
7. contract-build/README.md.

## 3 · Regeln (CLAUDE.md und Johannes, gelten immer)
- **Hülle nur einmal:** alles Übergreifende (Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände, Radien, Bewegung, Assistent) sofort und vollständig in ALLEN Ansichten gleich. Es liegt in ALFA Shell.dc.html, alfa-shell.js, alfa-bausteine.js, alfa-theme.css.
- **Belegpflicht, Erfindungssperre:** keine Aussage, Zahl, Frage oder Änderung ohne Quelle (Datei:Zeile, Zitat). Fehlt der Beleg, nicht eintragen.
- **Keine ZIPs, keine Downloads ohne ausdrückliche Freigabe von Johannes.** Das Paket vom 28.10. war freigegeben.
- **Suchen vor Fragen:** erst im ganzen Projekt, in den Notizen und im Repo (GitHub JohannesLeoB/ALFA_OS, Zweig main; DESIGN/ liegt dort nicht mehr im Stamm), erst ohne Treffer fragen.
- **Prüfer ablesen:** vor „fertig“ oder „geprüft“ P1 bis P4 und pruefung.js laufen lassen und die Ausgabe wörtlich nennen. Selbst nachmessen, nicht behaupten.
- **Vertrag nur über die Werkzeuge** in contract-build/ (apply.js), keine Handänderung an contract/*.json.
- **Keine Farbwelten, kein ALFAcolor.** Farbbögen sind gesperrt.
- Antworten kurz, Deutsch, kurze Wörter. Jede Ansage von Johannes sofort in entscheidungen.md (Datum, Wortlaut, was daraus folgt).
- Namen unter der Oberfläche strikt englisch: Tokens camelCase, data-part kebab-case, Bauteilnamen PascalCase, data-id bereich.teil, Textschlüssel bereich.teil.rolle. Brief A1: jeder Wert steht als Token im Vertrag; Bögen lesen ihn per var(--…).

## 4 · Stand
- **Bögen (9):** ALFA Mail, ALFA Einstellungen, ALFA Shell (Hülle), ALFA Bestaetigen — diese vier gehen an Code. ALFA Designsystem, ALFA Dienste, ALFA Widgets, ALFA Icon, ALFA Tokenbogen: Nachschlagebögen.
- **Gelöscht, nicht wieder anlegen:** ALFA PDF (N16: macOS nativ), ALFA Huelle, alle Farbbögen (Mail Color, Farbleiter, Farbsystem, Farbsystematik, Entscheidungsblatt Farbe, Entscheidungen).
- **Vertrag:** 487 Tokens, 97 Bauteile, 230 Elemente, 444 Texte (alle de und en), 3 Ansichten. Änderungsprotokoll: ein Block (667 Änderungen) gegen contract-build/previous/2026-10-23T-vor-uebergabe.
- **Lieferschein:** 44 Punkte, 30 erledigt. Offen: N27, N28, N29, N30, N31, N33, N38. Fragen: T5, T6, N15, N20, N26, N35, N43.
- **Prüfer 28.10. 15:40:** P1 contract: valid · P2 consistent · P3 log matches (667) · P4 items: 30 of 44 done, delivery: complete · pruefung.js gruen true.
- **Zuletzt gebaut:** N37 Assistent im Blob (ALFA Shell :89 ff.); Postfachstapel-Tokens; MAIL-G01 Mail linke Bahn 224 bis 280; Fläche der Postfächer Vorgabe Lack; N32 gestrichen; Startschutz data-alfa-boot (alfa-shell.js).
- **Code (Repo ALFA_OS):** baut nach dem Bogen; hat Postfachstapel, Menübreiten, Tokens, en-Texte, Hilfetext-Verweilen, Blob-Punkt gebaut. Siehe uploads/RUECKGABE-AN-DESIGN-2710.txt.

## 5 · Werkzeuge (im Skriptfenster)
- **Vertrag ändern:** contract-build/apply.js. Aufruf: const AF = Object.getPrototypeOf(async function(){}).constructor; await new AF("io","spec", await readFile("contract-build/apply.js"))({readFile,saveFile,ls}, spec). Spec-Felder: stamp, reason, tokens {pfad:[wert, beschreibung, "px"|"ms"|"number"|"easing", fundort]}, ext {pfad:{where}}, colors {name:{light:[r,g,b,a],dark:[…],hex,desc,where}}, dropTokens, texts [[schlüssel, de, art, element, en]], components, elements [{part,id,where}], dropComponents, dropTexts. Es prüft P1 bis P3 vorher und schreibt nur, wenn alle leer sind (Rückgabe written).
- **Ein Lauf am Ende:** contract-build/lauf.js führt die Blöcke von apply.js zu einem Block zusammen, erzeugt Lieferschein (Prüfsummen) und PRUEFUNG.txt neu, rechnet akte.json und läuft P1 bis P4 und pruefung.js. Erst mit { write: false } messen, dann { write: true }. Kopf der Datei erklärt den Aufruf.
- **Fundstellen:** nach Bogenänderungen verschieben sich Zeilen. Bauteil-where neu aus den Bögen mit contract-build/t2-components.js; Token-where per Skript prüfen (Zeile enthält Wert, Variable oder Namen).
- **Bahnen messen:** alfa-shell.js lässt sich mit Platzhalter-Fenster in einem Skript laden (window, document als Proxy) und über Breiten 640 bis 2200 durchrechnen (A.geo, A.layout, A.grow).

## 6 · Unerledigt (Reihenfolge nach Dringlichkeit; jeweils mit Beleg im Lieferschein oder in OFFEN-AN-CODE-2710.md)
1. **N38:** Blob-Zustand bei „Assistent ganz aus“ (Karte im Assistent ist gezeichnet, Blob selbst nicht), Abgleich je Bereich (Code gleicht nur Mail ab, AppHost.swift:55–61, alter Stand), Zeit im Tooltip des Abgleich-Knopfs (Bogen: „Neu laden · Gerade abgeglichen“, Mail syncTitle).
2. **N27, N28, N29, N31, N33 zeichnen** (Hub: Katalog, Verwalten je Dienst, Mitteilungen, Detailbericht, Quellenwahl Kontakte). Die Daten liefert Code nach Bedarf (OFFEN D). N30 (Dateiorte und Projektordner: Wahl von Ort — Mac, Google Drive, Dropbox, Server — und Ordner; Zustand ohne Wahl) hat im Lieferschein keinen Text; Beleg: DESIGN/brief/BRIEF.txt:164.
3. **Zustände je Bauteil in components.json** (Brief A6): 39 Bauteile haben im Bogen Hover, Aktiv, Fokus oder data-state, im Vertrag nur „rest“ (Liste in OFFEN-AN-CODE-2710.md J). Mit Tokens nachtragen, über apply.js.
4. **Brief A1, Zahlen in der Logik:** 146 Tokens stehen im Vertrag, aber die Logik schreibt die Zahl (Liste OFFEN C). Logik auf var-/Token-Lesen umstellen, Bild vorher und nachher messen (Bauteil für Bauteil, 0 Abweichungen). pruefung.js erweitern um „Zahlen in der Logik“.
5. **Assistent, Rest von N37:** Aktion der Entwurfskarte; eigene Formen für estimate, estimateBreakdown, calendarLink, driveFiles, contactDraft, taskChangeDraft, appointmentDraft, cartDraft, fileDraft, Bildvorschau (Code: Sources/Assistant/Model/Message.swift, ContentBlock). Beleg lesen, bevor du zeichnest.
6. **Erst-Setup zeichnen (Arbeitsliste Punkt 7):** wartet auf ein Wort von Johannes; vorher im Repo und in den Notizen suchen.
7. **Vermessung (Punkt 8):** Ringachsen, lange Inhalte bei 280/308/320, Kontrast hell und dunkel, alle Texte de und en. **Zustandsbogen (Punkt 9):** jede Mail-Ansicht in jedem Zustand, je in vier Modi. Bisher nicht gebaut.
8. **Textschlüssel:** Code verwendet eigene Schlüssel (Resources/Localizable.xcstrings), die texts.json-Schlüssel gibt es dort nicht. Datei aus dem Repo lesen (GitHub) und zuordnen, wenn Johannes es will.
9. **LIEF-T8:** Schema delivery.schema.json verlangt für erledigte Punkte ein where in einem Bogen; T8 zeigt auf einen Platzhalter (ALFA Mail.dc.html:289). Code hat zugestimmt, Dateipfad zuzulassen; das Schema ist Code-Sache.
10. **N43** kann geschlossen werden: Code 27.10. „Rechenschutz, kein Designwert, bleibt so“ (RUECKGABE-AN-DESIGN-2710.txt). Johannes hat nichts anderes gesagt.
11. Nach jeder Arbeit: lauf.js, Prüfer wörtlich ablesen, entscheidungen.md, Antwort an Code in lieferung-an-code/ANTWORT-*.md ergänzen.

## 7 · Offene Fragen an Johannes (nicht selbst entscheiden)
- **T5** Logos fehlen (Google, Mail-Konten, ClickUp, Claude, Airtable, sevDesk, Happa Happa): liefern oder Kürzel im Ring als Dauerlösung?
- **T6** Kartenstapel 8a/8b als Einstellung in Einstellungen wählbar?
- **N15** Aus Projektordner: Quelle, Ebenen, Höchstzahl, Fehlertexte von Code (spec-mail F28).
- **N20** Menüvorschläge (Verschieben, Notiz, Original, Später senden, Lesebestätigung, Vorlage) und Formatleiste: je Fall.
- **N26** Baum nach Zugehörigkeit in Einstellungen: Spec von Code und Wort von Johannes.
- **N35** Lage des Toasts: Bogen über dem Blob, Code darunter: Wort von Johannes.
- **Mailboxname-Menü „Angezeigt als“** und **springende Geisterkarte beim Wechsel** (Code-CLAUDE.md, nicht gezeichnet bzw. offen).
- Wenn Johannes ein neues Konto/Projekt schreibt: Wortlaut sofort in entscheidungen.md.

## 8 · Bekannte Fallen
- Props der Bögen stehen als &quot;-kodiertes JSON im data-props-Attribut (Mail :335, Einstellungen :186); beim Ändern dort suchen, nicht neu schreiben.
- Mail ist über 900 Zeilen mit sehr langen Zeilen; mit run_script suchen und mit exakten Ersetzungen ändern (Anzahl der Treffer prüfen).
- ready_for_verification meldet einen Hinweis zu github.md, sobald du GitHub liest: github.md mit Datum, gelesenen Dateien und Screen map aktualisieren.
- Beim Paket für Code: der Dateiname CLAUDE.md ist dort gesperrt; Inhalt als PROJEKT-REGELN.md.
- Die erste Darstellung kommt vor den Tokens: alfa-shell.js setzt data-alfa-boot und schaltet Übergänge bis 600 ms nach „alfa-tokens“ aus. Nicht entfernen.
- Nach jeder Änderung an einem Bogen ändert sich dessen Prüfsumme: Lieferschein erst am Schluss neu erzeugen (lauf.js).
