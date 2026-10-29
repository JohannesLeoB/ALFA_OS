# START HIER · Übergabe an eine frische Design-Sitzung (anderes Konto) · 24.10.2026
Arbeitsstand, nicht freigegeben. Von Johannes' Design-Sitzung geschrieben. Du bist die neue Sitzung: lies zuerst diese Datei ganz, dann CLAUDE.md, dann `lieferung-an-code/ABLAUFPLAN-UEBERGABE.md`.

## 0 · Erste Handgriffe (in dieser Reihenfolge)
1. Liegt das ZIP in `uploads/`: entpacken (run_script, ZIP lesen) und **jede Datei an denselben Pfad im Projektstamm kopieren**, auch `CLAUDE.md`, `contract/`, `contract-build/`, `lieferung-an-code/`, `material/`, `DESIGN/`, `design-branch/`. Die Datei `CLAUDE.md` gilt nur, wenn sie im Stamm liegt.
2. Prüfen: Es müssen im Stamm liegen: 18 Bögen `ALFA *.dc.html` (alle 18 stehen in `LIEFERUNG.json` drafts), `alfa-shell.js`, `alfa-bausteine.js`, `alfa-theme.css`, `TOKENBOGEN.json`, `entscheidungen.md`, `github.md`, `contract/` (u. a. `LIEFERUNG.json`, `components.json`, `texts.json`, `changes.json`). `support.js` schreibt die Umgebung selbst; nicht überschreiben.
3. `ALFA Mail.dc.html` öffnen und ansehen. Erst wenn Mail und Einstellungen laden, weiterarbeiten.
4. Nichts neu entwerfen. Nichts „verbessern“. Weiterarbeiten nach Ablaufplan.

## 1 · Was NICHT mitkommt (selbst klären)
- Chat-Verlauf und Kommentare. Alle Ansagen von Johannes stehen in `entscheidungen.md` (Zeilen ab 380 sind 22./23.10.).
- Der lokale Ordner `ALFA_OS` (Code-Repo) und der Ordner `dist` (Code-Lieferungen): Johannes muss sie in der neuen Sitzung wieder anhängen. Kopien der wichtigsten Stände liegen in `material/master-1810/` und `DESIGN/brief/BRIEF.txt` (Brief v14).
- Die GitHub-Verbindung (`JohannesLeoB/ALFA_OS`, Zweig main): neu verbinden. Inhalt: `DESIGN/`, `.claude/memory/` (stand.md, spec-*.md).
- Angehängtes Designsystem: falls es in der neuen Sitzung fehlt, nicht ersetzen; die Werte stehen in `alfa-theme.css` und `TOKENBOGEN.json`.

## 2 · Regeln von Johannes (CLAUDE.md, unverändert gültig)
- **Hülle nur einmal:** Alles, was die übergreifende Hülle betrifft (Blob, Abgleich, Personenmarke, Bahnen, Griffe, Abstände, Radien, Bewegung), ändert sich sofort und vollständig in ALLEN Ansichten (Mail, Einstellungen, weitere) und gleich.
- **Belegpflicht, Erfindungssperre:** Keine Aussage, Zahl, Frage oder Änderung ohne Beleg mit Quelle und Zeile. Fehlt der Beleg: nicht eintragen.
- **Keine ZIPs, keine Downloads ohne Freigabe:** Kein Lieferpaket, solange Johannes nicht ausdrücklich sagt „100 % sauber, darf raus“. `lieferung-an-code/` ist Arbeitsstand.
- **Suchen vor Fragen:** Erst im ganzen Projekt, in `dist/`, im Repo lokal und auf GitHub suchen (`DESIGN/`, `.claude/memory/spec-*.md`, `stand.md`). Eine Frage ohne diese Suche ist ein Fehler.
- **Vor „fertig/geprüft“:** Prüfer laufen lassen und die Ausgabe ablesen (P1 contract, P2 consistent, P3 log, P4 check-delivery), nicht annehmen. Selbst nachmessen (computed styles), nicht behaupten.
- **Vertrag nur über die Werkzeuge** in `contract-build/` (apply.js, t1, t2, t4, t9, diff.js, check.js, validate.js, check-delivery.js). Keine Handänderung an `contract/*.json`.
- **Farbe:** Keine Farbwelten, kein ALFAcolor. Die Farbbögen (`ALFA Mail Color`, `ALFA Farbsystematik`, Farbleitern, Entscheidungsblatt Farbe) sind gesperrt und gehen nicht an Code.
- **Antwortstil:** knapp, direkt, Deutsch. Kurze Wörter statt Kürzel (Johannes versteht „N15“ nicht ohne drei Wörter dazu). Eine Änderung = eine Zeile Eintrag in `entscheidungen.md`.

