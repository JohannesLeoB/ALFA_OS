# Code-Schnitt

`ALFA_OS` `main` @ f22d7bcc. **Ungeprüft.**

## Schichten im Code

| Schicht | Module | Beleg |
|---|---|---|
| Grundlage | Core, Design (Tokens), Shell (Hülle-Logik), Storage | `ARCHITECTURE.md:9–12` |
| Fachmodule | Hub, Mail, Calculation, Assistant | `ARCHITECTURE.md:13–16` |
| Dienste | Google, Airtable, ClickUp, Sevdesk, Clockodo, Shipping | `ARCHITECTURE.md:17–22` |
| Ansichten | `App/Mail`, `App/Settings`, `App/Shell`, `App/Components`, `App/Design` | `ARCHITECTURE.md:37`, `:46` |
| Zusammenbau | `App/Shell/Assembly.swift`, `ToolShelf` | `ARCHITECTURE.md:120` |

Dienste hängen nie voneinander ab (`ARCHITECTURE.md:37`). Ports sind die Schnittstelle zwischen Modulen.
- Beispiel: `MailSearchPort` wird im Assistant erklärt (`Sources/Assistant/Port/MailSearchPort.swift:1`) und in Google umgesetzt (`Sources/Integrations/Google/Adapter/AccessRouter.swift:67`).
- Angemeldet wird er je Fähigkeit (`App/Shell/Assembly.swift:137–140`).

## Wo Einstellungen und Hub leben

- **Hub** (`Sources/Hub`) enthält:
  - die Dienste (`Inlet`, `Connections`) und die Fähigkeiten `mail, calendar, contacts, files, tasks, time, documents, assistant, shipping` (`Sources/Hub/Model/Capability.swift:2`);
  - den Abgleich (`SyncEngine`), Schlüssel (`KeychainStore`) und die Einrichtung (`SetupEngine`);
  - den Zustand `SettingsState` und 16 Ports, darunter `FilesPort` mit `projectFolders()` (`Sources/Hub/Port/FilesPort.swift:4`).
  - „projects“ hat keine Fähigkeit (`Capability.swift:14`).
- **Einstellungen** sind nur Ansicht (`App/Settings`, 29 Dateien). Die Abschnitte sind eine feste Liste im Hub (`Sources/Hub/Model/SettingsSection.swift:1–26`), nicht Beiträge der Module.
- **Querzugriffe der Ansichten** (Zahl der Dateien mit `import`):

  | Ansicht | importiert |
  |---|---|
  | `App/Mail` | Hub ×12, Shell ×9 |
  | `App/Settings` | Hub ×17, Mail ×3, Assistant ×3, Shell ×8 |
  | `App/Shell` | alle sechs Dienste, Assistant ×10 |
  | `Sources/Mail` | Hub ×30 |

## Wo die These der Design-Sitzung trägt und wo nicht

- **Trägt:** Der Code ist in Schichten geschnitten (Grundlage, Fachmodule, Dienste, Ansichten), mit Ports als Schnittstellen. Einstellungen ist eine Ansicht, die viele Module zusammenführt.
- **Trägt nicht:**
  1. Der Hub ist im Code ein **Modul** mit Daten und Logik, keine reine Ansicht.
  2. Einstellungen sammelt keine Beiträge der Module ein. Die Abschnitte sind zentral festgelegt, und die Ansicht greift direkt auf Mail, Assistant und Shell zu.
  3. Der Assistent hat keine eigene Ansicht; er sitzt in der Hülle (`App/Shell/AssistantPanel.swift`).
