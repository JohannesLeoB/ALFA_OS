import SwiftUI
import ALFAcolorCore

/// All menus of the app. The entries are in `ShortcutTable` (ALFAcolorCore).
/// System menus stay with the system. Only the app's own entries are added, or they replace the place of `New Document`.
struct ALFAcolorCommands: Commands {
    var body: some Commands {
        ShellCommands()
        FileCommands()
        EditCommands()
        ObjectCommands()
        WindowCommands()
        HelpCommands()
    }
}

struct FileCommands: Commands {
    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            MenuEntries(menu: .file, functions: MenuFunctions())
        }
    }
}

struct EditCommands: Commands {
    var body: some Commands {
        CommandGroup(after: .pasteboard) {
            MenuEntries(menu: .edit, functions: MenuFunctions())
        }
    }
}

struct ObjectCommands: Commands {
    var body: some Commands {
        CommandMenu("menu.object") {
            MenuEntries(menu: .object, functions: MenuFunctions())
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
                functions: MenuFunctions(showShortcutTable: { openWindow(id: ShortcutTableView.windowID) })
            )
        }
    }
}
