import SwiftUI

/// Zustand der Fensterschale (B-102): welche Bereiche sichtbar sind.
/// Gehört zu einem Fenster; Menübefehle erreichen ihn über `focusedSceneValue`.
@MainActor
@Observable
final class ShellState {
    /// Seitenleiste: `.all` zeigt sie, `.detailOnly` blendet sie aus. Die Systemtaste der Werkzeugleiste schreibt hier mit.
    var columnVisibility: NavigationSplitViewVisibility = .all
    var inspectorVisible = true
    var statusBarVisible = true
    /// Platzhalter für die Raum-Reiter (echte Räume: B-206).
    var selectedRoom: PlaceholderRoom = .mail

    var sidebarVisible: Bool {
        get { columnVisibility != .detailOnly }
        set { columnVisibility = newValue ? .all : .detailOnly }
    }

    func toggleSidebar() { sidebarVisible.toggle() }
    func toggleInspector() { inspectorVisible.toggle() }
    func toggleStatusBar() { statusBarVisible.toggle() }

    /// Tab auf der Leinwand: ist irgendein Panel offen, schließen sich beide, sonst öffnen sich beide.
    func togglePanels() {
        let anyVisible = sidebarVisible || inspectorVisible
        sidebarVisible = !anyVisible
        inspectorVisible = !anyVisible
    }
}

/// Statische Raum-Reiter, bis B-206 echte Räume liefert.
enum PlaceholderRoom: String, CaseIterable, Identifiable {
    case mail = "Mail"
    case farben = "Farben"
    var id: Self { self }
}

extension FocusedValues {
    @Entry var shell: ShellState?
}
