Export: 21.10.2026

# contract-build · Werkzeuge für contract/ (Brief v9)
Alle Skripte laufen im Projekt-Skriptfenster (JS), weil dort kein Python läuft. Ports der Prüfer des Briefs: `validate.js` (= validate.py), `check.js` (= check_contract.py). `diff.js` (= diff_contract.py) liegt vor.

| Schritt | Skript | Eingabe | Ausgabe |
|---|---|---|---|
| T1 | t1-tokens.js | TOKENBOGEN.json | contract/base, theme-light, theme-dark, ground-lightGray .tokens.json, alfa.resolver.json (Resolver von Hand, siehe SPEC.md) |
| T2 | t2-components.js | vier Bögen, lieferung-an-code/bauteile.json, TOKENBOGEN.json | contract/components.json (data-id je Element sind in die Bögen geschrieben) |
| T3 | von Hand | – | contract/views.json |
| T4 | t4-texts.js | vier Bögen (Vorlagen und Logik) | contract/texts.json |
| T8 | von Hand (erster Block) | – | contract/changes.json |

Ergebnis 21.10.2026 16:45: P1 `contract: valid`, P2 `consistent` (--areas shell,mail,settings, vier Bögen), P3 `log matches` (Basis `previous/2026-10-21T16-30`, 214 Änderungen). Zahlen: 397 Tokens, 81 Bauteile, 183 Elemente mit data-id, 298 Texte, 3 Ansichten. Aufruf: t1 `new Function(code)(T)`, t2 `new Function('src','B','T','side',code)`, t4 `new Function('src',code)`, t7 `new Function('akte','sizes','contract','answered',code)`. P4: `check-delivery.js` (= check_delivery.py, Stand 21.10. 17:20), Aufruf `new AsyncFunction('ctx', code)(ctx)` mit ctx = { V (Ergebnis von validate.js), schema, note, noteProblem, brief, components, drafts (ArrayBuffer je .dc.html), pruefung }. Selbsttest: ohne Schein „file missing“; Schein mit 24 Punkten (T1–T8, N1–N11, N13–N17) „open“ → „delivery: complete“; Fehlerfälle (doppelt, N18, Hash, Zeile) erkannt. Jede .dc.html im Projektstamm muss in drafts stehen (14 Dateien).

| T9 | t9-css.js | contract/base.tokens.json | alfa-theme.css, Block „alfa:tokens“ (:root, 318 Variablen gesamt) |
| T10 | t10-literals.js | Bogen-Text, Bereichsname | Bogen mit var(--…) statt Literalen in style-Attributen (Maße, Radien, Schrift, Laufweite, Dauer, Kurve, Ringe); meldet Reste. Aufruf new Function('src','file',code) |

A1-Lauf 21.10. 17:50: Mail 590→0, Einstellungen 339→4, Shell 99→0, Bestaetigen 59→1 lose px/ms/em in style-Attributen (Rest: Einstellungen 4, Bestaetigen 1). Dienste/Widgets: Gerüstmaße der Bogenseite (64, 48, 820 …) und DHL-Gelb bleiben. Layout-Gleichheit gemessen: aufgelöste Kopie gegen Bogen, 0 Abweichungen in Mail, Shell, Bestaetigen, Dienste, Einstellungen (Widgets nach Neuladen 0). JS-Strings in der Logik (stackTrans, edgeTr …) noch nicht umgestellt. TOKENBOGEN.json: weiter von Hand/von t1 gelesen; neue Tokens dort eingetragen und mit t1 nach contract/ erzeugt (Brief A2 offen).

`apply.js` (21.10. abends): zieht den Vertrag nach einer Bogenänderung nach (Texte, Bauteile, Elemente, Tokens → TOKENBOGEN, t1, t9) und hängt einen Block an changes.json. Für die Lieferung danach changes.json auf EINEN Block gegen den gesicherten Stand zusammenführen (diff.js makeBlock), sonst meldet P3 „blocks before the last differ“. `t7-werte.js` erzeugt werte-abgleich.json.
