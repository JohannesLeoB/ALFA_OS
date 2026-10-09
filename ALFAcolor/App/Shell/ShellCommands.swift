import SwiftUI
import ALFAcolorCore

/// View menu. The entries are in `ShortcutTable`. The four switches (⌥⌘1 sidebar, ⌥⌘0 inspector,
/// all palettes, status bar) work unchanged. The zoom entries act on the canvas of the window in focus.
/// Tab (all palettes) is not a menu shortcut, because it applies only with focus on the canvas (see CanvasSurface).
struct ShellCommands: Commands {
    @FocusedValue(\.shell) private var shell
    @FocusedValue(\.canvas) private var canvas
    @FocusedValue(\.interaction) private var interaction

    var body: some Commands {
        CommandGroup(after: .sidebar) {
            MenuEntries(menu: .view, functions: MenuFunctions(shell: shell, canvas: canvas, interaction: interaction))
        }
    }
}
