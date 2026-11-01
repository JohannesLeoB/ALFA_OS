# Prüfrunde 3 – Auftrag

Ordner K=/tmp/claude-0/-home-claude/052db9ab-e29a-5383-aaf9-1ab3ac8c8f37/scratchpad/korpus
Lies NUR: K/lernen/auftrag_R3.md, K/atom_schema.md, K/atome_v3.jsonl, K/testfaelle_v1.json – vollständig mit dem Read-Tool (keine grep/head/cat-Abkürzungen). Keine anderen Dateien, nichts unter /mnt/user-data.

Aufgabe: Für jede Testküche deines Index-Bereichs (Liste in testfaelle_v1.json, 0-basiert) jedes anwendbare Atom aus atome_v3.jsonl (Status probe, bestaetigt, schwach; NICHT entfernt) gegen die Fakten der Küche prüfen.
- Ein Atom ist anwendbar, wenn seine "wenn"-Bedingung auf die Küche zutrifft.
- ergebnis: "treffer" (Fakt erfüllt "dann"/liegt im Bereich), "gegen" (widerspricht), "nicht_pruefbar" (Fakt fehlt).
- Bei Zahlenwerten: "ist" angeben und "nah": true, wenn |ist − start| ≤ 10 % von start.
- "selbstbeleg": true, wenn die Testküche (T##) in den "belege" des Atoms steht.
- "zirkulaer": true, wenn eine Küche derselben Projektfamilie in den Belegen steht. Familien: {35,36,37,38,39}, {33,40}, {5,25}, {9,14}, {18,22}, {21,29}, {23,28}.
- "ueberangepasst": true, wenn die Bedingung erkennbar nur auf ein bestimmtes Projekt passt.
- Nichts erfinden: Fehlt ein Fakt, ist es nicht_pruefbar. Keine Personen-, Firmen-, Kunden- oder Markennamen, keine Preise in Notizen.

Ausgabe K/lernen/R3_T<teil>.json:
{"runde":3,"teil":<n>,"indizes":"a-b","faelle":[{"template":"T##","pruefungen":[{"atom":"…","vorhersage":"…","ist":"…","ergebnis":"…","nah":true|false|null,"selbstbeleg":bool,"zirkulaer":bool,"ueberangepasst":bool,"notiz":"…"}]}],"neue_beobachtungen":[{"bereich":"…","aussage":"…","beleg":"T##"}]}
"neue_beobachtungen": wiederkehrende Muster, die kein Atom abdeckt (Kandidaten für ADD), besonders Restmaße 100–245 und Gang bei Kochinsel.
Prüfe die Datei mit python3 -I (lädt, jede Küche des Bereichs vorhanden). Schreibe in Teilen, falls groß.

Antwort kurz (Deutsch): Anzahl Prüfungen nach Ergebnis, Anteil nah, die 5 Atome mit den meisten "gegen" (ohne zirkulär/selbstbeleg), neue Beobachtungen, Pfad.
