# Verflechtung · Bereich × Bereich

Stand 29.10.2026, **ungeprüft**. 45 Einträge in `verflechtung.json` mit je einer Stelle in Design und Code.

- **Je Art:** Route 12, Einstellung 11, Daten 8, Vorgabe 8, Aktion 6.
- **Lücken:** Bei 7 Einträgen fehlt die Stelle im Design, bei 17 die im Code.

Zeile = wer etwas anbietet oder braucht, Spalte = von wem. Zahl = Einträge, Beispiele stehen in `verflechtung.json`.

| von \ an | Grundlage | Hülle | Mail | Einstellungen | Hub | Assistent | Projekte | Werkstatt |
|---|---|---|---|---|---|---|---|---|
| **Grundlage** | · | 1 | 1 | 1 | · | · | · | · |
| **Hülle** | · | · | 2 | 2 | · | 1 | · | · |
| **Mail** | · | · | · | 1 | 1 | · | 2 | · |
| **Einstellungen** | · | 2 | 3 | · | 2 | 3 | 2 | 1 |
| **Hub** | · | · | 2 | · | · | 4 | 3 | · |
| **Assistent** | · | · | · | · | · | · | · | · |
| **Projekte** | · | · | 2 | 2 | 1 | · | · | · |
| **Werkstatt** | · | · | · | 1 | 2 | · | 3 | · |

**Befund**
- **Einstellungen greift in sechs Bereiche:** Mail, Assistent, Hülle, Hub, Projekte und Werkstatt.
  - Im Code: `App/Settings/SettingsContext.swift:1–18` importiert Assistant, Hub, Mail und Shell. Es hält `InboxState`, `DeskState` und `ChatState`.
- **Hub beliefert Mail, Assistent und Projekte.** Im Code ist der Hub ein eigenes Modul (`Sources/Hub`). Seine Ansicht ist Einstellungen; einen eigenen Bogen gibt es nur als „ALFA Dienste“.
- **Projekte und Werkstatt bestehen nur als Brief.** Ihre Verflechtungen stehen im Brief, im Code fehlen sie.
  - Ausnahme: Mail ↔ Projektordner ist gebaut (`App/Mail/ProjectFolderList.swift:9`).
- **Der Assistent bietet niemandem etwas an.** Er nimmt nur, über Werkzeuge je verbundenem Dienst (`App/Shell/ToolShelf.swift:51`).
