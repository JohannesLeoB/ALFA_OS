---
name: spec-format
description: Form der Spec-Dateien: Funktionsbaum mit fünf Angaben je Funktion, keine Zitate, keine Herkunft
metadata:
  type: reference
---

Eine Spec beschreibt, was die App tut, nicht wer was wann gesagt hat. Der Verlauf liegt in Git.

Kopfzeile unter dem Titel: Eingetragen (Datum), Verfasser, Stand gegen Code-Commit (Hash), Quelle im Code (Pfade). Bei jeder Änderung neu setzen.

Aufbau: Kopf (ein Satz), Regeln (ohne Herkunft), Gruppen mit Funktionen, Später. Arbeitsregeln der Entwicklung gehören in AGENTS.md (nur mit Johannes' Freigabe), offene Fragen an Johannes in stand.md.

Je Funktion fünf Angaben:
- WAS: was sie für den Nutzer tut, ein Satz.
- WO: Ansicht und Ort in der App.
- WARUM: der Zweck im Geschäft.
- AUSSEHEN: Master-Bogen mit Zeile, kein Text daraus; sonst „nicht gezeichnet (Brief Nxx)“.
- STAND: gebaut, nicht abgenommen | teilweise | fehlt | Lücke bei Design, mit Datei:Zeile.

Keine Zitate, keine „J dd.mm.“, keine Sitzungskennungen. Zeile neu schreiben statt anhängen. Grün ist nur, was Johannes abgenommen hat.
