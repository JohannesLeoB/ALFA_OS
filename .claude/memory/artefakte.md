---
name: artefakte
description: "Hinweise aus 56 claude.ai-Artefakten (Grundsätze, Karten, Funde): Zitate teils nicht gefunden, nur Hinweise nach AGENTS.md §2.4, keine Quelle"
metadata:
  type: reference
---

ACHTUNG: Diese Datei ist Hinweis, keine Quelle (AGENTS.md §2.4). Die Zitate stammen aus Artefakten, nicht aus Johannes' Transkripten; 21 von 44 Zitaten der Funktionskarten waren am 20.10. im Korpus nicht gefunden, zwei davon am 21.10. nachgewiesen (Abschnitt Quellenrisiko). Vor jedem Bau, der auf so einem Zitat steht, den Wortlaut gegen das Transkript prüfen (`fragen.md`). Teil 1: die 20 Grundsätze. Teil 2: Karte der Artefakte.

# Teil 1: Grundsätze

Quelle: Artefakt „ALFA Grundsätze“ (Arbeitsunterlage zum Prüfen, Wahl Gilt/Ändern/Streichen; die gespeicherten Entscheidungen sind nicht gelesen). Zitate stehen dort mit Datum; nicht gegen Transkripte geprüft (siehe Quellenrisiko unten).

Ziel
- 1: „ALFA ist die eigentliche App die ich entwickeln will“ (10.10.).
- 2: „Die App als ERP denken, als interior design app, als indesign, Illustrator, cad etc“ (20.09.); „wir bauen das ja für unsere zwecke in Swift nach“ (03.10.); „Lokale App, aber native Webbasirte Daten“ (03.10.).
- 4: „nicht das nutzen, was es schon viel besser oder nativ … woanders EH gibt“ (19.09.). Spannung zu `app-ziel.md` (Vision, 19.09. 18:15 und 12.10.: nie wieder raus in andere Apps, besser als alle Dienste); das spätere Wort 12.10. gilt.

Kern und Code
- 5: „Globalen von ansichtsbereichs spezifischen trennen.“ (01.10.)
- 6: „es darf NIEMALS zwei Orte im Code geben, die designsnspruch oder Layout Regeln … beanspruchen.“ (18.09.); „EIN SYSTEM für alle dass immr alle mitzieht“ (10.10.)
- 7: „NICHT IM CODE hardcoded“ (10.10.); „Keine firnendaten im Code, keine Namen, Firmennamen.“ (09.10.)
- 8: „von jeder Firma … individuell eingerichtet“ (04.10.); „Multiuser multi configuration adaptability.“ (08.10.)
- 9: „Der gesamte Code muss strikt englisch sein.“ (22.09.); „Keine code commentate, meta, Zitate.“ (09.10.) Überholt in Teilen: AGENTS.md §6 erlaubt technische Kommentare in Englisch (ASD-STE100).
- 10: „ein element, ein name …“ (01.10.)
- 11: „Bugs, totes, sinnloses löschen.“ (09.10.)

Arbeitsweise
- 12: „NIEMALS ERFINDEN!“ (19.09.); „Nichts glauben …“ (09.10.); „ALLES AI SLOP wenn nicht real im Code 1:1 bewiesen“ (19.09.)
- 13: „was ich hier eingebe, IST IMMER vollständig zu lesen“ (05.10.)
- 14: „Es darf nie erledigt gemeldet werden, wenn nicht alles … bewiesen“ (29.09.); „…zu jedem einen exakten Beleg“ (13.09.)
- 15: „stelle … immer so viele … offene Fragen!“ (09.10.) Überholt durch fragen.md (11.10.: erst Historie lesen) und sein Wort 11.10. „Ich brauche auch keine Fragen…“.
- 16: „ES GILT WAS ICH ENTSCHEIDE!“ (06.10.)
- 17: „Ausgabetoken für Chatgespräch sind Heilig.“ (07.10.); „So wenige Docs und Dateien wie Möglich“ (06.10.)
- 18: „kein screenuse/computeruse oder ansichtsfenster eingriffe.“ (08.10.)
- 19: „ICH SELBER, will so gut wie NICHTS in der App selber machen, prüfen, anschauen oder korrigieren müssen.“ (08.10.)

Repo
- 20: „LOKAL NUR in ALLFARBEN, github maximal 1 Branch.“ (08.10.); „KEINE separaten Bau-Ordner“ (08.10.); „GITHUB immer direkt Pushen, commiten ( main)“ (09.10.) Ort überholt: seit AGENTS.md §11 lokal `~/Developer/ALFA_OS`.

