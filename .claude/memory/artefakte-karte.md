---
name: artefakte-karte
description: Karte der 56 Artefakte (claude.ai, Liste 20.10.): gelesen, nicht lesbar, Quellenrisiko der Zitate, Funde je Artefakt
metadata:
  type: reference
---

Gelesen am 20.10. (sechs Leser, je zehn Artefakte, Abgleich gegen dieses Gedächtnis; Johannes: „Lies alle Artefakte der Liste vollständig und gleiche sie mit dem Gedächtnis ab.“). Alle Aussagen unten stammen aus den Artefakten selbst, nicht aus dem Repo; Datum je Artefakt ist der Veröffentlichungsstand.

Nicht lesbar oder leer
- Claude-Docs-Typ, Connector fehlt: Lastenheft Editoren (Funktionsebene), ALFA OS Design-Briefs Werkzeuge und Vorlagen, Lagebericht ALPHA: Code und Design.
- Leer: ALFA Designsystem, Design System, Untitled.
- Nur teilweise gelesen (Größe 2 bis 4 MB): ALPHA Inventur, ALPHA Inventur Lauf 2, UI-Testbogen; Kanon ohne api-Karten.
- Ohne Bezug zu ALFA: Uhren-App Zifferblatt, Hauptküche Folie und Planlayout, Ultraleichter Schreibtisch, kilo lux System, Licht-Stash Schaltbaum, johannesleoberger.com Neustart und Redesign, Plaster and Shadow, Die Bohne schwört Treue.

Quellenrisiko (Willensbaum, Stand 18.10., Commit 1785da4)
- 21 von 44 Zitaten der Funktionskarten (`app-*.md`) sind im Korpus nicht gefunden, 7 davon sind Auswahloptionen („Ja, ganz weg (Empfohlen)“). Nicht gefunden u. a.: „Blob sitzt über den Spalten!!“, „Die App ist auf Fullscreen ausgelegt.“, „…es seih denn die FIRMA (Admin) sperrt…“ (12.10. 17:40), „ALFA_OS ist MAIN App…“ (16.10. 20:31), „Erst nach dem Design-Nachzug“, „c - aber noch ohne Kalkulation“ (18.10. 13:11). Die Quelle kann außerhalb des Korpus liegen; belegt ist nur: nicht gefunden.
- Heißt: vor jedem Bau, der auf so einem Zitat steht, den Wortlaut gegen das Transkript prüfen (erst-historie-dann-fragen).

Interface 11.10. (Artefakt „ALFA Interface · Stand 2026-10-11“, entscheidungen.md, Johannes 11.10.; Stand überholt, laut design-ist-das-ziel nur Herkunft)
- „Und Design muss ja Werken und machen und tun und mit mir die App Ansichten durchgehen deklinieren und designen. Damit Code was hat nach dem gebaut wird.“
- „Ich brauche auch keine Fragen, weil es sind eure Übersetzungs-Probleme, nicht etwas, dass ich entscheiden müsste.“ und „Ihr Müsst "die exakt gleiche sprache sprechen"“.
- „die Schablone war ja nur "ein erster Keks- ausstecher" zum Testen und Grundklagen ermitteln…“; „wieso Höhenversatz?“ (Menüabstand).
- Werte dort: Ruhe 300, größte Seitenbahn 380, Falten unter 120, Mindestbreite 240, Menü 216, Assistentenkarte 360; gegen sein späteres Wort 112/280 (16.10.). Name „Stein“ in Tokens und `StoneMenu` gegen sein Wort vom 10.10. 23:04.

Kanon (Artefakt, TOKENBOGEN 2.3.6, 08.10.)
- Beschluss Johannes 06.10.: „Das gesamte Blatt/Zeichnung/Entwurf bildet nun einen AKTUELLEN Tokenbogen der Gültigkeit bekommt bis ich einen neueren bestimme.“ Seit Master 1810 überholt (design-ist-das-ziel).
- Kanon führt BOGEN-MAIL 3.1.0 als „Dateikopf ohne status“; `app-mail.md` nennt es „decided“. Unaufgelöst.

