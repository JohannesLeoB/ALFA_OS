# Vertrag nach Schnitt

Quelle: `Design Vollexport 2910 Transfer - Etappe I/contract/` auf `DESIGNCHANNEL`. Gezählt per Skript. **Ungeprüft.**

| Datei | gesamt | mit Bereichs-Vorsilbe | gemeinsam / mehrere Bereiche |
|---|---|---|---|
| `texts.json` | 388 | `area`: mail 192, settings 169, shell 27 | Schlüssel ohne Bereichswort: 12 (z. B. `card.close`, `menu.search`, `assistant.field`). 7 Texte gehören laut `element` zu einem anderen Bereich als ihr Schlüssel, z. B. `settings.service.dhlship.field.password` → `shell.lock-password` |
| `components.json` (Bauteile) | 97 | nur in einem Bogen: Mail 31, Shell 24, Einstellungen 12, Bestätigen 6 | **24 in mehreren Bögen:** Einstellungen + Mail 18, alle drei 4, Mail + Shell 2 |
| `components.json` (Element-IDs) | 230 | mail 126, settings 59, shell 39, confirm 6 | IDs tragen immer eine Bereichs-Vorsilbe |
| `views.json` | 3 Ansichten (shell, mail, settings) | Aktionen: shell 4, mail 6, settings 7 + confirm 1 | `textKeys` sind fast leer (mail 1, sonst 0); Querbezüge über Ansichten sind hier nicht erfasst |
| `base.tokens.json` | 355 | Bereichswort im Namen: blob 41, confirm 12, mail 5, settings 2, assistant 1, project 1 | 293 ohne Bereichswort. Fundstelle (`where`): ohne 139, Mail 88, Shell 40, `alfa-shell.js` 26, Einstellungen 14, Bestätigen 13 |
| `theme-light` / `theme-dark` | 73 / 70 | kein Bereichswort | Fundstelle meist leer (57 / 55) |

**Folgerung:**
- Texte und Element-IDs sind heute **nach Bildschirm** geschnitten.
- Bauteile und Tokens sind überwiegend **gemeinsam**. Ein Viertel der Bauteile steht in mehreren Bögen; drei Viertel der Tokens tragen kein Bereichswort.
- Die Tokens erfasst `where` nur als Fundstelle, nicht als Nutzung. Wie oft ein Token über Bereiche genutzt wird, ist deshalb nicht messbar (`unklar`).
