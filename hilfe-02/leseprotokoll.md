# HILFE-02 · Leseprotokoll

Stand 29.10.2026. „ganz“ bedeutet Wort für Wort gelesen. „Liste“ bedeutet: nur Name und Prüfsumme erfasst, Inhalt nicht gelesen. „Suche“ bedeutet: nur `grep`-Treffer gelesen.

## Bestand (alle Quellen: Liste)

| Quelle | Wie gelesen | Dateien |
|---|---|---|
| E1 `ALFA_OS` `DESIGNCHANNEL` 33feb10f, `Design Vollexport 2910 Transfer - Etappe I/` | `git ls-tree -r`, `git log --name-only` für das Datum | 1095 |
| E2 dasselbe, `Design Vollexport EDITOREN 2910 Transfer - Zulieferer/` | ebenso | 693 |
| E3 `alfa-design-` `main` 71086862, `project/` | `git ls-tree -r` im blobless-Klon; **Inhalte nicht geladen**, nur Namen und Blob-Prüfsummen | 1911 |
| E4 `ALFA_OS` `alfa-draws` 47951ebd, `alfaos/` `fundus/` `gestaltung/` `DESIGN/` | `git ls-tree -r`; 667 `.swift`-Dateien gezählt, nicht gelistet | 98 |
| E5 `~/Downloads/ALFA OS Interface CHEF 2810 (1).zip` | Python `zipfile`, Prüfsumme je Eintrag | 1095 |
| E5 `~/Downloads/ALFA OS Editoren Sketches 1610-3.zip` | ebenso | 693 |
| E5 `ALFA DESIGN OUTBOX/brief-werkstatt-2910.zip` | ebenso | 8 |

- Prüfsumme: Git-Blob-SHA-1, für ZIP-Einträge gleich berechnet.
- Dateinamen wurden nach Unicode NFC angeglichen. Ein Name in der Editoren-ZIP war NFD-kodiert: `uploads/ALFA_Nachlieferung_161026_1708/uebergabe-code/ALFA Hülle.dc.html`.
- Art und Bereich sind **nur nach Pfad und Name** vergeben (Regeln in `bestand.json` › `art_regel`). Kein Inhalt wurde dafür gelesen.

## Ganz gelesen

| Datei | Zeilen |
|---|---|
| `contract-build/lauf.js` (E1) | ganz, 34 Z. |
| `contract-build/apply.js` (E1) | ganz, 46 Z. |
| `contract-build/check.js` (E1) | ganz, 25 Z. |
| `contract-build/check-delivery.js` (E1) | ganz, 39 Z. |
| `contract-build/diff.js` (E1) | ganz, 19 Z. |
| `contract-build/validate.js` (E1) | ganz, 32 Z. |
| `lieferung-an-code/pruefung.js` (E1) | ganz, 86 Z. |
| `CLAUDE.md` (E1) | ganz, 10 Z. |
| `ETAPPE-2910.md` (E1) | ganz, 58 Z. |
| `ARCHITECTURE.md` (CODE f22d7bcc) | ganz, 152 Z. |
| `Resources/apps.json` (CODE) | ganz |
| `KALTSTART-HILFE-02.md` | ganz, 70 Z. |

## Teilweise oder per Suche

| Datei | Umfang |
|---|---|
| `github.md` (E1) | Z. 1–80 von 258 |
| `Package.swift` (CODE) | Suche nach `name:`, `dependencies`, `path:`; Z. 134–171 gelesen |
| `project.yml` (CODE) | Suche; Z. 26–35 und 36–63 (14 × `package: ALFA`) |
| `CLAUDE.md` (CODE) | Z. 23, 24, 32 per Suche |
| 9 Bögen am E1-Stamm, 19 Bögen am E2-Stamm | nur Suche nach `<dc-import`, `href=`, `src=`, `url(`, `fetch(`, `alfa-shell.js`, `alfa-bausteine.js`, `TOKENBOGEN`, Exportvermerk |
| `alfa-shell.js`, `alfa-theme.css`, `alfa-bausteine.js` (E1, E2) | nur Z. 1 (Exportvermerk) |
| `BRIEFING_Editoren.md`, `HANDOFF_Weiterarbeit_2110.md` (E2) | Suche nach „Shell“ und „Hülle“ |
| `App/Components`, `App/Design`, `App/Shell` (CODE) | Dateiliste; `Chip`, `MenuPanel`, `LaneHead` per Suche in `App/` |

## Nicht gelesen

- **E3: kein einziger Inhalt.** Der Klon ist blobless; das Nachladen scheiterte am Sandbox-Netzfilter (github.com in diesem Aufruf nicht freigegeben). Pfade und `dc-import` in E3 sind deshalb nicht geprüft.
- E4: Inhalte nicht gelesen.
- `INHALT.json` (E1, 1294 Z.), `ARCHIV/INHALT.md`, `entscheidungen.md`, `START-HIER-NEUE-SITZUNG-2810.md`, `SPEC.md`, alle `lieferung-an-code/*.md`.
- Alle Bögen außer den gesuchten Zeilen, alle `uploads/`, alle Bilder.
- Ob Claude Design `<dc-import name=…>` über Ordner oder Projekte hinweg auflöst: keine Quelle gefunden.

## Stichproben

Gegen die Quelle nachgeprüft:
- E1 ↔ CHEF-ZIP: 1095 von 1095 gleich.
- E2 ↔ Editoren-ZIP: 693 von 693 gleich.
- Die Prüfsummen von `ALFA Shell.dc.html`, `alfa-shell.js`, `alfa-theme.css`, `alfa-bausteine.js`, `ALFA Bestaetigen.dc.html` und `TOKENBOGEN.json` sind in E1 und E2 verschieden (mit `shasum`).
- `support.js` ist in E1 und E2 gleich.

Alles Übrige ist nicht nachgeprüft.