Aus ALPHA Staffelstab (29.09., alte Linie, Herkunft): „Tests zählen nicht als Nachweis“ (27.09.) gilt nicht mehr, AGENTS.md §10 hält genau einen Test als Nachweis; „NICHTS ins REPO schreiben, NIEmals“ (29.09.) gilt nicht für App-Code unter `alfaos/`.

# Teil 2: Karte der Artefakte

Gelesen am 20.10. (sechs Leser, je zehn Artefakte, Abgleich gegen dieses Gedächtnis; Johannes: „Lies alle Artefakte der Liste vollständig und gleiche sie mit dem Gedächtnis ab.“). Alle Aussagen unten stammen aus den Artefakten selbst, nicht aus dem Repo; Datum je Artefakt ist der Veröffentlichungsstand.

Nicht lesbar oder leer
- Claude-Docs-Typ, Connector fehlt: Lastenheft Editoren (Funktionsebene), ALFA OS Design-Briefs Werkzeuge und Vorlagen, Lagebericht ALPHA: Code und Design.
- Leer: ALFA Designsystem, Design System, Untitled.
- Nur teilweise gelesen (Größe 2 bis 4 MB): ALPHA Inventur, ALPHA Inventur Lauf 2, UI-Testbogen; Kanon ohne api-Karten.
- Ohne Bezug zu ALFA: Uhren-App Zifferblatt, Hauptküche Folie und Planlayout, Ultraleichter Schreibtisch, kilo lux System, Licht-Stash Schaltbaum, johannesleoberger.com Neustart und Redesign, Plaster and Shadow, Die Bohne schwört Treue.

Quellenrisiko (Willensbaum, Stand 18.10., Commit 1785da4)
- 21 von 44 Zitaten der Funktionskarten (`app-*.md`) sind im Korpus nicht gefunden, 7 davon sind Auswahloptionen („Ja, ganz weg (Empfohlen)“). Nicht gefunden u. a.: „Blob sitzt über den Spalten!!“, „Die App ist auf Fullscreen ausgelegt.“, „…es seih denn die FIRMA (Admin) sperrt…“ (12.10. 17:40), „ALFA_OS ist MAIN App…“ (16.10. 20:31), „Erst nach dem Design-Nachzug“, „c - aber noch ohne Kalkulation“ (18.10. 13:11). Die Quelle kann außerhalb des Korpus liegen; belegt ist nur: nicht gefunden. Berichtigung 21.10.: „ALFA_OS ist MAIN App …“ und „Erst nach dem Design-Nachzug“ sind gefunden (Wortlaut und Fundstelle in `app-kataloge.md`). Die frühere Suche durchsuchte nur Nutzertext und übersah Klickantworten; Suchweg in `fragen.md`.
- Heißt: vor jedem Bau, der auf so einem Zitat steht, den Wortlaut gegen das Transkript prüfen (`fragen.md`).

Interface 11.10. (Artefakt „ALFA Interface · Stand 2026-10-11“, entscheidungen.md, Johannes 11.10.; Stand überholt, laut `design-ist-das-ziel.md` nur Herkunft)
- „Und Design muss ja Werken und machen und tun und mit mir die App Ansichten durchgehen deklinieren und designen. Damit Code was hat nach dem gebaut wird.“
- „Ich brauche auch keine Fragen, weil es sind eure Übersetzungs-Probleme, nicht etwas, dass ich entscheiden müsste.“ und „Ihr Müsst "die exakt gleiche sprache sprechen"“.
- „die Schablone war ja nur "ein erster Keks- ausstecher" zum Testen und Grundklagen ermitteln…“; „wieso Höhenversatz?“ (Menüabstand).
- Werte dort: Ruhe 300, größte Seitenbahn 380, Falten unter 120, Mindestbreite 240, Menü 216, Assistentenkarte 360; gegen sein späteres Wort 112/280 (16.10.). Name „Stein“ in Tokens und `StoneMenu` gegen sein Wort vom 10.10. 23:04.

Kanon (Artefakt, TOKENBOGEN 2.3.6, 08.10.)
- Beschluss Johannes 06.10.: „Das gesamte Blatt/Zeichnung/Entwurf bildet nun einen AKTUELLEN Tokenbogen der Gültigkeit bekommt bis ich einen neueren bestimme.“ Seit Master 1810 überholt (`design-ist-das-ziel.md`).
- Kanon führt BOGEN-MAIL 3.1.0 als „Dateikopf ohne status“; `app-mail.md` nennt es „decided“. Unaufgelöst.

