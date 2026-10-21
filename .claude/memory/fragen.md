---
name: fragen
description: "Johannes nur fragen, was seine Entscheidung ist, und erst nach Suche in seinen Transkripten; nie zu Design- oder Fremdtexten"
metadata:
  type: feedback
---

Regel: AGENTS.md §9 (Fragen) und §2 (Quellen).

Sein Wort
- „Die Fragen fragst du dich erstmal bitte die gesamte Historie, bevor ich da x mal da selbe antworten muss auf vorschnelle Fragen“ (11.10. 19:17 7cc894d9) · „Ich habe NIE 224 Irgendwo gesagt.“ · „Wenn Du und Design eure Aufzeichnungen nciht aktuell haltet und meine Ansagen, Entscheidungen udn Hinweise vermerkt und notiert - selber Schuld.“ (17.10. 15:10 c2a04c8a)
- Johannes 21.10. (Lead-Sitzung bc4854d7): „ich höre immer iund immer und immer wieder die gleichen Fragen zu Sachen die ICH nie gesagt habe. Wie kann das sein?“

**Why:** Die Antwort steht fast immer schon in seinen Nachrichten; ein Designwert (224) wurde als sein Wort ausgegeben. Design-Wortlaut gilt als Soll (§2); Agenten machen daraus Lücken und Fragen an ihn, obwohl er das Thema nie aufgebracht hat. Quellen werden vermischt, neue Sitzungen fragen ohne Suche.

**How to apply:**
- Vor jeder Frage: Ist das eine echte Produktentscheidung, die nur er treffen kann? Gibt es schon sein Wort dazu? Dann zitieren, mit Datum.
- Suchen in seinen Transkripten mit `python3 -I`: Nachrichten vom Typ `user`, eingereihte Nachrichten (`queue-operation`, `queued_command`) und die Antworten der Fragewerkzeuge im `tool_result` (`The user answered`); Zeiten sind UTC. Gefundenes wörtlich mit Datum, Uhrzeit, Sitzung. Design-Master und Gedächtnis dazu.
- Stammt etwas nur von Design, aus alten Dokumenten oder Transkripten fremder Stimmen: nicht fragen, als „nicht von Johannes“ markieren, nichts dazu bauen.
- Mehrere Punkte gesammelt einmal vorlegen. Vor jeder Ausgabe prüfen Haiku-Worker Fragen und Feststellungen gegen die Belege (§9).
- Siehe `keine-babysitter-texte.md`, `entscheidung-wortlaut-herkunft.md`.
