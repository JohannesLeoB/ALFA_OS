Export: 21.10.2026

# Nachzug der Editor-Bögen auf Master 2110 · 21.10.2026

Quelle: `uploads/ALFA OS Interface CHEF 2110/` (Master-Kandidat 21.10.). Regeln: `CLAUDE.md` (Hülle nur einmal, Belegpflicht), `DESIGN/brief/BRIEF.txt` v9 („Namen unter der Oberfläche englisch“, data-id je Element), `HANDOFF-FUER-AGENTEN.md` Abschnitt 6.

## Übernommen (1:1 aus dem Master, alte Stände in `archiv-1810/`)
`alfa-theme.css`, `alfa-shell.js`, `ALFA Shell.dc.html`, `ALFA Bestaetigen.dc.html`, `TOKENBOGEN.json`, `alfa-bausteine.js`.

## Nachgezogen in den Editor-Bögen
Atelier, Atelier v1, Aufmass, Aufmass v1, Moodboard, Moodboard v1, Konfigurator, Planvergleich.
1. Hülle-Props englisch wie `ALFA Mail.dc.html` (Master): area, appearance, ground, typeface, handle="hairline", window, search-path, visible-lanes.
2. Tweaks englisch: appearance (light|dark), ground (white|lightGray), surface (lacquer|glass|flat), typeface, window; dazu sketch, view, state, photo, sheet, wheel, page, grid, draft, comparison, room.
3. Farbschalter `data-appearance` / `data-ground` (alfa-theme.css:3–5); auch in Entwurf A, B, Bausteinbibliothek, `alfa-material.css`.
4. data-id an jedem Element mit `data-part` und Handler, Muster `bereich.bauteil.handler` wie im Master (`shell.area-page.root-down`). Bereiche: atelier, survey, moodboard, configurator, plan-compare.
5. Export-Kopf `<!-- Export 21.10.2026 -->` je Bogen.

## Offen (nicht erfunden, Entscheidung oder Arbeit ausstehend)
- Elemente mit dynamischem `data-part="{{ … }}"` (Moodboard 6) ohne data-id.
- Editoren stehen nicht im Vertrag `contract/` (Brief v9: Pilot nur Mail, Einstellungen, Hülle; „Projekte, Heute, Kataloge … folgen nach dem Pilot im selben Format“).
- Sichtbare Texte nicht in `texts.json`; Tokens der Editor-Literale nicht geführt; Status je Wert `set-by-design`.
- Bereichsnamen (`area="Atelier"`, „Aufmaß“) bleiben deutsch wie im Master (`area: "Mail"`, „Einstellungen“).
- Entwurf C/D hängen an `alfa-glas.css` (Liquid Glass laut Master gesperrt, UEBERGABE-NAECHSTER-CHAT.md „Kein Liquid Glass“).