Schleusen und Prüfung 48 Stunden (Artefakte vom 17./18.10.)
- Schleife und Schleusen: 717 Commits 08.–18.10., 236 ohne Swift-Zeile, 38 ändern AGENTS.md, 3,3 % der Werkzeugaufrufe betreffen Produkt-Code. Fünf Schleusen mit Ist: Betriebssystem fehlt, Claude-Hook Prototyp, Git-Hooks teils, GitHub zwei Rulesets ohne Branchschutz für main, CI `check.yml` da.
- Prüfung 48 Stunden (Stand 17.10. 21:25 MESZ): 23 Aussagen geprüft, 15 bestätigt, 5 mit Korrektur, 1 falsch, 2 nicht prüfbar; 6 Punkte fehlen im Bericht. Offene Züge von Johannes: sudo, Deploy-Key mit Ruleset, Docs-Grenze „10 oder 3“ (gegen AGENTS.md §9 überholt). Auto-Push-Hook: „von dir behalten (16.10. 17:32)“.
- Sperren und Wächter bleiben nach AGENTS.md §10 außerhalb der Code-Sitzung; hier nur Befund.

Weitere Funde je Artefakt (Herkunft, keine Quelle)
- Werkstatt Vollbild-Konzepte (16.10.): Werkzeuge Alle Werkstücke, Aufmaß, Plan, Planabgleich, Atelier, Moodboard, Konfigurator, Dokumente; 14 Vorlagen, mitgelieferte schreibgeschützt; „Die App erstellt Entwürfe. Versand und Buchhaltung bleiben außerhalb.“ Nur Namen und sein Wort vom 27.09. zu Vorlagen belegt. Widerspruch: ein Bereich mit Unterwerkzeugen gegen „Jedes eigener Bereich“ (app-spaeter), Atelier gegen „noch nie real genutzt“, ⌘K gegen „Maus, nicht Tastenkombis“, Sand-Farbwelt gegen „Weiß, Haarlinien“.
- Moodboard Editor und Aufmaß Editor (16.10.): lauffähige Prototypen in der Hülle (Rand 16, Abstand 12, Ruhe 280, Falten 56 ab 112); Aufmaß legt ab in „01 INFOS/01 Pläne“; Fußzeile „MYKILOS GMBH“ nur Artefakt, nie in Code.
- Projektkarte (14.10.): „Cash bleibt Bereich“ und Reihenfolge Mail, Kalender/Kontakte, Aufgaben gegen `app-projekte.md` (04.10., 16.10.); „Kalkulation nur Assistent-Werkzeug“ gegen `app-spaeter.md` (18.10.). Das spätere Wort gilt.
- Tafel (14.10.): „höchstens 10 Docs“, „Haiku 5 max“ überholt (AGENTS.md §9; Bau nur Sonnet 5.5, `arbeitsweise.md`).
- Anlagenplan (18.10.): „Hub 1 von 9 belegt“ überholt durch 6668bcd (`app-konten.md`). Zählwerte: ALFA_OS 9.005 Zeilen in 74 Dateien, ALPHA 53.076 in 426.
- Setzkasten (18.10.): 42 von 1.147 ALPHA-Typen angeschlossen; Perlen „Schloss“, „Prüfstempel“ sind Schutzfunktionen, nicht übernehmen (`arbeitsweise.md`, Keine Rechte).
- Alte Linie (ALPHA, 25.09.–09.10.), nur Herkunft: Inventur und Lauf 2, Doppelungen, Knäuel-Karte, Bauplan der Ebenen, Plan Shell Mail Einstellungen, Fahrplan, Staffelstab, Stadtplan, Verdrahtung, Leitstand, Moodboard Fassung 14. Zählwerte (z. B. 129.222 Zeilen in 784 Dateien, 18 Integrationen) stehen nur dort.
- ALFAcolor-Artefakte, Farbwelten, Kanon-Paletten, UI-Testbogen (35 Ideen, Farbwelt „Frage an Johannes“), Briefe an Design, Einsatzbögen, Schablone: alle mit Farbwelten oder Dock gegen „Nur das ALFA-Interface, keine Farbwelten“ (10.10. 02:33) und „Dockbar entfällt.“ (03.10.); Akzent Koralle gegen Blau ist dort „Johannes entscheidet“, offen.
- Schablone (10.10.): Zitate 18.09. „NIEMALS zwei Orte im Code…“, 20.09. „Es gibt nur noch ADMIN und TEAM…“ (überholt durch „Rollen später als Einstellung“), 21.09. „App offline – alles geht lokal…“, 04.10. „Alles immer als Eingänge…“.

Verweise: `design-ist-das-ziel.md`, `app-huelle.md`, `stand.md`, `app-kataloge.md`.
