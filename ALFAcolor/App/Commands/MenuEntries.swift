import SwiftUI
import ALFAcolorCore
import BoardModel

/// What a menu entry does when triggered.
typealias MenuAction = @MainActor () -> Void

/// The functions behind the menu entries. A command without an entry here stays visible and dimmed.
struct MenuFunctions {
    var shell: ShellState?
    var canvas: CanvasController?
    var interaction: CanvasInteraction?
    var showShortcutTable: MenuAction?
    var openStarter: MenuAction?

    @MainActor
    func action(for command: MenuCommand) -> MenuAction? {
        switch command.id {
        case "view.sidebar": return with { $0.toggleSidebar() }
        case "view.inspector": return with { $0.toggleInspector() }
        case "view.allPalettes": return with { $0.togglePalettes() }
        case "view.statusBar": return with { $0.toggleStatusBar() }
        case "view.blobMode": return with { $0.toggleBlobMode() }
        case "view.rulers": return with { $0.rulersVisible.toggle() }
        case "view.guides": return with { $0.guidesVisible.toggle() }
        case "view.guidesLocked": return with { $0.guidesLocked.toggle() }
        case "view.gridShown": return withInteraction { $0.setGridShown(!$0.gridShown) }
        case "view.snapsAtAll": return withInteraction { $0.setSnapsAtAll(!$0.snapsAtAll) }
        case "view.zoomIn": return withCanvas { $0.perform(.zoomIn) }
        case "view.zoomOut": return withCanvas { $0.perform(.zoomOut) }
        case "view.actualSize": return withCanvas { $0.perform(.actualSize) }
        case "view.fitAll": return withCanvas { $0.perform(.fitAll) }
        case "view.fitSelection": return withCanvas { $0.perform(.fitSelection) }
        case "edit.deselect": return withInteraction { $0.deselect() }
        case "object.duplicate": return withInteraction { $0.duplicateSelection() }
        case "object.group": return withInteraction { $0.groupSelection(title: String(localized: "item.kind.group")) }
        case "object.ungroup": return withInteraction { $0.ungroupSelection() }
        case "object.bringForward": return withInteraction { $0.stackSelection(.forward) }
        case "object.sendBackward": return withInteraction { $0.stackSelection(.backward) }
        case "object.bringToFront": return withInteraction { $0.stackSelection(.toFront) }
        case "object.alignLeft": return arrange(.alignLeft)
        case "object.alignHCenter": return arrange(.alignCenter)
        case "object.alignRight": return arrange(.alignRight)
        case "object.alignTop": return arrange(.alignTop)
        case "object.alignVCenter": return arrange(.alignMiddle)
        case "object.alignBottom": return arrange(.alignBottom)
        case "object.distributeRow": return arrange(.row)
        case "object.distributeGrid": return arrange(.grid)
        case "object.distributePile": return arrange(.pile)
        case "object.sameSize": return arrange(.sameSize)
        case "object.alignToGrid": return arrange(.snapToGrid)
        case "file.export": return withStore { MockupExport.run(store: $0) }
        case "tool.lab":
            guard let shell, let canvas else { return nil }
            return { shell.openLab(in: canvas) }
        case "help.openStarter": return openStarter
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

    /// Runs one arrangement on the selection of the window.
    @MainActor
    private func arrange(_ how: Arrangement) -> MenuAction? {
        withInteraction { $0.arrangeSelection(how) }
    }

    /// Passes the store of the window on. Without a window, the entry stays dimmed.
    @MainActor
    private func withStore(_ perform: @escaping @MainActor (BoardStore) -> Void) -> MenuAction? {
        guard let store = interaction?.store else { return nil }
        return { perform(store) }
    }

    /// Connects a command to the selection of the window. Without a window, the entry stays dimmed.
    @MainActor
    private func withInteraction(_ perform: @escaping @MainActor (CanvasInteraction) -> Void) -> MenuAction? {
        guard let interaction else { return nil }
        return { perform(interaction) }
    }

    /// Connects a command to the canvas of the window. Without a window, the entry stays dimmed.
    @MainActor
    private func withCanvas(_ perform: @escaping @MainActor (CanvasController) -> Void) -> MenuAction? {
        guard let canvas else { return nil }
        return { perform(canvas) }
    }
}

/// The members of a menu from the shortcut table. Only entries with `origin == .app` appear.
/// What macOS provides itself stays with macOS.
struct MenuEntries: View {
    let menu: AppMenu
    let functions: MenuFunctions
    /// Commands the document scene already provides. They keep their place in the shortcut table and have no entry here.
    var hiding: Set<String> = []

    var body: some View {
        ForEach(visibleEntries) { entry in
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

extension MenuEntries {
    private func isHidden(_ entry: MenuEntry) -> Bool {
        if case .command(let command) = entry { return hiding.contains(command.id) }
        return false
    }

    /// The entries that stay. A separator never starts or ends the menu and never doubles, even after entries were hidden.
    private var visibleEntries: [MenuEntry] {
        var result: [MenuEntry] = []
        for entry in ShortcutTable.entries(menu, origin: .app) where !isHidden(entry) {
            if case .separator = entry, result.last.map(Self.isSeparator) ?? true { continue }
            result.append(entry)
        }
        if let last = result.last, Self.isSeparator(last) { result.removeLast() }
        return result
    }

    private static func isSeparator(_ entry: MenuEntry) -> Bool {
        if case .separator = entry { return true }
        return false
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
    if text == "↑" { return .upArrow }
    if text == "↓" { return .downArrow }
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
