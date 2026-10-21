---
name: spec-arbeit
description: Wie an ALFA gearbeitet wird, soweit AGENTS.md es nicht schon regelt: Lesen, Fragen, Aufträge, Ablage, Design-Annahme, Prüfen, Haltung; dazu die Rolle der Draws-Sitzung und Merkmale eines guten Ergebnisses
metadata:
  type: project
---

# Arbeit · Spec (Stand 21.10.)

AGENTS.md ist die Verfassung. Diese Datei ergänzt nur, was dort fehlt, und verweist sonst auf `AGENTS §n`. Alle Quellen sind Johannes' Wort mit Datum und Sitzungskürzel, sofern nicht „Hinweis“ oder „Befund“ dasteht. Kürzel: a2df0c2a, 6a6a9365, 055e95fd, ffde6a84 (alte Linien, 08.–10.), 7cc894d9, a9bb817c, 97326b1d, c2a04c8a (Oktober, alte Lead-Linie), 3f52450e (Produkt-Sitzung 20./21.10.), bc4854d7 (Lead-Sitzung 21.10.).

## Ziel
Jede Sitzung arbeitet so, dass Johannes sich blind auf Beleg, Ablage und Kürze verlassen kann und seine Zeit nicht mit Fragen, Berichten oder Nachprüfen verbraucht. Die Regeln unten schließen die Lücken zwischen AGENTS.md und seinem Wort.

## Richtung (später)
- Prüfung auf der Wächter-Seite statt durch die Baustelle selbst (Abitur-Fächer, ARBEIT-R24), sobald Johannes sie dort will.
- Draws-Hinweise (ARBEIT-D04) werden Regel für ALFA_OS nur, wenn Johannes sie in der Lead-Sitzung selbst sagt.
- Distribution (App Store, iOS, iPadOS, Web, Abo) und Rollen als Einstellung kommen später (ARBEIT-R20, ARBEIT-R19).

## Arbeitsregeln

Lesen und Quellen
- **ARBEIT-R01 Nachricht ganz lesen**: Jede Nachricht von Johannes wird vollständig gelesen, bevor gebaut, geantwortet oder gefragt wird; eine Umsetzung, die einen Teil ausließ, gilt als Fehler (AGENTS §9). Ergänzt AGENTS §5 (dort Dateien). Quelle: J 05.10. a2df0c2a.
- **ARBEIT-R02 Funktion bleibt, Form wird neu**: Keine Ansicht und keine Funktion wird gelöscht, bevor sie den Umbau durchlaufen hat; zugleich wird nichts 1:1 neu gebaut, sondern jede übernommene Funktion samt Tokens, Nomenklatur, Kommentaren, Sprache und Zuschnitt auf die neue UI und Module gehoben, umfassend. Ergänzt AGENTS §6 Bestand. Quelle: J 05.10. a2df0c2a; J 20.10. 3f52450e.
- **ARBEIT-R03 Bestand zuerst, am Code belegen**: Vor jeder Lücke, Spec, Triage und Frage wird mehrfach und weit im Bestand gesucht; jede gefundene Funktion wird mit `Datei:Zeile` festgehalten. Gedächtnis, Karten, Zitatlisten, Briefe und Dokus gelten erst als belegt, wenn der Code sie trägt. Ergänzt AGENTS §2.3. Quelle: J 21.10. bc4854d7; J 20.10. 3f52450e.
- **ARBEIT-R04 Zitate vor dem Bau prüfen**: Ein Zitat in den Funktionskarten oder Artefakt-Hinweisen, auf dem ein Bau steht, wird vorher gegen das Transkript geprüft; bis dahin ist es Hinweis. Befund: 21 von 44 Karten-Zitaten waren am 20.10. nicht gefunden (seither teils gefunden: drei am 21.10. nachgewiesen). Quelle: Befund Lead 20.10./21.10., `.claude/memory/artefakte.md` (Quellenrisiko).
- **ARBEIT-R05 Wunsch, Wortlaut und Herkunft getrennt**: Sein Ja zu einem Verhalten ist keine Freigabe eines Textes; ein Design-Wert oder Design-Satz wird nie als sein Wort zitiert und führt nicht zu einer Frage an ihn. Ergänzt AGENTS §2 (letzter Absatz), §9 (Freigabe). Quelle: J 12.10. 7cc894d9; J 17.10. c2a04c8a; J 21.10. bc4854d7.

