import SwiftUI
import ALFAcolorCore

/// What a menu entry does when triggered.
typealias MenuAction = @MainActor () -> Void

/// The functions behind the menu entries. A command without an entry here stays visible and dimmed.
struct MenuFunctions {
    var shell: ShellState?
    var showShortcutTable: MenuAction?

    @MainActor
    func action(for command: MenuCommand) -> MenuAction? {
        switch command.id {
        case "view.sidebar": return with { $0.toggleSidebar() }
        case "view.inspector": return with { $0.toggleInspector() }
        case "view.allPalettes": return with { $0.togglePalettes() }
        case "view.statusBar": return with { $0.toggleStatusBar() }
        case "help.shortcutTable": return showShortcutTable
        default: return nil
        }
    }

    /// Connects a toggle function to the state of the window. Without a window, the entry stays dimmed.
    @MainActor
    private func with(_ perform: @escaping @MainActor (ShellState) -> Void) -> MenuAction? {
        guard let shell else { return nil }
        return { perform(shell) }
    }
}

/// The members of a menu from the shortcut table. Only entries with `origin == .app` appear.
/// What macOS provides itself stays with macOS.
struct MenuEntries: View {
    let menu: AppMenu
    let functions: MenuFunctions

    var body: some View {
        ForEach(ShortcutTable.entries(menu, origin: .app)) { entry in
            switch entry {
            case .separator:
                Divider()
            case .command(let command):
                CommandItem(command: command, action: functions.action(for: command))
            case .submenu(let titleKey, let commands):
                Menu(LocalizedStringKey(titleKey)) {
                    ForEach(commands) { command in
                        CommandItem(command: command, action: functions.action(for: command))
                    }
                }
            }
        }
    }
}

/// A menu entry. The shortcut is only on commands that apply everywhere. The single keys of the tools
/// are bound with focus on the canvas. This way menus do not catch letters from text fields.
struct CommandItem: View {
    let command: MenuCommand
    let action: MenuAction?

    var body: some View {
        if let shortcut = command.shortcut, command.scope == .always, let key = keyEquivalent(for: shortcut.key) {
            Button(LocalizedStringKey(command.titleKey)) { action?() }
                .keyboardShortcut(key, modifiers: eventModifiers(for: shortcut.modifiers))
                .disabled(action == nil)
        } else {
            Button(LocalizedStringKey(command.titleKey)) { action?() }
                .disabled(action == nil)
        }
    }
}

/// Translates the key from the table into the SwiftUI form. Letters are lower case, as SwiftUI expects them.
func keyEquivalent(for text: String) -> KeyEquivalent? {
    if text == "⌫" { return .delete }
    guard text.count == 1, let character = text.lowercased().first else { return nil }
    return KeyEquivalent(character)
}

func eventModifiers(for modifiers: KeyModifiers) -> EventModifiers {
    var result: EventModifiers = []
    if modifiers.contains(.control) { result.insert(.control) }
    if modifiers.contains(.option) { result.insert(.option) }
    if modifiers.contains(.shift) { result.insert(.shift) }
    if modifiers.contains(.command) { result.insert(.command) }
    return result
}
