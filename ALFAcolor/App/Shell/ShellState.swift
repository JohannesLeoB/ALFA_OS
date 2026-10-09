import SwiftUI
import Motion

/// State of the window shell: which areas are visible.
/// It belongs to one window. Menu commands reach it through `focusedSceneValue`.
@MainActor
@Observable
final class ShellState {
    /// Sidebar: `.all` shows it, `.detailOnly` hides it. The system key of the toolbar writes here too.
    var columnVisibility: NavigationSplitViewVisibility = .all
    var inspectorVisible = true
    var statusBarVisible = true
    /// Blob mode: the blob menu replaces the sidebars. The sidebars and the inspector are hidden while it is on.
    private(set) var blobMode = false
    /// State of the blob menu. Only the views of the menu change it.
    var blob = BlobMenu()
    /// Placeholder for the space tabs.
    var selectedRoom: PlaceholderRoom = .mail

    var sidebarVisible: Bool {
        get { columnVisibility != .detailOnly }
        set { columnVisibility = newValue ? .all : .detailOnly }
    }

    func toggleSidebar() { sidebarVisible.toggle() }
    func toggleInspector() { inspectorVisible.toggle() }
    func toggleStatusBar() { statusBarVisible.toggle() }

    /// Switches between the sidebars and the blob menu. Leaving the blob mode shows the sidebars again.
    func toggleBlobMode() {
        blobMode.toggle()
        sidebarVisible = !blobMode
        inspectorVisible = !blobMode
    }

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
