Export: 19.10.2026

# Plan · Durchkämmen · Airbus-Regel
Auftrag Johannes 19.10.: jede Etappe mit Evaluierung und Verifizierung in Schleife, nichts liegen lassen, nichts als „fehlend“ melden ohne Suche unter allen Namen in allen Dateien. Grundlage: `HANDOFF-FUER-AGENTEN.md` Abschnitt 6 (zehn Schritte), hier verschärft. Keine ZIP vor „raus“. Hülle einmal.

## Regeln für jede Etappe
1. **Suchprotokoll vor „fehlt“:** mindestens vier Suchbegriffe (deutsch, englisch, Token-Pfad, Variante), Suche in allen `.md/.json/.js/.css/.html/.txt` inkl. `contract/`, `contract-build/previous/`, `lieferung-an-code/`, `DESIGN/`, `material/`, `uploads/`, Bilder einzeln angesehen. Ergebnis mit Dateien und Zeilen in `SUCHPROTOKOLL.md`. Erst danach Status „fehlt“.
2. **Schleife je Etappe:** Ausführen → Evaluieren (Skript, Zahl, Kriterium) → Verifizieren (zweiter, unabhängiger Weg: anderes Werkzeug, Bild, Gegenzählung) → bei Abweichung zurück zu Ausführen. Etappe endet erst bei zwei grünen Wegen hintereinander.
3. **Basis sichern** vor jeder Änderung an `contract/` (`contract-build/previous/<stamp>/`), danach `diff.makeBlock`, P1 bis P3, `pruefung.js`.
4. **Messen, nicht laden:** Übergänge aus, Maße mit `getBoundingClientRect`, Kontrast gerechnet; Bewegung nur mit echter Maus (Johannes).
5. **Belegpflicht:** Aussage = Datei:Zeile oder Wortlaut aus `entscheidungen.md`, sonst `set-by-design`.
6. **Protokoll:** nach jeder Etappe ein Eintrag in `HANDOFF-FUER-AGENTEN.md` (Stand) und `entscheidungen.md` nur bei neuen Worten von Johannes.

## Korrekturen aus der Gegenprüfung (19.10., Suche über alle Dateien)
- **Maßband-Lupe:** Wortlaut `entscheidungen.md:30` (11.10.) und `:67` (13.10.). Kein Treffer in Bögen, JS, JSON. `material/icons/entwuerfe-v3.zip` (66 Einträge) enthält nur App-Icon-Entwürfe A bis E, kein Maßband. `material/icons/s1.png` bis `s7.png` nur teilweise angesehen (s1 = Suchergebnis-Bildschirmfoto Clockodo/sevdesk). Status: **nicht gefunden, Quelle bei Johannes**; s2 bis s7 noch zu sichten (P1).
- **„Blob anheften“ (`entscheidungen.md:198`):** In `ALFA Mail.dc.html:138` gibt es einen Knopf `mail.symbol-button.pin` mit Tooltip „Anheften · bleibt im Stapel“ (`contract/texts.json:79`) und `data-state="preview"`. Naheliegend: Karte aus der Vorschau im Stapel festhalten (zusammen mit Wort 13.10. „jede angeklickte Mail bleibt hängen rechts“). Ob Johannes den **Blob** meint, bleibt offen; als Frage mit diesem Befund stellen, nicht erfinden.
- **Logos:** `material/icons/` enthält `clockodo.png`, `dhl.svg`, `monday.svg`, `s1.png` bis `s7.png`. Zählung der Dienste mit Logo in P7 neu.
- **Handoff-Aussage „Zahlen 4 Zählweisen“:** noch nicht neu gezählt, siehe P2.

## Etappen
**P0 · Quellen vollständig (Lesen)**
- Ausführen: lesen: `entscheidungen.md` (ganz, gelesen 19.10.), `TRENNUNG-BERICHT`, `BREAK-UI-BERICHT`, `KONTRAST-PROTOKOLL`, `AUDIT.md`, `AUDIT-BERICHT.md`, `contract-build/README.md`, `DESIGN/brief/BRIEF.txt`, `uploads/AN-DESIGN-LIEFERUNG-15.md`, `INHALT.json`, `lieferung-an-code/*`.
- Evaluieren: Liste „Johannes entschieden / offen / von Design gesetzt“ je Thema.
- Verifizieren: Stichprobe 20 Einträge aus `HANDOFF-SESSION-4` Abschnitt 4 gegen Wortlaut in `entscheidungen.md`; 0 Abweichungen.

**P1 · Suchprotokoll aller „fehlt“-Aussagen**
- Ausführen: je Punkt aus `HANDOFF-FUER-AGENTEN` 3 bis 5 (Lupe, Anheften, Logos, Farbleiter, Sperre, Fensterhöhe, 29 Bauteile ohne Maße, Mechaniken, Texte-Gaps, 213 Tokens ohne Status) Suchprotokoll nach Regel 1; alle sieben `s*.png` und `uploads/*.png` ansehen.
- Evaluieren: je Punkt Status gefunden / nicht gefunden / teils mit Fundstelle.
- Verifizieren: zweite Suche mit anderen Begriffen und per Skript über alle Dateien; Abweichung → Protokoll korrigieren.

