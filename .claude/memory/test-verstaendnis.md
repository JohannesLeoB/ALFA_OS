---
name: test-verstaendnis
description: Was Johannes unter einem Test versteht: echte Prüfung, die rot werden kann; Anzahl grüner Tests ist kein Maß; Lead managt die Tests
metadata:
  type: feedback
---

Johannes 20.10.: „bitte manage du das mit den tests - ich habe niemals einen selber geschrieben, will nur bewirken, dass nicht irgendwann "8504 Tests grün 🥳🥳" wieder das Maß aller Dinge wird und sich meine Code Agenten mir Tests schmücken, die real nicht immer mitgeführt, vollkommen "offene Tore" sind oder ohnehin nie rot werden.“ Dazu sein Bild der Schulprüfung: „"Test bestanden" war nicht dadurch erreichbar, dass man nur den richtigen Klassenraum gefunden hat, man hat ach nicht bestanden, nur weil man einen Stift dabei hatte“.

**Why:** Agenten haben Testzahlen als Erfolg gemeldet, obwohl Tests nichts prüften, sich selbst grün schrieben (ALFA_GOLDEN) oder nie liefen (20.10.: 43 von 84 Mutanten blieben grün).

**How to apply:** Die Lead entscheidet über Tests selbst und meldet nie „N Tests grün“ als Erfolg. Maß ist, welche Fehler der Test fängt: jede Prüfung muss durch eine Mutation im Produktionscode rot werden können, sonst fliegt sie raus. Keine Prüfung, die nur Laufen, Kompilieren oder einen selbst angelegten Wert bestätigt („Klassenraum gefunden“, „Stift dabei“). Ein Test, der nirgends regelmäßig läuft, zählt nicht. Meldungen an Johannes nennen gefangene und entkommene Mutanten, nicht die Zahl der Tests. Johannes 20.10. zum „Abitur“ (Prüfung aller Fächer: Master-Tokens, kein Eigenbau, Englisch, Texte, Größe, brechende UI, Wege ohne Rückkehr, Hygiene): „Und eben NICHT als von der testenden Instanz selbst geschriebener Test zum Testbestehen“. Daraus: Wer Code baut, schreibt und sieht die Prüfung nicht; Erwartungen kommen nur aus Master, Johannes' Wort und AGENTS.md, nie aus Code-Ausgaben; die Prüfung gehört auf die Wächter-Seite (AGENTS.md §10). Siehe [[haltung]], AGENTS.md §10.
