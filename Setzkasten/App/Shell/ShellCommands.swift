import SwiftUI
import SetzkastenCore

/// Menü Darstellung (B-102, B-106). Die Einträge stehen in `Tastenkarte`. Die vier Schalter aus B-102
/// (⌥⌘1 Seitenleiste, ⌥⌘0 Inspektor, Alle Panels, Statusleiste) wirken unverändert.
/// Tab (alle Panels) ist kein Menükürzel, weil es nur bei Fokus auf der Leinwand gilt (siehe CanvasView).
struct ShellCommands: Commands {
    @FocusedValue(\.shell) private var shell

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            MenuePosten(menue: .darstellung, funktionen: MenueFunktionen(shell: shell))
        }
    }
}
