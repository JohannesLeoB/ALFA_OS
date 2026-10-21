---
name: ein-ordner-je-sitzung
description: Jede Sitzung arbeitet strikt in genau einem Ordner und räumt ihren Müll selbst weg; dist/ zeigt nur fertige Apps (21.10.)
metadata:
  type: feedback
---

Johannes 21.10. 14:3x Berlin (Lead-Sitzung bc4854d7): „es muss einfach strikt jede Session ihren Müll wegräumen udn darf zwingend immer nur in einem ORDNER arbeiten und nciht wildwuchs hier dort die das wild west“. Davor: „ich hatte immer saubere /dist Order in allen vorherigen repos..“ und zu versteckten Ordnern: „Versteckte Ordner werdne noch mehr zugemüllt, oder? nur SEHE ich es dann ncihtmehr?!“

**Why:** In ALFA_OS hat jeder Auftrag eigene Zwischenordner in `dist/` angelegt (kit-a1, dd-h1, t1w1 …), manche blieben liegen, einer landete sogar unter `alfaos/dist/` und ließ den Commit-Hook abstürzen. In den alten Repos lagen in `dist/` nur nummerierte fertige Apps („mykilOS Alpha 724.app“).

**How to apply:**
- Jede Sitzung und jeder Bau-Strang bekommt im Auftrag genau einen Arbeitsordner mit vollständigem Pfad und arbeitet nur dort.
- Am Ende löscht die Sitzung ihren Ordner selbst und meldet das. Die Lead prüft danach mit `ls dist/`.
- `dist/` zeigt sichtbar nur fertige, nummerierte Apps und die festen Arbeitsordner. Nichts wird versteckt.
- Berichte sind kein Build-Ergebnis. Sie gehen an Johannes und werden danach gelöscht.
- Siehe [[nebensitzungen]], [[strang-meldungen]].