## 3 · Stand in einem Absatz
Bögen: Mail (mit Postfach-Stapel, Postausgang, Übersicht, Kachelansicht), Einstellungen, Shell/Hülle, Dienste, Bestätigen, PDF, Widgets. Brief v14 von Code (`DESIGN/brief/BRIEF.txt`, per Skript gezählt: T1–T8 und 36 N-Punkte; N11, 12, 14, 18, 25, 34, 42 fehlen, zusammengelegt oder nie vergeben) ist veröffentlicht und gegengelesen (`lieferung-an-code/GEGENLESE-v14.md`). Lieferschein `contract/LIEFERUNG.json` steht auf v14 und besteht das Schema; 44 Punkte: 27 erledigt, 8 offen (nicht gezeichnet: N27, N28, N29, N30, N31, N33, N37, N38), 9 Fragen (T5, T6, N15, N16, N20, N26, N32, N35, N43). Gestern gemessen: 59 von 59 `where`-Zeilen zeigen auf vorhandene Zeilen; 4 von 18 Entwurfs-Prüfsummen sind veraltet (Einstellungen, Icon, Mail, Shell; die zweite Sitzung zählte 5 mit Mail Color: dort selbst nachrechnen, möglich sind andere Zeilenenden nach dem Entpacken) (neu erzeugen, Phase 5.2). P4 ist noch nicht gelaufen.

## 4 · Arbeitsliste (aus der laufenden Sitzung übernommen)
In dieser Reihenfolge. Jeder Punkt: Beleg suchen, bauen über Werkzeuge, prüfen, in `entscheidungen.md` eintragen.
1. **Vertrag über die Werkzeuge aufsetzen** (Ablaufplan Phase 1): neun Handeinträge von heute (Bauteile account-title, account-deck, account-card, envelope-stack, envelope, switch-glass, settings-account-name, settings-account-show, hint; Tokens switchIn 360, switchOut 760, hintDwell 3000, hintRadius 7, foldAt 112; vier Texte) in `lieferung-an-code/bauteile.json` aufnehmen und per `apply.js` einspielen (erst Probelauf, dann write). Zustand der Handänderungen: siehe `contract/changes.json`, Block 2026-10-23T20:00 und `contract-build/previous/2026-10-23T-vor-uebergabe/`. Hinweis: Das Zurücksetzen auf 21.10. ist verworfen (verliert Werkzeugläufe vom 22.10.). Stempel in `changes.json` 22T01:15 und 22T22:15 stehen nicht in Reihenfolge; vor P3 prüfen.
2. **Hilfetexte an Griff und Blob** (Shell :40, :53): erst nach 3 s Verweilen, Zeiger in kleinem Umkreis (Bewegungstoleranz), Token hintDwell, hintRadius. Spec HUELLE-H01. Nicht gebaut.
3. **Blob-Punkt** nur bei Antwort des Assistenten im verdeckten Zustand (Spec HUELLE-F10, F11). Anzeigeeffekt auf der Vorderseite später definieren (Johannes: „definieren wir später“).
4. **Punkt am Postausgang** im gefalteten Streifen: Signalfarbe (Code färbt „gescheitert“ in Signal, `MailCardView.swift:143`). Im Bogen noch schwarz.
5. **Untertitel der Kacheln in Einstellungen** (`ALFA Einstellungen.dc.html` :233–:235, :236, :335): nur Wert oder Status aus der echten Anbindung, sonst leer. Keine erfundenen Texte.
6. **Zeichnen, was fehlt** (Brief v14): N27 Katalog mit Kategorien und Filter, N28 Verwalten je Dienst, N29 Mitteilungen je Dienst und global stumm, N31 Detailbericht, N30 Dateiort/Ordnerschema (Stand open im Lieferschein), N33 Quellenwahl Kontakte, N37 Assistent mit Eingabe/Antwort/Verlauf, N38 Blob bei „Assistent ganz aus“, Abgleich je Bereich, Zeit im Tooltip. Daten je Dienst liefert Code; nichts erfinden.
7. **Erst-Setup** (v14 Teil 4): zeichnen, sobald Johannes ein Wort dazu hat; vorher suchen (`.claude/memory/spec-hub.md`, `spec-huelle.md`).
8. **Vermessung per Skript** (Ablaufplan Phase 4): Ringachsen (Liste 16, Karte Radiusmittelpunkt 20, Streifen 28), Material Postfachkarte gegen Stapelkarte (eine Funktion `stackShadow`, gespiegelt), lange Inhalte bei 280/308/320 px, hell/dunkel/Kontrast, jeder sichtbare Text in `texts.json` de/en.
9. **Zustandsbogen:** jede Mail-Ansicht in jedem Zustand (lädt, leer, Fehler, offline, Entwurf, Übersicht, jede Faltkombination) in vier Modi (hell, dunkel, Kontrast hell, Kontrast dunkel).
10. **Lieferschein neu erzeugen** (Phase 5.2): where-Zeilen und Prüfsummen, `akte.json` Stand und export, Begleitdateien (SPEC-NACHTRAG-2310, ENTSCHEIDUNGEN-AN-CODE-2310, GEGENLESE-v14, ANTWORT-2310). P1–P4 laufen lassen und wörtlich ablesen.
11. **Vorlage an Johannes** (Phase 6): eine Seite mit Prüfergebnissen und offenen Fragen. Dann warten. Kein Paket ohne seine Freigabe.

