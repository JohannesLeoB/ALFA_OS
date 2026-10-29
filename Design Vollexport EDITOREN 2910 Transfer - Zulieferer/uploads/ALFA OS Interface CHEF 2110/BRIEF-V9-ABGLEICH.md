Export: 19.10.2026

# Brief Code → Design v9 · Abgleich 19.10.2026 · Stand nach Arbeit am Vertrag
Quelle: `DESIGN/brief/BRIEF.txt` (Repo JohannesLeoB/ALFA_OS, main; Johannes: seit Commit 9645718, 19.10., 02:10). Kopie im Projekt: `DESIGN/brief/`. Grundlage des Briefs: Export vom 18.10. (sha256 d0ed5abb…3c8d2); alles seit 19.10. kennt Code nicht.
Ziel: Ordner `contract/` (Tokens nach DTCG, Bauteile mit ids, Ansichten, Texte, Änderungsprotokoll) für Mail, Einstellungen, Hülle, geprüft mit validate.py, check_contract.py, diff_contract.py.

## Ergebnis 19.10. (Ordner `contract/`, Werkzeuge in `contract-build/README.md`)
- **P1** (Port validate.js): alle 9 Dateien valid → „contract: valid“.
- **P2** (Port check.js, --areas shell,mail,settings, Entwürfe ALFA Mail, ALFA Einstellungen, ALFA Shell, ALFA Bestaetigen): „consistent“.
- **P3:** nicht gelaufen, erster Vertrag; Basis gesichert in `contract-build/previous/2026-10-19T16-55/`. `diff_contract.py` ist nicht nach JS portiert.
- Python lief hier nicht; die Ports sind nachgebaut nach dem Quelltext der drei .py-Dateien (Selbsttest: alle 8 Beispieldateien des Briefs valid). Bitte bei Code mit den Originalskripten gegenprüfen.

## Stand je Schritt (alt, Anfang des Tages; aktueller Stand siehe Ergebnis oben und unten „Nachtrag“)
| Schritt | Inhalt | Stand |
|---|---|---|
| T1 | Tokens nach DTCG (base, theme-light, theme-dark, alfa.resolver); Status umbenennen; 297 Funde in tokens-gegen-schema.txt | offen. TOKENBOGEN.json nutzt `approved`, `provisionalApproval`, `designSet`; der Brief nennt `approved-provisional`, `set-by-design` (Schreibweise weicht ab) |
| T2 | components.json, data-id an jedem Element | offen. bauteile.json (75, 18.10.) ist die Vorstufe, ohne id je Element und ohne flow-Muster |
| T3 | views.json (shell, mail, settings) | offen |
| T4 | texts.json (key, de, area, kind) | offen. Texte stehen im Markup und in INHALT.json |
| T5 | L-008 Konto hinzufügen, L-009 Kontowechsel (bis 3 Konten), L-010 Signaturen, L-011 Logos, L-012 Rückmeldung „Jetzt abgleichen“, L-013 Konto/Vorlage entfernen | offen. L-010 teils: Block „Signatur“ in ALFA Einstellungen über „Ich“ erreichbar (19.10.), Anlegen/Wählen je Postfach nicht. L-011: Logos für 3 von 10 Diensten (wie Brief). L-008, L-009, L-012, L-013 nicht gezeichnet. Zeilennummern des Briefs beziehen sich auf den Export 18.10. und gelten für die getrennten Bögen nicht mehr |
| T6 | L-015, L-016, W-03 bis W-07 | siehe unten |
| T7 | akte.json und werte-abgleich.json per Skript; W-01, W-02, W-08 bis W-10 | offen. Heute nur Prüfer (`lieferung-an-code/pruefung.js`), kein Erzeuger |
| T8 | changes.json | offen |

