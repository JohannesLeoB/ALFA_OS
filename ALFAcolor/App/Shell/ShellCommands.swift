import SwiftUI
import ALFAcolorCore

/// View menu. The entries are in `ShortcutTable`. The four switches (⌥⌘1 sidebar, ⌥⌘0 inspector,
/// all palettes, status bar) work unchanged.
/// Tab (all palettes) is not a menu shortcut, because it applies only with focus on the canvas (see CanvasView).
struct ShellCommands: Commands {
    @FocusedValue(\.shell) private var shell

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            MenuEntries(menu: .view, functions: MenuFunctions(shell: shell))
        }
    }
}