## 5 · Offene Fragen an Johannes (nur stellen, wenn die Suche ergebnislos war)
- Augen in Ruhe: Master, Code und Bogen sind gleich (halb geschlossen, `lidRestScale` 0,45, `blobLidOffset` 1,4); von Code-Seite beantwortet, nichts zu ändern. Johannes fragte am 22.10. nach „Strichen“ (`entscheidungen.md:398`); seine Antwort steht aus. HUELLE-F09 heißt deshalb „offen bei Johannes, kein Bauauftrag“. Kein Widerspruch.
- Ringachse rechter Stapel 22 (Master) oder 20 (Radiusmittelpunkt wie links, :420). Kein Wort von Johannes.
- Toast-Lage: Bogen über dem Blob, Code darunter (`CardPile.swift:37–42`) (N35).
- N15 „Aus Projektordner“: Funktion von Code zu specen (spec-mail F28, spec-projekte F11). Menü im Bogen ist Demo; nichts erweitern.
- N26 Baum nach Zugehörigkeit, N32 „Schlüssel gespeichert/Verwaist“, N43 `releaseSpan`/`pointerStep`: siehe `LIEFERUNG.json`.
- Ob die Serviette (Gesten Gleiten/Tauschen, vier Zustände, Achsen) gilt: Vorschlag, nicht entschieden. Nicht bauen.

## 6 · Wo was liegt
- Ansagen und Entscheidungen: `entscheidungen.md` (neueste unten). Specs: `lieferung-an-code/SPEC-NACHTRAG-2310.md`. Verbindliches an Code: `lieferung-an-code/ENTSCHEIDUNGEN-AN-CODE-2310.md`.
- Plan und Selbstkorrektur-LOG: `lieferung-an-code/ABLAUFPLAN-UEBERGABE.md`, `PLAN-2310.md`.
- Vertrag: `contract/` (components, texts, changes, base.tokens, LIEFERUNG, akte). Werkzeuge: `contract-build/` (README dort).
- Code-Stand lesen: GitHub `.claude/memory/stand.md`, `spec-huelle.md`, `spec-mail.md`, `spec-hub.md`, `DESIGN/brief/BRIEF.txt`; lokal `ALFA_OS/alfaos/…` (Swift).
- Master von Code (18.10.): `material/master-1810/`.

## 7 · Berichtigt nach der Gegenprüfung der zweiten Sitzung (24.10.)
- Zahlen in Abschnitt 3 und 0 berichtigt (36 N + 8 T, 18 Bögen, N30 offen).
- `lieferung-an-code/decisions.json` existiert und ist gültig (Fragen A1a ff. mit Beleg). Der Satz in `entscheidungen.md:450` meinte: im Lieferschein gibt es kein Feld `decisions`. Dort berichtigt.
- Die ältere Sperre („Stempel“) in `contract/PRUEFUNG.txt:2` gilt weiter: nicht öffnen, nicht liefern.
- „Übergabe 23.10.“ in Codes `stand.md` ist Codes Stabübergabe an die nächste Code-Sitzung, nicht die Lieferung von Design.
