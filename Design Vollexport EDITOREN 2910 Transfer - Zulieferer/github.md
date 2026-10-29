repo: JohannesLeoB/ALFA_OS
branch: main
draws-branch: alfa-draws (auf GitHub, alfaos/Draws; NOTES.md Stand 23.10.2026, nicht auf main)

## Last sync
date: 2026-10-29T14:58:49Z
alfa-draws Baumstand: 47951ebd300f (Tree-Hash, kein Commit). Am 14:58 identisch zu 14:44, keine Änderungen seit dem letzten Sync.
Kein Commit-Stand aus dem Sync vom 23.10. gespeichert, daher kein echter Diff. Verglichen wurden die Quellen der Draws-v2-Karte gegen den heutigen Zweig alfa-draws. main und alfa-draws sind auseinandergelaufen (Verlauf auf main neu geschrieben, 146 Commits nur auf main).

### Updated in this project
- Geprüft, ohne Abweichung zu ALFA Draws v2: Examples/kueche.json (14 Teile, 4 Einheiten), Packs/presets/default.json (4 Vorgaben), Packs/template/studio-a3-plan/template.json, Layouts.swift (Blattarten), Shell.swift (Lanes, Blob-Menü)
- Neu in Proto.swift seit der Mapping-Liste, in v2 nicht abgebildet: editorWidth 240, editorInset 8, stepCoarse 50, stepFine 10, undoDepth 100, ringInset 4, stale 0.5
- Neue Quelldateien ohne Karte: Editing.swift, CabinetMenu.swift, Configurator.swift, DocFiles.swift, ClaudeEntry.swift, DrawsApp.swift; nicht gelesen
- v2 nicht verändert; Lanes.swift, Parts.swift, ClaudePanel.swift, DrawsModel.swift, Localizable.xcstrings nicht neu gelesen (kein Vergleichsstand)

## Screen map
| Screen | Repo-Dateien (Zweig alfa-draws) |
|---|---|
| ALFA Draws v2 | alfaos/Draws/Sources/DrawingDudeApp/{Shell,Lanes,Parts,ClaudePanel,Proto,DrawsModel,Layouts}.swift, Resources/Localizable.xcstrings, Packs/template/studio-a3-plan/template.json, Packs/presets/default.json, Examples/kueche.json, specs/design-needs.md |
| Ungemappt (neu im Zweig) | DrawingDudeApp/{Editing,CabinetMenu,Configurator,DocFiles,ClaudeEntry,DrawsApp,Style}.swift |
| ALFA Draws (v1) | keine Repo-Quelle (vor Fund von alfaos/Draws gebaut) |

## Sync history
- 2026-10-23T12:34:45Z: ALFA Draws v2 aus lokalem Clone ALFA_DRAWS (Zweig alfa-draws, NOTES.md 23.10.2026) gebaut