Schleusen und Prüfung 48 Stunden (Artefakte vom 17./18.10.)
- Schleife und Schleusen: 717 Commits 08.–18.10., 236 ohne Swift-Zeile, 38 ändern AGENTS.md, 3,3 % der Werkzeugaufrufe betreffen Produkt-Code. Fünf Schleusen mit Ist: Betriebssystem fehlt, Claude-Hook Prototyp, Git-Hooks teils, GitHub zwei Rulesets ohne Branchschutz für main, CI `check.yml` da.
- Prüfung 48 Stunden (Stand 17.10. 21:25 MESZ): 23 Aussagen geprüft, 15 bestätigt, 5 mit Korrektur, 1 falsch, 2 nicht prüfbar; 6 Punkte fehlen im Bericht. Offene Züge von Johannes: sudo, Deploy-Key mit Ruleset, Docs-Grenze „10 oder 3“ (gegen AGENTS.md L2 überholt). Auto-Push-Hook: „von dir behalten (16.10. 17:32)“.
- Sperren und Wächter bleiben nach AGENTS.md außerhalb der Code-Sitzung; hier nur Befund.

Weitere Funde je Artefakt (Herkunft, keine Quelle)
- Werkstatt Vollbild-Konzepte (16.10.): Werkzeuge Alle Werkstücke, Aufmaß, Plan, Planabgleich, Atelier, Moodboard, Konfigurator, Dokumente; 14 Vorlagen, mitgelieferte schreibgeschützt; „Die App erstellt Entwürfe. Versand und Buchhaltung bleiben außerhalb.“ Nur Namen und sein Wort vom 27.09. zu Vorlagen belegt. Widerspruch: ein Bereich mit Unterwerkzeugen gegen „Jedes eigener Bereich“ (app-spaeter), Atelier gegen „noch nie real genutzt“, ⌘K gegen „Maus, nicht Tastenkombis“, Sand-Farbwelt gegen „Weiß, Haarlinien“.
- Moodboard Editor und Aufmaß Editor (16.10.): lauffähige Prototypen in der Hülle (Rand 16, Abstand 12, Ruhe 280, Falten 56 ab 112); Aufmaß legt ab in „01 INFOS/01 Pläne“; Fußzeile „MYKILOS GMBH“ nur Artefakt, nie in Code.
- Projektkarte (14.10.): „Cash bleibt Bereich“ und Reihenfolge Mail, Kalender/Kontakte, Aufgaben gegen `app-projekte.md` (04.10., 16.10.); „Kalkulation nur Assistent-Werkzeug“ gegen `app-spaeter.md` (18.10.). Das spätere Wort gilt.
- Tafel (14.10.): „höchstens 10 Docs“, „Haiku 5 max“ überholt (AGENTS.md L2; Bau nur Sonnet 5.5, stand.md).
- Anlagenplan (18.10.): „Hub 1 von 9 belegt“ überholt durch C2 teils (stand.md, 6668bcd). Zählwerte: ALFA_OS 9.005 Zeilen in 74 Dateien, ALPHA 53.076 in 426.
- Setzkasten (18.10.): 42 von 1.147 ALPHA-Typen angeschlossen; Perlen „Schloss“, „Prüfstempel“ sind Schutzfunktionen, nicht übernehmen (keine-rechte-im-code).
- Alte Linie (ALPHA, 25.09.–09.10.), nur Herkunft: Inventur und Lauf 2, Doppelungen, Knäuel-Karte, Bauplan der Ebenen, Plan Shell Mail Einstellungen, Fahrplan, Staffelstab, Stadtplan, Verdrahtung, Leitstand, Moodboard Fassung 14. Zählwerte (z. B. 129.222 Zeilen in 784 Dateien, 18 Integrationen) stehen nur dort.
- ALFAcolor-Artefakte, Farbwelten, Kanon-Paletten, UI-Testbogen (35 Ideen, Farbwelt „Frage an Johannes“), Briefe an Design, Einsatzbögen, Schablone: alle mit Farbwelten oder Dock gegen „Nur das ALFA-Interface, keine Farbwelten“ (10.10. 02:33) und „Dockbar entfällt.“ (03.10.); Akzent Koralle gegen Blau ist dort „Johannes entscheidet“, offen.
- Schablone (10.10.): Zitate 18.09. „NIEMALS zwei Orte im Code…“, 20.09. „Es gibt nur noch ADMIN und TEAM…“ (überholt durch „Rollen später als Einstellung“), 21.09. „App offline – alles geht lokal…“, 04.10. „Alles immer als Eingänge…“.

Verweise: [[grundsaetze]], [[stammtisch]], [[design-ist-das-ziel]], [[app-huelle]], [[stand]].