Fragen
- **ARBEIT-R06 Suchweg vor jeder Frage**: Vor einer Frage werden seine Transkripte mit `python3 -I` durchsucht: Nachrichten vom Typ `user`, eingereihte Nachrichten (`queue-operation`, `queued_command`) und Antworten der Fragewerkzeuge (`The user answered` im `tool_result`); Zeiten sind UTC. Treffer werden wörtlich mit Datum, Uhrzeit (Berlin) und Sitzung zitiert. Ergänzt AGENTS §9. Quelle: J 11.10. 7cc894d9; J 21.10. bc4854d7.
- **ARBEIT-R07 Recherchierbares wird nicht gefragt**: Was in Altcode, ALPHA, Hub-Struktur oder Bestand nachlesbar ist, fragt die Sitzung nicht. Quelle: J 21.10. 3f52450e (00:15 Berlin); J 20.10. 3f52450e (21:59 Berlin).
- **ARBEIT-R08 Fragen als Faktenliste**: Eine Vorlage an Johannes ist eine kurze Liste von „Facts“ zum Bestätigen, Ändern oder Verneinen, gesammelt, nie über mehrere Seiten; Antworten insgesamt sind auf einen Blick lesbar. Ergänzt AGENTS §9. Quelle: J 21.10. 3f52450e (00:45 Berlin); J 21.10. bc4854d7.

Aufträge und Meldungen
- **ARBEIT-R09 Meldezeile je Strang**: Der Strang meldet je Ereignis eine Zeile: Start (Ticket, Modell), Blockade (woran, was er braucht, wer entscheidet), Ende (Ergebnis, `Datei:Zeile`, was ungeprüft blieb). Blockaden, die Johannes lösen muss, stehen fett und als Frage. Ersetzt den toten Verweis `strang-meldungen.md` in AGENTS §3 (ARBEIT-L01). Quelle: J 20.10. bc4854d7 (15:34 UTC; „send me more updates“, Remote Control).
- **ARBEIT-R10 Auftrag mit Start, Stop, Ziel-Check**: Ein Auftrag an Strang oder Sub-Sitzung nennt Start, Stop und Ziel-Check, den vollständigen Arbeitsordner (R14) und was aufzuräumen ist. Vorher sucht die Lead Vorhandenes (README-Karte, Stränge, `scripts/`), und ein Brief mit Belegen geht erst nach Prüfung hinaus. Quelle: J 19.10. (Lead-Sitzung, Sitzungskürzel nicht belegt); Lead-Befund 18./19.10. (`spec-arbeit.md`).
- **ARBEIT-R11 Reihenfolge der Tickets**: Tickets werden in der Reihenfolge des effizientesten und qualitativ besten Ablaufs vergeben. Quelle: J 20.10. bc4854d7 (17:10 UTC).
- **ARBEIT-R12 Kein Kürzen mit Menschenmaß**: Umfang und Termine des Ziels (AGENTS §1) werden nicht mit Schätzungen nach menschlicher Arbeitsdauer gekürzt oder verschoben. Quelle: J 20.10. 3f52450e (22:37 Berlin).
- **ARBEIT-R13 Zwei Aufträge, eine Datei**: Zwei gleichzeitige Aufträge ändern nie dieselbe Datei im selben Ordner; Nebensitzungen bekommen deshalb einen eigenen Worktree (AGENTS §3). Befund Lead 20.10. (zwei Aufträge in `WholeAppTests.swift` vermischt), `spec-arbeit.md`.
- **ARBEIT-R14 Arbeitsordner im Auftrag**: Jeder Strang bekommt genau einen Arbeitsordner mit vollständigem Pfad, auch für `--scratch-path`, und löscht ihn am Ende; die Lead prüft danach `ls dist/`. Nichts liegt unter `alfaos/dist/` (ließ den Commit-Hook abstürzen); versteckte Ordner sind kein Ausweg. Ein Bericht ist kein Build-Ergebnis. Ergänzt AGENTS §11. Quelle: J 21.10. bc4854d7 (14:3x Berlin).
- **ARBEIT-R15 Modell je Aufgabe**: Gebaut wird über die Bau-Stränge mit Sonnet 5.5; Opus ist der Lead; Haiku prüft, liest gegen und gleicht Fakten ab (AGENTS §6, §9). Quelle: J 19.10. bc4854d7 (14:27 UTC „Bauen nur noch über die Bau-Stränge …“).
- **ARBEIT-R16 Eigencode zuletzt**: Vor eigenem Code gilt die Reihenfolge Apple-Framework, dann etablierter Standard, dann Eigenbau; fremde Pakete so wenige wie möglich. Quelle: J 20.10. 04:37 Stammtisch („der beste code ist der, der nicht geschrieben werden muss“); Reihenfolge und Paketsatz nur aus Archivar-Bericht, Hörensagen.
- **ARBEIT-R17 Übernahme aus Fundus und ALPHA**: Nicht mitgenommen werden UI, Nomenklatur, deutsche Namen, Slop, Eigenbauten, Dubletten, hart codierte Tokens und Schutzfunktionen (Schloss, Prüfstempel). Ergänzt AGENTS §6 (Bestand, Rechte). Quelle: J 12.10. a9bb817c (Rechte); übrige Punkte Archivar-Bericht, Hörensagen.
- **ARBEIT-R18 Stammtisch-Antwort**: Eine Stammtisch-Antwort gilt ab zwei fremden Belegen ohne offenen Zweifel und ist nie Freigabe (AGENTS §9). Quelle: J 19.10. 23:55 (Lead-Sitzung, Kürzel nicht belegt, F-07).