**P2 · Zahlen und Namen**
- Ausführen: Tokens aus `TOKENBOGEN.json` und `contract/` zählen (Definitionen, Pfade, `$value`, je Status); eine Zahl festlegen; alte Bezeichner (`designSet`, `provisionalApproval`, `freigabe-orange`, `von-design-gesetzt`, `v2`, `design-system/`, „eine Logikdatei“, 368/350/370/397/399) in Berichten nachziehen oder mit Datum als Historie markieren.
- Evaluieren: Suchlauf nach den alten Wörtern: nur Historie mit Datum übrig.
- Verifizieren: `pruefung.js` und `akte.json` nennen dieselbe Zahl wie `HANDOFF-*`, `ABNAHME`, `TOKENBOGEN`-Kopf.

**P3 · Status und Fundstellen (213 + 101)**
- Ausführen: je Token ohne Status Wortlaut in `entscheidungen.md` suchen; sonst `set-by-design` mit `where` = Datei:Zeile im aktuellen Quelltext; 101 veraltete `where` per Skript neu setzen.
- Evaluieren: 0 Tokens ohne Status; 0 `where` auf nicht vorhandene Zeile (Skript prüft, dass der Wert an der Zeile steht).
- Verifizieren: Stichprobe 30 Tokens von Hand; `pruefung.js` grün; P1 bis P3 grün.

**P4 · Literale und Rollen**
- Ausführen: alle px, ms, Grad, Deckkraft, rgba, Skalierung in Templates der vier Bögen und `alfa-bausteine.js`, `alfa-shell.js` per Skript sammeln; je Wert Token oder dokumentierte Ausnahme mit Rolle (5 px, −3 px, 96 px, 28 px, 320/160 ms, `margin-left:-8px`).
- Evaluieren: Liste „Wert ohne Token“ = 0 oder jeweils mit Grund.
- Verifizieren: Render alt gegen neu bei 1512 × 982, hell und dunkel, 0 Abweichungen; `werte-abgleich.json` neu per Skript.

**P5 · Mechaniken, Zustände, Maße im Vertrag**
- Ausführen: `mechanik.json` → `components.json` (`mechanics`), Zustands-Tokens je Bauteil, Maße der 29 Bauteile gemessen (Render), Dauer ↔ Kurve für die 45 Dauern nur belegt zuordnen.
- Evaluieren: P1, P2 grün; je Bauteil Zustand und Maß gemessen oder „nicht messbar“ mit Grund.
- Verifizieren: 7 Muster-Flows gegen Quelltext, Bild und `mechanik.json` (drei Wege); `diff.js` Block mit Grund je Änderung.

**P6 · Texte**
- Ausführen: 71 dynamische Texte als Schlüssel mit Platzhaltern, `en` für alle (ASD-STE100), sprechende Schlüssel für 40 wichtigste Elemente, `textKey` je Element mit Text.
- Evaluieren: t4-Lauf: 0 Gaps; jedes Element mit sichtbarem Text hat `textKey`.
- Verifizieren: Suchlauf nach sichtbaren deutschen Strings in Templates, die nicht in `texts.json` stehen: 0.

**P7 · Ansichten, Logos, Konto-Wähler, Formular**
- Ausführen: alle Aktionen inkl. Fehler/Leer/Laden in `views.json`; Logos je Dienst Material prüfen (nur Johannes' Material); Konto-Formular gegen Brief L-008 neu prüfen (Feldliste, Port, E-Mail-Adresse, Passwortzustand); Konto-Wähler messen: Kontrast hell/dunkel, lange Adressen, drei Konten, Esc, Klick daneben, Tastatur.
- Evaluieren: Kontrastprotokoll wie `KONTRAST-PROTOKOLL.md`; Break-UI-Fälle.
- Verifizieren: Bild je Zustand; Johannes bestätigt mit echter Maus (Klickfolge, Esc).

**P8 · Englisch unter der Oberfläche**
- Ausführen: Prop-Werte, Zustandswörter (`lädt`, `leer`, …), `kind: "setting"`, `data-state`-Werte englisch; sichtbare Wörter nur über `texts.json`.
- Evaluieren: `pruefung.js` Regel „Name nicht englisch“ erweitert, grün.
- Verifizieren: Render-Vergleich alt gegen neu 0 Abweichungen; Suche nach den alten Wörtern.

**P9 · Begleitdokumente**
- Ausführen: `AUDIT.md`, `RUECKGABE-AN-CODE.md`, `UEBERGABE-NAECHSTER-CHAT.md`, `TOKENBOGEN.json`-Kopf (cardMeta, Fokus 1, `apple`, `size.account*`), `ABNAHME.md` nachziehen.
- Evaluieren: ABNAHME Zeile 11 „0 Widersprüche“ mit Suchbeleg.
- Verifizieren: zweite Lesung aller Begleitdokumente gegen `akte.json`.

**P10 · Abgleich, Fremd-Audit, „raus“**
- Ausführen: ABNAHME Zeile für Zeile, `AUDIT.md` für Fremd-KI vorbereiten, Original-Prüfskripte bei Code anfragen.
- Evaluieren: zwölf Zeilen ✅ oder offen mit Grund.
- Verifizieren: Johannes' „raus“. Erst dann Paket.

## Fragen an Johannes (gebündelt, nur was Suche nicht klärt)
Maßband-Entwurf (Quelle), „Blob anheften“ (Befund oben), Farbleiter, Sperre je Ansicht, Fensterhöhe, Reife `set-by-design`, Logos (Material), Kachelnamen, Kind-DCs, Systemfrage iOS/iPadOS/Web, Abnahme Konto-Wähler/Assistent.
