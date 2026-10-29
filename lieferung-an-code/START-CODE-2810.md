# Übergabe Design → Code · 28.10.2026
Stand: Lieferschein 2026-10-28T15:40. Freigabe: Johannes 28.10. („bitte … als ZIP ausgeben“).

## Lesereihenfolge
1. project/lieferung-an-code/ANTWORT-2810.md — Antwort auf deine Rückgabe vom 27.10. und N37 (Assistent).
2. project/lieferung-an-code/OFFEN-AN-CODE-2710.md — offene Einträge nach Schema, Rückgabe nur nach Bedarf (Abschnitte A bis J).
3. project/lieferung-an-code/ENTSCHEIDUNGEN-AN-CODE-2310.md — verbindliche Entscheidungen (inkl. LIEF-K01 bis K04, MAIL-Z01, LIEF-T8).
4. project/lieferung-an-code/SPEC-NACHTRAG-2310.md — Spec-Nachtrag (HUELLE-L07/L08/K02, MAIL-G01 224 bis 280, MAIL-D01).
5. contract/ — der Vertrag (Tokens, Bauteile, Ansichten, Texte, Änderungsprotokoll, Lieferschein, PRUEFUNG.txt).
6. project/lieferung-an-code/symbols.json, bauteile.json, mechanik.json, motion-springs.json, settings-sections.json, akte.json.
7. project/entscheidungen.md — Wortlaut aller Ansagen von Johannes, mit Datum.

## Geändert seit dem Paket vom 27.10.
- Postfachstapel: alle Werte aus deiner Rückgabe als Tokens (motion.duration deckOpen … glassDelay, motion.easing deckOpen/deckClose/envelopeSpring/glassIn/glassOut, opacity.switchGlass, size.ghostShadow*, size.envelopeStroke, color.ghostShadow/ghostRing). size.recipientPaddingOpen gestrichen.
- MAIL-G01: Mail linke Bahn 224 (size.mailLaneMinimumLeft) bis 280 (size.mailLaneMaximumLeft). Fläche der Postfächer: Vorgabe lacquer.
- N32 gestrichen (stored/orphaned).
- N37 Assistent gezeichnet: ALFA Shell :89 ff.; Bauteile assistant, assistant-thread, assistant-message, assistant-activity, assistant-card, assistant-attachment, assistant-scope, assistant-input; Tokens count.chatDocumentByteLimit 20000000, count.chatTextCharacterLimit 120000, opacity.disabled 0.4.
- Bauteil-Fundstellen (where) in contract/components.json neu aus den Bögen: 100 % stimmen.

## Prüfer (wörtlich)
P1 contract: valid · P2 consistent · P3 log matches (667) · P4 items: 30 of 44 done · delivery: complete · pruefung.js: gruen true.

## Nicht in diesem Paket
Entwurf ALFA PDF (gelöscht, N16 macOS nativ), Farbbögen (gesperrt), Dienste/Widgets-Bauteile (nur nach Bedarf).
