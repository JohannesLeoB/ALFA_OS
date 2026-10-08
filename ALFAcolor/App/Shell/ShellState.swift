import SwiftUI

/// State of the window shell: which areas are visible.
/// It belongs to one window. Menu commands reach it through `focusedSceneValue`.
@MainActor
@Observable
final class ShellState {
    /// Sidebar: `.all` shows it, `.detailOnly` hides it. The system key of the toolbar writes here too.
    var columnVisibility: NavigationSplitViewVisibility = .all
    var inspectorVisible = true
    var statusBarVisible = true
    /// Placeholder for the space tabs.
    var selectedRoom: PlaceholderRoom = .mail

    var sidebarVisible: Bool {
        get { columnVisibility != .detailOnly }
        set { columnVisibility = newValue ? .all : .detailOnly }
    }

    func toggleSidebar() { sidebarVisible.toggle() }
    func toggleInspector() { inspectorVisible.toggle() }
    func toggleStatusBar() { statusBarVisible.toggle() }

    /// Tab on the canvas: if any palette is open, both close. Otherwise both open.
    func togglePalettes() {
        let anyVisible = sidebarVisible || inspectorVisible
        sidebarVisible = !anyVisible
        inspectorVisible = !anyVisible
    }
}

/// Static space tabs. The raw value is the key of the tab title in the string catalog.
enum PlaceholderRoom: String, CaseIterable, Identifiable {
    case mail = "room.mail"
    case colors = "room.colors"
    var id: Self { self }
}

extension FocusedValues {
    @Entry var shell: ShellState?
}