## T6 im Einzelnen
- **L-015 Fokusring-Abstand:** erledigt 19.10.: Wert 1 (Johannes: „fokusring“, Brief: „Wert wählst du“). `alfa-theme.css:6` auf 1, Token `size.focusRingOffset` 1, ALFA Bestaetigen unverändert 1. Grund: Pille 28, Knopf 20, Rand 4; Ring 2 + Abstand 1 = 3 passt, 2 + 2 stößt an die Pillenkante.
- **L-016 menu-row:** erledigt 19.10. (Johannes: „einberstanden, bitte setze das so um.“): Radius 12 und Innenabstand 12 in beiden Menüs. Grund: Zeilenradius = Außenradius − Innenabstand (Blob 20 − 8, Kontextmenü 16 − 4), Token `menuRowPadding` 12, Zeile 12 laut Rückgabe 17.10. Gemessen in ALFA Mail (6 Menüs) und ALFA Einstellungen: Radius 12, Innenabstand 12, Trennlinie 12; Breiten 168 bis 280 auf dem 56er-Raster, keine abgeschnittenen Zeilen außer der 64-Zeichen-Adresse bei Höchstbreite 280 (Ellipsis).
- **W-03** „Fenster 960 × 600“ streichen: im Projekt keine Fundstelle mehr (grep 19.10.: 0 Treffer). Johannes 13.10.: „wieso hängst du so an dieser 960er Mini ansicht??? … Weg damit“ ✅.
- **W-04** trailingTextInset: `decisions.json:99` nannte 14, Token und RUECKGABE 12. Behoben 19.10. auf 12 ✅.
- **W-05** Dienstzahl in settings-sections.json:4: offen (nicht neu gezählt).
- **W-06** Gruppen der Einstellungen: im Bogen Ich, Firma, Verbindungen, Schutz und System; INHALT.json:93 und :1223 nicht nachgezogen: offen.
- **W-07** 47 Felder in INHALT.json felder_je_abschnitt: offen.
- **Als entschieden gemeldet (Code zitiert Johannes 19.10., Wortlaut liegt mir nicht vor):** Kachelhöhe Integrationen 112 (Stand der Bögen), Kartenstapel 8a/8b als Einstellung mit Vorgabe 8a (Stand der Bögen), L-014 Firmendaten/Impressum trägt der Nutzer ein. Bis zum Wortlaut: „Code berichtet“.

## Folge
Der Brief ist ein Auftrag von Code an Design: T1 bis T8 sind ein großer neuer Lieferumfang. Beginn erst auf dein Wort („go“ für den Vertrag), weil T1 allein die Status-Schreibweise und rund 300 Funde berührt.

## Nachtrag 19.10. (nach dem Bau)
| Schritt | Stand |
|---|---|
| T1 Tokens | erledigt (394 Tokens in 4 Dateien, Status auf approved / approved-provisional / set-by-design, component.* als echte Tokens, stack und surface als benannte Tokens, color.mood je Thema, confirm.tooltip an confirm-pill). motion.transition.* für die gleichnamigen Paare (blobFlight, stack, fold) angelegt; die übrigen Dauern haben keine gleichnamige Kurve und werden nicht erfunden. Tokens ohne Wortlaut bleiben `set-by-design` |
| T2 Bauteile | teils: 76 Bauteile, 187 Elemente, jedes mit data-id in den Bögen. Maße: 49 von 76 Bauteilen mit Höhe oder Radius als Token; Zustände haben Namen, aber leere `tokens`; keine `mechanics` je Bauteil (nur `flow` bei 7 Mustern). Ids sind erzeugt (Bauteil + Handlername), nicht von Hand benannt |
| T3 Ansichten | teils: shell, mail, settings mit Bahnen, 4 bis 5 Aktionen je Ansicht; nicht alle Aktionen |
| T4 Texte | teils: 283 Texte (de) aus Vorlagen und Logik; 71 dynamische oder zusammengesetzte Texte nicht erfasst (Liste im Lauf); Schlüssel erzeugt (Element-Id oder Art + Zähler), `en` fehlt überall |
| T5 Fehlender Inhalt | offen (L-008, L-009, L-012, L-013 nicht gezeichnet; L-010 teils; L-011 3 von 10 Logos) |
| T6 Werte | L-015 ✅, L-016 ✅, W-03 ✅, W-04 ✅; W-05, W-06, W-07 offen |
| T7 Begleitdokumente per Skript | offen |
| T8 Protokoll | erster Block (previous none, changes leer); Skript für Folgeblöcke fehlt |

