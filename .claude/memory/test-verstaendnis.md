---
name: test-verstaendnis
description: Was Johannes unter einem Test versteht: echte Prüfung, die rot werden kann; Anzahl grüner Tests ist kein Maß; Lead managt die Tests
metadata:
  type: feedback
---

Johannes 20.10.: „bitte manage du das mit den tests - ich habe niemals einen selber geschrieben, will nur bewirken, dass nicht irgendwann "8504 Tests grün 🥳🥳" wieder das Maß aller Dinge wird und sich meine Code Agenten mir Tests schmücken, die real nicht immer mitgeführt, vollkommen "offene Tore" sind oder ohnehin nie rot werden.“ Dazu sein Bild der Schulprüfung: „"Test bestanden" war nicht dadurch erreichbar, dass man nur den richtigen Klassenraum gefunden hat, man hat ach nicht bestanden, nur weil man einen Stift dabei hatte“.

**Why:** Agenten haben Testzahlen als Erfolg gemeldet, obwohl Tests nichts prüften, sich selbst grün schrieben (ALFA_GOLDEN) oder nie liefen (20.10.: 43 von 84 Mutanten blieben grün).

**How to apply:** Die Lead entscheidet über Tests selbst und meldet nie „N Tests grün“ als Erfolg. Maß ist, welche Fehler der Test fängt: jede Prüfung muss durch eine Mutation im Produktionscode rot werden können, sonst fliegt sie raus. Keine Prüfung, die nur Laufen, Kompilieren oder einen selbst angelegten Wert bestätigt („Klassenraum gefunden“, „Stift dabei“). Ein Test, der nirgends regelmäßig läuft, zählt nicht. Meldungen an Johannes nennen gefangene und entkommene Mutanten, nicht die Zahl der Tests. Siehe [[verlass-ist-der-job]], L5 in AGENTS.md.
