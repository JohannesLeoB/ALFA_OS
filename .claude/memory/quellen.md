---
name: quellen
description: Wo das Wissen zu ALFA liegt, in welcher Reihenfolge es zu lesen ist, und Johannes' stehende Regeln dazu; vor jeder Frage, Aussage, Brief und Bauauftrag lesen
metadata:
  type: reference
---

Reihenfolge vor jeder Frage an Johannes, jeder Aussage über die App, jedem Brief, jedem Bauauftrag:
1. `AGENTS.md` (LAWS), dann diese Datei, dann `MEMORY.md` und die Funktionskarten `app-*.md`.
2. Strang `.claude/agents/produkt.md`: Vision, Ziel, Funktionskarte mit seinem Wortlaut und Datum; Liste der offenen Fragen.
3. Register `~/ALPHA/ASSUMPTIONS.tsv` (483 Zeilen, Spalten id, assumption, status, source, checked, strand, kind, now, links): seine Entscheidungen mit Datum und Wortlaut, Spalte `now` sagt holds oder superseded. Nur lesen.
4. Baustellen `~/ALPHA/BAUSTELLEN.tsv` (Stand, wartet auf, Entscheidung, Quelle). Nur lesen.
5. Verträge `~/ALPHA/Design/`: BOGEN-MAIL 3.1.0 (155 Funktionen), BOGEN-GLOBAL 0.6.6 decided, TEXTE-MAIL 2.0.1 decided, TEXTE-EINSTELLUNGEN 1.4.1 decided, TEXTE-GLOBAL decided, beide ERGAENZUNG decided; BOGEN-EINSTELLUNGEN 1.8.2, BOGEN-HEUTE, BOGEN-KATALOG, TEXTE-HEUTE, TEXTE-KATALOG nur proposal. Stand vor dem Design-Master; der Master geht vor (L0, L9), die Verträge tragen Funktionen und freigegebene Texte.
6. Design-Master `DESIGN/MANIFEST.json` Rang latest, entpackt nur in `dist/master-latest/`; Johannes' Worte an Design in `entscheidungen.md`, Rückgaben in `RUECKGABE-AN-CODE.md`, `lieferung-an-code/decisions.json`.
7. Bibliothek `~/.claude/skills/alfa-bibliothekar/books/` (Code-Fakten mit Zeile und Prüfskript, Stand 14.10.; vor Nutzung `bibliothek.py check`).
8. Bestand nur lesend nach L6: `~/Developer/ARCHIV/mykilos-Alphabet` (docs/, Handbuch), `~/Developer/mykilos-labor`.
9. Erst danach Transkripte: `~/.claude/projects/<Ordner>/*.jsonl`, nur seine Nachrichten (type user) und seine Antworten auf Auswahlfragen, mit python3 -I. Ordner zuordnen: ALFA_OS, ALPHA, mykilos-labor und mykilos-Alphabet sind ALFA und Vorläufer; ALLFARBEN, Datan, SlopSLACK, ZEHNVONZEHN, OWN, SCAN sind andere Vorhaben und gelten nicht für ALFA. Jüngeres Wort geht vor Älterem, Entscheidung vor Frage.

Lesen: Master-Bögen und lange JSON-Zeilen nie mit dem Lesewerkzeug (schneidet ab 2000 Zeichen ab), sondern mit python3 -I in Stücken.

Stehende Regeln aus dem Register (sein Wort):
- A440 (05.10.): „Ich will kein Wort ich will Ergebnisse.“; „strikte wortsperre, wenn nicht zwingend nötig an mich“.
- A428 (05.10.): Was er eingibt, „IST IMMER vollständig zu lesen, nicht nur zu erfinden, zu bluffen.“; eine Design-Lieferung wird nie übersprungen und nie nur mit dem Vorgänger verglichen.
- A347 (04.10.): nichts nur ablegen, um es als erledigt zu zählen; keine Tabelle als Absolution; an der Wurzel lesen.
- 18.10.: Was im Design fehlt, formuliert der Code als Funktions-Spec und Baubedarf an Design, nicht als Frage an ihn.
Fragen an ihn nur, wenn Schritte 1 bis 9 nichts ergeben und die Entscheidung den Bau blockiert; dann mit dem Beleg, wo gesucht wurde.

Siehe [[erst-historie-dann-fragen]], [[arbeitsweise]], [[lead-verantwortung]].