Produktgrenzen
- **ARBEIT-R19 Rechte später**: Wie Rollen und Sperren gegated werden, wird nicht vorab entworfen; die App kann zunächst alles, zudrehen geht später in den Einstellungen. Ergänzt AGENTS §6 Rechte. Quelle: J 13.10. 97326b1d; J 21.10. 3f52450e (00:50 Berlin).
- **ARBEIT-R20 Reichweite nicht verbauen**: Kit-Logik und Datenverträge bleiben so geschnitten, dass App Store, iOS, iPadOS, Web, Abo und fremde Nutzerstrukturen oder Integrationen später möglich sind; heute wird davon nichts gebaut. Ergänzt AGENTS §6 Logik. Quelle: J 12.10. a9bb817c; J 08.10. 055e95fd; J 26.09. ffde6a84.

Design-Annahme (ergänzt AGENTS §8)
- **ARBEIT-R21 Brief zuerst, dann Lieferung**: Bei einer neuen Lieferung wird erst der Brief an Design abgelegt, gepusht und als Prompt bereitgestellt; dann wird die Lieferung mit drei Prüfungen angenommen: Sauberkeit (Prüfskripte, lose Werte), die Memos von Design (ABNAHME.md, README, changes.json) und deren offene Punkte. Der Brief wird nicht gekürzt, um auf den Export zu warten. Jede belegte Lücke und jede Änderung der Arbeitsweise geht sofort in den Brief; erledigte Nummern fliegen nach der Lieferung raus. Quelle: J 20.10. bc4854d7 (22:39 Berlin); J 20.10. (Brief in GitHub aktuell halten).
- **ARBEIT-R22 Fehlendes im Master**: Was im geltenden Master fehlt, formuliert der Code als Funktions-Spec und Baubedarf im Brief; gebaut wird es nicht (AGENTS §7). Der Code gestaltet nie, auch nicht vorläufig. Quelle: J 18.10. (Lead-Sitzung, Kürzel nicht belegt); J 12.10. 7cc894d9 („reine Funktion … keine Haut“).

