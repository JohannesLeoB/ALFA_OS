import SwiftUI
import ALFAcolorCore
import BoardModel

/// All menus of the app. The entries are in `ShortcutTable` (ALFAcolorCore).
/// System menus stay with the system. Only the app's own entries are added, or they replace the place of `New Document`.
struct ALFAcolorCommands: Commands {
    var body: some Commands {
        ShellCommands()
        FileCommands()
        EditCommands()
        ObjectCommands()
        RoomCommands()
        WindowCommands()
        HelpCommands()
    }
}

/// File menu. The document scene provides New, Open, Open Recent, Save, Duplicate (Save As with the Option key),
/// Rename, Move To and Revert To with the keys of the shortcut table. Only the entries it does not provide are added here.
struct FileCommands: Commands {
    /// The commands of the shortcut table that the document scene provides.
    static let providedByDocumentScene: Set<String> = [
        "file.new", "file.open", "file.recent", "file.save", "file.duplicate", "file.rename", "file.move", "file.revert"
    ]
    @FocusedValue(\.interaction) private var interaction

    var body: some Commands {
        CommandGroup(after: .importExport) {
            MenuEntries(menu: .file, functions: MenuFunctions(interaction: interaction), hiding: Self.providedByDocumentScene)
        }
    }
}

struct EditCommands: Commands {
    @FocusedValue(\.interaction) private var interaction

    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            MenuEntries(menu: .edit, functions: MenuFunctions(interaction: interaction))
        }
    }
}

struct ObjectCommands: Commands {
    @FocusedValue(\.interaction) private var interaction

    var body: some Commands {
        CommandMenu("menu.object") {
            MenuEntries(menu: .object, functions: MenuFunctions(interaction: interaction))
        }
    }
}

struct WindowCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .windowArrangement) {
            MenuEntries(menu: .window, functions: MenuFunctions())
        }
    }
}

struct HelpCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .help) {
            MenuEntries(
                menu: .help,
                functions: MenuFunctions(
                    showShortcutTable: { openWindow(id: ShortcutTableView.windowID) },
                    openStarter: { StarterOpener.open() }
                )
            )
        }
    }
}
