import SwiftUI

/// Tasten für die Fensterschale (B-102) als Menüeinträge unter „Darstellung“.
/// Die volle Menüleiste und die Tastenkarte baut B-106; dort wandern diese Einträge hin.
/// Tab (alle Panels) ist kein Menükürzel, weil es nur bei Fokus auf der Leinwand gilt (siehe CanvasView).
struct ShellCommands: Commands {
    @FocusedValue(\.shell) private var shell

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            Button("Seitenleiste ein/aus") { shell?.toggleSidebar() }
                .keyboardShortcut("1", modifiers: [.option, .command])
                .disabled(shell == nil)
            Button("Inspektor ein/aus") { shell?.toggleInspector() }
                .keyboardShortcut("0", modifiers: [.option, .command])
                .disabled(shell == nil)
            Button("Alle Panels ein/aus") { shell?.togglePanels() }
                .disabled(shell == nil)
            Button("Statusleiste ein/aus") { shell?.toggleStatusBar() }
                .disabled(shell == nil)
        }
    }
}