## T6 Nachtrag
- W-05 ✅ settings-sections.json: „11 Dienste“ → „10 Dienste inkl. Mail-Konten; monday nur in ALFA Dienste“ (Zählung: SVC in ALFA Einstellungen = google, mailkonten, clickup, clockodo, claude, airtable, sevdesk, dhl, dhlversand, happa).
- W-06 ✅ INHALT.json `kategorien` und `gruppen[Einstellungen].eintraege` auf Ich, Firma, Verbindungen, Schutz und System (Symbole person, building, plug, system wie CATS in ALFA Einstellungen).
- W-07 offen: 47 Felder in `felder_je_abschnitt` (10 Abschnitte, Namen deutsch: identitaet, darstellung, konten, firma, ordner, vorlagen, mail, datenschutz, system, impressum) gegen den Vertrag; kein Feld ist heute ein Token oder Element.

## Stand 19.10. abends (nach „alles planvoll abarbeiten und verifizieren“)
- **Vertrag neu erzeugt:** 397 Token-Definitionen (340 Pfade), 76 Bauteile, 188 Elemente, 291 Texte, 3 Ansichten. **P1** „contract: valid“ (9 Dateien), **P2** „consistent“, **P3** „log matches“ gegen die Basis (134 Änderungen im zweiten Block, `changes.json` hat 2 Blöcke). Prüfer sind JS-Ports (contract-build/validate.js, check.js, diff.js); gegen die Originale bei Code prüfen.
- **T5 gebaut in den Bögen (vorher nur beschrieben):**
  - L-008 Konto hinzufügen (ALFA Einstellungen › Verbindungen › Mail-Konten): Formular mit Anbieter (Gmail, GMX, IONOS), Anzeigename, Server Eingang, Port, Verschlüsselung (Keine, SSL/TLS), Server Ausgang, Passwort, Passwort Ausgang; Prüfung zeigt „Es fehlen: …“ oder „Eingang und Ausgang erreichbar.“ Felder aus INHALT.json:1063 und der Prüfung-Liste (:928–958), Feldliste im Quelltext von INHALT abgeschnitten, Rest aus der Prüfmeldung abgeleitet.
  - L-009 Kontowechsel in Mail: Kopf der linken Bahn ist jetzt ein Wähler (Konten, Häkchen am gewählten, „Konto hinzufügen“ führt zu den Einstellungen). Heute nur ein Konto in den Daten; bis zu drei laut decisions.json:30.
  - L-010 Signatur: „Signatur anlegen“ in Einstellungen › Ich › Signatur je Konto (nur für das eigene Konto mit Text, neue Konten leer); Wählen in Mail bleibt wie bisher im Entwurf.
  - L-012 Rückmeldung von „Jetzt abgleichen“: Zeile zeigt „Verbindung steht. Letzter Abgleich …“ bzw. „Fehler: … .“ (Wortlaut Prüfung INHALT.json:928–958).
  - L-013 Konto entfernen und Vorlage entfernen mit Bestätigen-Pille („Konto entfernen?“, „Vorlage entfernen?“). Vorlagen heißen „Vorlage 1, 2 …“ (Name von Design gesetzt).
  - L-011 Logos: nicht gebaut. Es gibt nur drei Logos (Clockodo, DHL, monday) von Johannes; weitere Marken zeichne ich nicht.
- **T6:** L-015, L-016, W-03 bis W-07 erledigt (W-07: 31 der 47 Felder im Bogen, 16 gestrichen als Dummy-Abschnitt, siehe INHALT.json `felder_status`, nach Namenssuche, nicht je Feld geprüft).
- **T7:** teils: `contract-build/t7-akte.js` setzt Tokenzahl (W-01), Bytes (W-02) und `answered` in akte.json. `werte-abgleich.json` wird nicht erzeugt (offen), W-08 bis W-10 offen.
- **T8:** Skript `diff.js` (makeBlock) erzeugt Folgeblöcke; Grund je Änderung ist eine Sammelformel.