Prüfen (ergänzt AGENTS §9, §10)
- **ARBEIT-R23 Prüfung ohne Fänger fliegt raus**: Eine Prüfung, die nur Laufen, Kompilieren oder einen selbst angelegten Wert bestätigt, wird gestrichen; ein Test, der nirgends regelmäßig läuft, zählt nicht. Quelle: J 20.10. bc4854d7 (17:49 UTC; „Klassenraum gefunden“, „Stift dabei“).
- **ARBEIT-R24 Wer baut, prüft sich nicht**: Wer Code baut, schreibt und sieht die Prüfung seiner Arbeit nicht; Erwartungen kommen nur aus Master, Johannes' Wort und AGENTS.md, nie aus Code-Ausgaben. Die Prüfung gehört auf die Wächter-Seite. Das „Abitur“ umfasst: Master-Tokens, kein Eigenbau, Englisch, Texte, Größe, brechende UI, Wege ohne Rückkehr, Hygiene. Quelle: J 20.10. bc4854d7 (17:56 UTC „Abitur“). Offen: ARBEIT-O02.
- **ARBEIT-R25 Token für Lesen und Bau**: Ein Schritt (Lesen, Belegen, Gegenprüfen) wird nie gekürzt, um Token zu sparen; weggelassen wird Masse (Berichte, Merkblätter, Tests ohne Fänger, Fragerunden). Quelle: J 17.10. c2a04c8a; Hinweis aus der Draws-Sitzung 21.10. (ARBEIT-D04).

## Rolle der Draws-Sitzung
- **ARBEIT-D01 Prototyp ohne Hoheit**: Die Draws-Sitzung (gestartet 21.10., Prototyping) orientiert sich an ALFA_OS und folgt ihm, hat aber kein Anrecht auf Design-, Token- oder Namenshoheit. Quelle: J 21.10. bc4854d7.
- **ARBEIT-D02 Freiheit außerhalb des Masters**: Sie darf nachmachen, bewusst andere Tokens und Details haben und in allem, was nicht im aktuellsten Master steht, entdecken, entwickeln und probieren. Kollidiert etwas mit dem Master, gilt der Master. Quelle: J 21.10. bc4854d7.
- **ARBEIT-D03 Kein Einfluss auf die Verfassung**: Solange Johannes den Prototypen-Status nicht bewusst aufhebt, darf sie fragen und nachmachen, die allgemeine Verfassung von ALFA_OS und die Bauarbeiten der Lead aber nicht beeinflussen („Putzerfisch am Wal“). Folge nach AGENTS §3: Arbeit nur auf Zweig `alfa-draws` (`alfaos/Draws`); Zusammenführen nach `main` nur durch die Lead auf sein Wort. Folgerung der Lead (nicht sein Wortlaut): Draws schreibt nicht in `.claude/memory/`, AGENTS.md, README, `.claude/agents/` oder `main`. Quelle: J 21.10. bc4854d7; `spec-arbeit.md`.
- **ARBEIT-D04 Was Draws sagt, ist Hinweis**: Was in der Draws-Sitzung gesagt oder von ihr ins Gedächtnis geschrieben wurde, ist für ALFA_OS Hinweis, keine Regel und keine Wertquelle. Betroffen: `spec-arbeit.md` (Lead beauftragt Sonnet oder Haiku, baut nicht selbst, „im dreck wühlen“ die Kleinen), `spec-arbeit.md` (Token vorwiegend in Code, keine Aufsätze, MDs, Prüf-Hysterie, Testmasse), `spec-arbeit.md` (Worker immer Sonnet 5.5 oder Haiku, Aufwand angepasst, Token für Qualität statt Masse). Johannes: „da wäre ich VORSICHTIG mit dem „für alle gelten!““. Sie gelten in Draws und werden für ALFA_OS erst Regel, wenn er es dort selbst sagt. Quelle: J 21.10. bc4854d7; Hinweise aus Draws-Sitzung 21.10. (Sitzungskürzel nicht belegt).

