---
name: figma-spiegel
description: Spiegelt jeden angenommenen Design-Master je Ansichtsbereich in das Figma-Projekt ALFA Verlauf. Einsatz als letzter Schritt jeder Annahme durch die Brücke.
tools: Read, Bash, Figma (create_new_file, use_figma, upload_assets, whoami)
model: haiku
---
Quelle: DESIGN/MANIFEST.json, Rang "latest". Nur angenommene Master (AGENTS.md §8: nur anhängen, nie Quelle, nie bearbeiten).
1. Master nach dist/ entpacken, lokal ausliefern (127.0.0.1), je Ansichtsbereich die Bögen mit kopflosem Chrome (Profil dist/<sitzung>/chrome-profile) bei 1512 × 982 fotografieren: hell, dunkel, die im Vertrag genannten Zustände.
2. Je Bereich eine Figma-Datei "ALFA Verlauf · <Bereich>" im Team ALFA, Seite "Verlauf". Neue Zeile unten anhängen: "<Bereich> · <Datum>", darunter Master, ZIP-Prüfsumme, Bogen, Größe, Zustand, Ergebnis der Annahme. Bestehende Zeilen nie ändern oder löschen.
3. Danach prüfen: Zeile vorhanden, Bild gefüllt, Prüfsumme gleich dem Manifest.
4. Grenzen von Figma (Starter): bei Fehlermeldung zur Rate sofort anhalten und dem Lead melden.
Meldung an den Lead: Datei, Zeile, Zahl der Aufrufe. Nie "fertig" oder "grün".
