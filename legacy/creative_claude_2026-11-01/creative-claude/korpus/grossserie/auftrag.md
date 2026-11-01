# Auftrag: Großserien-Referenz aus einem Küchen-Systemkatalog

Quelle: /mnt/user-data/attachments/052db9ab-e29a-5383-aaf9-1ab3ac8c8f37/8fd73964-metod.pdf (44 Seiten). Mit dem Read-Tool, Parameter `pages` (max. 20 je Aufruf), JEDE Seite lesen und ansehen.

Zweck: Beispiele für typische Küchen der Großserie – als VERGLEICH zum Studiowissen (Studio plant ohne Raster, mm-genau). Nichts davon ist Studioregel.

VERBOTEN in der Ausgabe: Preise/Beträge/Währungen, Produkt-, Serien-, Marken- und Herstellernamen, Artikel- oder Referenznummern, Farb-/Dekor-Handelsnamen, Personen, Adressen, URLs. Nur Kategorien (z. B. "Unterschrank 2 Auszüge", "Fronttyp Lack hell").

Erfassen (grob, mit Seitenbeleg "S.<n>"):
- Raster: Breiten, Höhen, Tiefen der Korpusse (Unter-, Hoch-, Oberschränke), Sockel, Arbeitsplatte, Arbeitshöhe.
- Frontaufteilung: Höhenteilungen, Kombinationen (Tür/Auszug/Schubkasten).
- Korpustypen und Sonderelemente (Ecke, Spüle, Geräte, Abdeckseiten, Blenden, Passleisten, Sockel, Füße).
- Innenausstattung (Schubkästen, Innenauszüge, Einsätze, Böden, Müll).
- Typische Layouts/Planungsbeispiele (Zeile, L, U, Insel), Planungsregeln/-hinweise, Montage-/Anschlusslogik.
- Griff-/Öffnungsarten.
- Unterschiede zum Studiowissen, soweit offensichtlich (z. B. festes Raster vs. freie Maße).

Ausgabe: genau eine JSON-Datei (Pfad im Einzelauftrag):
{"durchgang":"…","seiten_gelesen":"44/44",
 "atome":[{"id":"GS-<BEREICH>-NN","bereich":"RASTER|FRONT|KORPUS|INNEN|LAYOUT|GRIFF|ANSCHLUSS|REGEL","aussage":"eine prüfbare Aussage","werte":[…],"einheit":"mm","belege":["S.n"]}],
 "vergleich_studio":["…"],"offen":["…"]}
Gültigkeit mit python3 -I prüfen. Vor dem Speichern selbst kontrollieren: keine Preise, Namen, Nummern.