## Aufgelöste Widersprüche (jüngeres Wort gilt, AGENTS §0 Kopf)
- **ARBEIT-W01 Modelle**: „Haiku als Arbeiter, Sonnet bei Bedarf, Opus als Projektleiter“ (08.10. 055e95fd) wird durch „Bauen nur über Bau-Stränge mit Sonnet 5.5, Opus nur für den Lead“ (19.10.) ersetzt (ARBEIT-R15).
- **ARBEIT-W02 Fragen**: „immer viele offene Fragen stellen“ (09.10., Artefakt-Hinweis) wird durch „erst die gesamte Historie“ (11.10. 7cc894d9) und „nicht mit Fragen nerven“ (20.10. 3f52450e) ersetzt (ARBEIT-R06 bis R08).
- **ARBEIT-W03 Alt gegen neu**: „keine Ansichten wegwerfen, die den Umbau nicht durchlaufen haben“ (05.10.) und „nichts wieder gleich bauen“ (20.10.) gelten beide: nicht löschen vor dem Durchlauf, aber nie 1:1 übernehmen (ARBEIT-R02).
- **ARBEIT-W04 Prüfen gegen Bauen**: „Weniger prüfen, mehr bauen, dann Gebautes prüfen“ (21.10. bc4854d7) gegen „jede Aussage mit Beleg“ (11.10.–18.10.): Vor-Prüfung nur bei riskanten Aufträgen (AGENTS §6); jede Aussage an Johannes bleibt belegt (AGENTS §9). Zwei Stufen, kein Widerspruch.
- **ARBEIT-W05 Meldungen**: „mehr Updates zu Strängen“ (20.10.) gegen „nicht 3 Seiten lesen“ (21.10.): viele, aber je eine Zeile (ARBEIT-R09).
- **ARBEIT-W06 Berichte**: `spec-arbeit.md` („Berichte gehen an Johannes, danach gelöscht“) gegen AGENTS §9 („keine Berichte“): AGENTS gilt; Berichte laufen nur im Chat und werden nicht abgelegt (ARBEIT-R14).
- **ARBEIT-W07 Token**: „Jeder Token, den du sparen willst, ist 10000facher Aufwand“ (17.10.) gegen „Token zu Code, keine Prüf-Hysterie“ (21.10., Draws-Hinweis): beide in ARBEIT-R25 vereint; die jüngere Aussage bindet nur Draws.
- **ARBEIT-W08 Alte Artefakt-Grundsätze**: „höchstens 10 Docs“, „Tests zählen nicht als Nachweis“, „keine Code-Kommentare“, „NICHTS ins REPO schreiben“, „Fragen immer“ sind durch AGENTS §6, §9, §10 und §11 überholt (`artefakte.md`, Hinweis).
- **ARBEIT-W09 Quelle des Designs**: „ALFA INTERFACE ist nicht unser goldener Gral“ (11.10.) wird durch „Quelle ist immer meine neueste Design-Lieferung“ (16.10. 97326b1d; 18.10. c2a04c8a) ersetzt; es gilt AGENTS §2.2.

