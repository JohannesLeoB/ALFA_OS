# HILFE-02 · Code-Schnitt

Quelle: `JohannesLeoB/ALFA_OS`, Commit `f22d7bcc9e73be346ee1e13a8f691a09a9225629`. Ergebnis **ungeprüft**.

## Module

- `Package.swift` erklärt 14 Bibliotheken: Core, Design, Shell, Storage, Calculation, Hub, Assistant, Mail, Google, Airtable, ClickUp, Sevdesk, Clockodo und Shipping (`Package.swift:13–26`).
- Jede Bibliothek hat ein eigenes Ziel mit festem Pfad, zum Beispiel `Sources/Shell` (`Package.swift:34`) und `Sources/Integrations/Google` (`Package.swift:68`).
- Das App-Ziel bindet alle 14 Bibliotheken ein (`project.yml:36–63`, 14 × `package: ALFA`; `ARCHITECTURE.md:5`).
- Als Ressourcen gehen nur Schriften, Assets, `Localizable.xcstrings` und `apps.json` in die App (`project.yml:26–35`).

| Modul | Hängt ab von | Beleg |
|---|---|---|
| Core | – | `ARCHITECTURE.md:9`, `Package.swift:32` |
| Design | – | `ARCHITECTURE.md:10`, `Package.swift:33` |
| Shell | Design | `ARCHITECTURE.md:11`, `Package.swift:34` |
| Storage | Core, GRDB | `ARCHITECTURE.md:12`, `Package.swift:35–38` |
| Hub | Core, Design, Storage, GRDB | `ARCHITECTURE.md:13`, `Package.swift:41–44` |
| Mail | Core, Design, Shell, Storage, Hub, GRDB | `ARCHITECTURE.md:14`, `Package.swift:47–50` |
| Calculation | Core, Storage, GRDB | `ARCHITECTURE.md:15`, `Package.swift:53–56` |
| Assistant | Core, Design, Storage, Hub, Calculation, GRDB | `ARCHITECTURE.md:16`, `Package.swift:59–62` |
| Google, Airtable, ClickUp, Sevdesk, Clockodo, Shipping | Hub, Assistant und weitere | `ARCHITECTURE.md:17–22` |

- Integrationen hängen nie voneinander ab. `App` enthält nur Ansichten und hängt von jedem Modul ab (`ARCHITECTURE.md:37`).
- Reservierte Modulnamen ohne Code: Catalog, Project, Today und Survey (`ARCHITECTURE.md:54`, `:151`).

## Ansichten (App)

- `App/<Feature>/` hat einen Ordner je Bereich (`ARCHITECTURE.md:46`). Heute gibt es `App/Components`, `App/Design`, `App/Mail`, `App/Settings` und `App/Shell` (Verzeichnisliste am Commit).
- `Resources/apps.json` nennt genau zwei Apps, `mail` (Gruppe `communication`) und `settings` (Gruppe `core`). Panes gibt es nur für diese beiden (`ARCHITECTURE.md:152`).
- `App/Shell/Assembly.swift` baut alle Abhängigkeiten. `AppSession` erzeugt die Panes `mail` und `settings` (`ARCHITECTURE.md:120`).

## Was geteilt wird

| Geteilt | Wo | Wer liest | Beleg |
|---|---|---|---|
| Tokens | `Resources/tokens.json` (8363 Z.) → `utils/generate_tokens.py` → `Sources/Design/Model` | alle Ansichten über `Tokens`, `Colors`, `Moods`, `Shadows`, `Surface`, `InkSet` | `ARCHITECTURE.md:132` |
| Tokens aus dem Vertrag | aus `contract/` der Lieferung 28.10. umgerechnet (base, theme-light, theme-dark, ground-lightGray) | – | `CLAUDE.md:32` |
| Texte | `Resources/*.localizable.json` (9 Dateien) → `Localizable.xcstrings` | Ansichten über `Appearance`, Engines über `TextPort` | `ARCHITECTURE.md:136` |
| Werte in Ansichten | nur aus `Design`-Tokens oder `App/Design/SheetValues.swift` | alle `App`-Ansichten | `ARCHITECTURE.md:97` |
| Bauteile | `App/Components` (33 Dateien, z. B. `Chip.swift`, `MenuPanel.swift`, `LaneHead.swift`) | Stichprobe per Namenssuche: `Chip` und `MenuPanel` in `App/Mail`, `LaneHead` in `App/Mail` und `App/Shell`; alle übrigen nicht geprüft | Verzeichnisliste, `grep` |
| Hülle | `App/Shell` (Blob, DeskLane, LaneHandle, SyncButton, AssistantPanel …) und `Sources/Shell` | alle Panes | `ARCHITECTURE.md:11`, `:120`, `:149` |
| Hub | Verbindungen, Postfächer, Einstellungen-Daten | Mail, Assistant, alle Integrationen | `ARCHITECTURE.md:13–22` |

## Folgerung für den Schnitt (nur aus den Belegen oben)

- **Gemeinsam für alle Bereiche:** Design (Tokens), Texte, Bauteile (`App/Components`) und Hülle (`App/Shell`, `Sources/Shell`).
- **Je Bereich:** Mail (`App/Mail` mit `Sources/Mail`) und Einstellungen (`App/Settings` mit Hub).
- **Ohne Code:** Projekte (Name `Project` reserviert) und Werkstatt. Bei der Werkstatt ist nur Survey reserviert. Die Werkstatt als ein eigenes Modul ist entschieden (`CLAUDE.md:24`), ein Modulname dafür fehlt.
