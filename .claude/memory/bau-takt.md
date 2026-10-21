---
name: bau-takt
description: Mehr bauen, dann Gebautes prüfen: große Stücke, kein Vorab-Grillen außer bei Risiko, Diff einmal Lead und einmal blind durch Worker (21.10.)
metadata:
  type: feedback
---

Johannes 21.10. (Lead-Sitzung bc4854d7): „Viel zu viel geredet und wenig weiter die App konkretisiert, oder?“, dann „Weniger prüfen, mehr bauen dann gebautes prüfen?“ und „diffs dann einmal du einmal "blind durch worker" lesen?“

**Why:** Am 20./21.10. ging viel Kraft in Vorab-Prüfung der Tickets (Haiku) und mehrere Nachbesserungsrunden, wenig in sichtbare Funktion.

**How to apply:**
- Bauen in großen Stücken, ein Bereich je Auftrag, nicht viele Mini-Tickets.
- Ticket nur bei riskanten Stellen vorab von Haiku prüfen lassen (Löschen, Senden, Geheimnisse, GitHub-Regeln, Wächter-Nähe).
- Danach prüfen, was gebaut ist:
  - die Lead liest den Diff mit Ticket und Master;
  - ein Worker liest ihn blind, nur mit Diff, AGENTS.md und Master, ohne Ticket und ohne Bericht des Bauers;
  - Abweichungen klärt die Lead am Code;
  - eine Nachbesserung, dann Commit.
- Je neuer Logik ein Mutant. Nach jedem Stück eine App für Johannes über `scripts/build_app.sh`.
- Gesetze bleiben: L0 Werte nur aus dem Master, L5 echte Prüfungen, L4 sofort pushen. Siehe [[test-verstaendnis]], [[ein-ordner-je-sitzung]].