## Woran man ein gutes Ergebnis erkennt
- **ARBEIT-E01 Prüfweg steht dabei**: Jede Aussage nennt, wie sie geprüft wurde (`Datei:Zeile`, Befehl, Prüfer) und was ungeprüft blieb; ohne Abnahme ist der Status höchstens Orange. Quelle: J 11.10. 7cc894d9; J 18.10. c2a04c8a (`spec-arbeit.md`); AGENTS §9.
- **ARBEIT-E02 Lücke statt Füllung**: Fehlendes ist als Lücke belegt, nicht durch zahlengleiche Tokens, abgeleitete Werte oder erfundene Namen ersetzt (AGENTS §6, §7). Quelle: J 17.10. c2a04c8a.
- **ARBEIT-E03 Prüfung kann rot werden**: Zu jeder neuen Prüfung gibt es einen Mutanten im Produktionscode, der sie rot macht; gemeldet werden gefangene und entkommene Mutanten, nie die Zahl der Tests. Quelle: J 20.10. (Lead-Sitzung, Kürzel nicht belegt); AGENTS §9, §10. Befund 20.10.: 43 von 84 Mutanten blieben grün (`spec-arbeit.md`).
- **ARBEIT-E04 Nur Funktionsbedingtes in der UI**: Jeder sichtbare Text in `Localizable.xcstrings` ist Titel, Beschriftung, Knopf, Fehler oder Warnung; es gibt keine Erklärsätze unter Knöpfen, Zeilen oder Karten. Fund im Master wird Johannes gezeigt, nicht still gebaut, und nicht bei Design angefordert. Quelle: J 21.10. bc4854d7; AGENTS §6, §8.
- **ARBEIT-E05 Ablage sauber**: Nach Sitzungsende zeigt `ls dist/` keinen Ordner der Sitzung; lokal und GitHub sind gleich (AGENTS §11, §13). Quelle: J 21.10. bc4854d7.
- **ARBEIT-E06 Kürze**: Die Meldung an Johannes passt auf einen Blick, nennt Stand, nächsten Schritt und Beleg und steht nicht auf mehreren Seiten (ARBEIT-R08). Quelle: J 21.10. 3f52450e.
- **ARBEIT-E07 Kein Nachprüfen durch ihn**: Johannes soll in der App so gut wie nichts selbst prüfen, ansehen oder korrigieren müssen. Quelle: Hinweis, Artefakt „ALFA Grundsätze“ Nr. 19 (08.10.), nicht gegen das Transkript geprüft.
- **ARBEIT-E08 Code vor Text (Hinweis)**: Der Aufwand eines Auftrags steckt überwiegend in Code, nicht in Berichten, Merkblättern, Fragerunden oder Testmasse. Quelle: nur Hinweis aus der Draws-Sitzung (`spec-arbeit.md`), siehe ARBEIT-D04.

## Lücken
- **ARBEIT-L01 Toter Verweis**: AGENTS §3 verweist auf `strang-meldungen.md`; die Datei gibt es nicht mehr, das Format steht in ARBEIT-R09. Ändern von AGENTS.md braucht seine Freigabe; liefert Johannes. Beleg: `AGENTS.md:24`; `grep -rn strang-meldungen AGENTS.md README.md .claude` nur diese Fundstelle, `ls .claude/memory/` ohne die Datei.
- **ARBEIT-L02 Kürzel fehlen noch**: Sitzungskürzel für ARBEIT-R10 (19.10.), ARBEIT-R18 (19.10. 23:55, F-07), ARBEIT-R22 (18.10.), ARBEIT-E03 (20.10.) und die Draws-Sitzung fehlen in den Quellen; liefert die Lead aus den Transkripten. Beleg: die Quellzeilen dieser Regeln in `spec-arbeit.md` tragen „Kürzel nicht belegt“. Erledigt am 21.10.: R09, R11, R15, R23, R24 stehen in Sitzung bc4854d7.
- **ARBEIT-L03 Wächter-Prüfung**: Ob das „Abitur“ (ARBEIT-R24) auf der Wächter-Seite existiert, ist ungeprüft; die Wächterdateien liest diese Spec nicht (AGENTS §10).

## Offen bei Johannes
- **ARBEIT-O01** Sollen die Draws-Hinweise (Lead baut nicht selbst, Token zu Code, Worker nur Sonnet 5.5 oder Haiku) auch für die Lead-Sitzung von ALFA_OS gelten?
- **ARBEIT-O02** Wer schreibt die Prüfung, wenn der Bau-Strang sie nicht schreiben darf (ARBEIT-R24): ein eigener Prüf-Strang oder allein die Wächter-Seite? AGENTS §10 verlangt Mutanten zu jeder neuen Logik und nennt die Lead als Verantwortliche.
