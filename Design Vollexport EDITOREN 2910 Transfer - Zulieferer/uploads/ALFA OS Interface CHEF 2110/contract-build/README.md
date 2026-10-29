Export: 19.10.2026

# contract-build · Werkzeuge für contract/ (Brief v9)
Alle Skripte laufen im Projekt-Skriptfenster (JS), weil dort kein Python läuft. Ports der Prüfer des Briefs: `validate.js` (= validate.py), `check.js` (= check_contract.py). `diff_contract.py` ist noch nicht portiert (P3 offen; erster Vertrag, Basis liegt in `previous/2026-10-19T16-55/`).

| Schritt | Skript | Eingabe | Ausgabe |
|---|---|---|---|
| T1 | t1-tokens.js | TOKENBOGEN.json | contract/base, theme-light, theme-dark, ground-lightGray .tokens.json, alfa.resolver.json (Resolver von Hand, siehe BRIEF-V9-ABGLEICH.md) |
| T2 | t2-components.js | vier Bögen, lieferung-an-code/bauteile.json, TOKENBOGEN.json | contract/components.json (data-id je Element sind in die Bögen geschrieben) |
| T3 | von Hand | – | contract/views.json |
| T4 | t4-texts.js | vier Bögen (Vorlagen und Logik) | contract/texts.json |
| T8 | von Hand (erster Block) | – | contract/changes.json |

Ergebnis 19.10.2026: P1 `contract: valid` (9 Dateien), P2 `consistent` (--areas shell,mail,settings, vier Bögen als Entwürfe). Zahlen: 394 Tokens, 76 Bauteile, 187 Elemente mit data-id, 283 Texte, 3 Ansichten.
