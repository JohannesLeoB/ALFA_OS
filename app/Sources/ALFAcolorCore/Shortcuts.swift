// Shortcut table: menu commands, key shortcuts and presets as plain data.
// No SwiftUI, so that `swift test` can check the table. The menus in ALFAcolor/App/Commands/
// turn the entries into UI. All titles are keys of the string catalog (Localizable.xcstrings).
// Sources: konzept/05-OBERFLAECHE.txt sections 4 (menus) and 5 (tools);
// konzept/02-NUTZER.txt section 6 (collisions with macOS);
// konzept/09-VISION-AUSFUEHRLICH.md section 4 (tool keys).

/// A menu of the menu bar. `tool` is only in the shortcut table. The tool menu itself is built later.
public enum AppMenu: String, CaseIterable, Hashable, Sendable {
    case file, edit, object, view, window, help, tool

    /// Key of the menu title in the string catalog.
    public var titleKey: String {
        switch self {
        case .file: "menu.file"
        case .edit: "menu.edit"
        case .object: "menu.object"
        case .view: "menu.view"
        case .window: "menu.window"
        case .help: "menu.help"
        case .tool: "menu.tool"
        }
    }
}

/// Modifier keys. The display follows the macOS order ⌃⌥⇧⌘.
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    public static let control = KeyModifiers(rawValue: 1 << 0)
    public static let option = KeyModifiers(rawValue: 1 << 1)
    public static let shift = KeyModifiers(rawValue: 1 << 2)
    public static let command = KeyModifiers(rawValue: 1 << 3)
}

/// A key shortcut: modifiers and one key. Letters are stored in upper case.
public struct Shortcut: Hashable, Sendable {
    public let modifiers: KeyModifiers
    public let key: String

    public init(_ modifiers: KeyModifiers, _ key: String) {
        self.modifiers = modifiers
        self.key = key.uppercased()
    }

    /// Display as in the menu, for example "⌥⌘1" or "⇧⌘]".
    public var display: String {
        var text = ""
        if modifiers.contains(.control) { text += "⌃" }
        if modifiers.contains(.option) { text += "⌥" }
        if modifiers.contains(.shift) { text += "⇧" }
        if modifiers.contains(.command) { text += "⌘" }
        return text + key
    }
}

/// Where the key comes from: a macOS default, InDesign (from memory, not checked) or a proposal of ALFAcolor.
public enum Preset: String, Hashable, Sendable {
    case macOS, inDesign, proposal

    /// Key of the preset name in the string catalog.
    public var titleKey: String {
        switch self {
        case .macOS: "preset.macOS"
        case .inDesign: "preset.inDesign"
        case .proposal: "preset.proposal"
        }
    }
}

/// `always`: the shortcut applies everywhere. `canvasOnly`: only with focus on the canvas and without a text field.
public enum Scope: String, Hashable, Sendable {
    case always, canvasOnly
}

/// `app`: ALFAcolor creates the entry. `system`: macOS or SwiftUI provides it, and it is only in the shortcut table.
public enum Origin: String, Hashable, Sendable {
    case app, system
}

/// A menu command with its shortcut. `id` is unique and is used to match the function.
public struct MenuCommand: Identifiable, Hashable, Sendable {
    public let id: String
    public let menu: AppMenu
    public let shortcut: Shortcut?
    public let preset: Preset
    public let scope: Scope
    public let origin: Origin
    /// Key of the submenu title that the entry belongs to (for example "submenu.align"). nil for entries directly in the menu.
    public let submenuKey: String?
    /// A separator line before the entry.
    public let separatorBefore: Bool

    /// Key of the command title in the string catalog.
    public var titleKey: String { "command." + id }
}

/// A member of a menu, in display order.
public enum MenuEntry: Identifiable, Sendable {
    case separator(Int)
    case command(MenuCommand)
    case submenu(titleKey: String, commands: [MenuCommand])

    public var id: String {
        switch self {
        case .separator(let n): "separator-\(n)"
        case .command(let command): command.id
        case .submenu(let titleKey, _): "submenu-\(titleKey)"
        }
    }
}

/// The table of all commands: command to key to preset. One source for menus and shortcut table.
public enum ShortcutTable {
    public static let commands: [MenuCommand] = file + edit + view + object + window + help + tool

    /// The members of a menu. Without `origin`, all entries. Otherwise only those with this origin.
    /// Separators are never first. Entries with the same `submenuKey` are joined into one submenu.
    public static func entries(_ menu: AppMenu, origin: Origin? = nil) -> [MenuEntry] {
        var result: [MenuEntry] = []
        for command in commands where command.menu == menu && (origin == nil || command.origin == origin) {
            if command.separatorBefore && !result.isEmpty {
                result.append(.separator(result.count))
            }
            if let titleKey = command.submenuKey {
                if case .submenu(let openKey, let members)? = result.last, openKey == titleKey {
                    result[result.count - 1] = .submenu(titleKey: openKey, commands: members + [command])
                } else {
                    result.append(.submenu(titleKey: titleKey, commands: [command]))
                }
            } else {
                result.append(.command(command))
            }
        }
        return result
    }

    static let file: [MenuCommand] = [
        command("file.new", .file, "N", [.command], preset: .macOS),
        command("file.open", .file, "O", [.command], preset: .macOS),
        command("file.recent", .file),
        command("file.close", .file, "W", [.command], preset: .macOS, origin: .system, separator: true),
        command("file.save", .file, "S", [.command], preset: .macOS, separator: true),
        command("file.duplicate", .file, "S", [.command, .shift], preset: .macOS),
        command("file.rename", .file),
        command("file.move", .file),
        command("file.export", .file, "E", [.command, .shift], separator: true),
        command("file.revert", .file),
        command("file.pageSetup", .file, "P", [.command, .shift], preset: .macOS, separator: true),
        command("file.print", .file, "P", [.command], preset: .macOS),
    ]

    static let edit: [MenuCommand] = [
        command("edit.undo", .edit, "Z", [.command], preset: .macOS, origin: .system),
        command("edit.redo", .edit, "Z", [.command, .shift], preset: .macOS, origin: .system),
        command("edit.cut", .edit, "X", [.command], preset: .macOS, origin: .system, separator: true),
        command("edit.copy", .edit, "C", [.command], preset: .macOS, origin: .system),
        command("edit.paste", .edit, "V", [.command], preset: .macOS, origin: .system),
        command("edit.pasteMatchStyle", .edit, "V", [.option, .shift, .command], preset: .macOS),
        command("edit.pasteStyle", .edit, "V", [.option, .command], preset: .macOS),
        command("edit.delete", .edit, "⌫", [], preset: .macOS, scope: .canvasOnly),
        command("edit.selectAll", .edit, "A", [.command], preset: .macOS, origin: .system, separator: true),
        command("edit.deselect", .edit, "A", [.command, .shift], preset: .macOS),
        command("edit.find", .edit, "F", [.command], preset: .macOS, separator: true),
    ]

    static let view: [MenuCommand] = [
        command("view.sidebar", .view, "1", [.option, .command]),
        command("view.inspector", .view, "0", [.option, .command]),
        command("view.allPalettes", .view, separator: true),
        command("view.statusBar", .view),
        command("view.blobMode", .view),
        command("view.toolbar", .view, "T", [.option, .command], preset: .macOS, origin: .system, separator: true),
        command("view.toolOptions", .view),
        command("view.zoomIn", .view, "=", [.command], separator: true),
        command("view.zoomOut", .view, "-", [.command]),
        command("view.actualSize", .view, "1", [.command]),
        command("view.fitSelection", .view, "9", [.command]),
        command("view.fitAll", .view, "0", [.command]),
        command("view.grid", .view, "R", [.option, .command], separator: true),
        command("view.guides", .view, "L", [.option, .command]),
        command("view.snapToGrid", .view, "R", [.command, .shift]),
        command("view.fullScreen", .view, "F", [.control, .command], preset: .macOS, origin: .system, separator: true),
    ]

    static let object: [MenuCommand] = [
        command("object.group", .object, "G", [.command]),
        command("object.ungroup", .object, "G", [.command, .shift]),
        command("object.duplicate", .object, "D", [.command], preset: .inDesign),
        command("object.bringForward", .object, "]", [.command, .shift], submenu: "submenu.arrange", separator: true),
        command("object.sendBackward", .object, "[", [.command, .shift], submenu: "submenu.arrange"),
        command("object.bringToFront", .object, "]", [.option, .command, .shift], submenu: "submenu.arrange"),
        command("object.alignLeft", .object, submenu: "submenu.align", separator: true),
        command("object.alignHCenter", .object, submenu: "submenu.align"),
        command("object.alignRight", .object, submenu: "submenu.align"),
        command("object.alignTop", .object, submenu: "submenu.align"),
        command("object.alignVCenter", .object, submenu: "submenu.align"),
        command("object.alignBottom", .object, submenu: "submenu.align"),
        command("object.distributeRow", .object, submenu: "submenu.distribute", separator: true),
        command("object.distributeGrid", .object, submenu: "submenu.distribute"),
        command("object.distributePile", .object, submenu: "submenu.distribute"),
        command("object.sameSize", .object, separator: true),
        command("object.alignToGrid", .object),
        command("object.fitToFrame", .object),
    ]

    static let window: [MenuCommand] = [
        command("window.minimize", .window, "M", [.command], preset: .macOS, origin: .system),
        command("window.minimizeAll", .window, "M", [.option, .command], preset: .macOS, origin: .system),
        command("window.zoom", .window, origin: .system),
        command("window.tools", .window, "P", [.option, .command], separator: true),
        command("window.layers", .window),
        command("window.collection", .window),
        command("window.bringAllToFront", .window, origin: .system, separator: true),
        command("window.previous", .window, "`", [.command], preset: .macOS, origin: .system),
        command("window.next", .window, "`", [.command, .shift], preset: .macOS, origin: .system),
    ]

    static let help: [MenuCommand] = [
        command("help.help", .help, "?", [.command]),
        command("help.shortcutTable", .help, separator: true),
    ]

    /// Single keys of the tools (09-VISION section 4). Without the command key, so only on the canvas.
    static let tool: [MenuCommand] = [
        command("tool.select", .tool, "V", preset: .inDesign, scope: .canvasOnly),
        command("tool.directSelect", .tool, "A", preset: .inDesign, scope: .canvasOnly),
        command("tool.frame", .tool, "F", scope: .canvasOnly),
        command("tool.shape", .tool, "U", scope: .canvasOnly),
        command("tool.text", .tool, "T", scope: .canvasOnly),
        command("tool.hand", .tool, "H", preset: .inDesign, scope: .canvasOnly),
        command("tool.zoom", .tool, "Z", preset: .inDesign, scope: .canvasOnly),
        command("tool.eyedropper", .tool, "I", scope: .canvasOnly),
        command("tool.measure", .tool, "M", scope: .canvasOnly),
        command("tool.pen", .tool, "P", scope: .canvasOnly),
        command("tool.comment", .tool, "C", scope: .canvasOnly),
        command("tool.lab", .tool, "L", scope: .canvasOnly),
    ]

    /// Short form for the table. Without `key`, there is no shortcut.
    private static func command(
        _ id: String,
        _ menu: AppMenu,
        _ key: String? = nil,
        _ modifiers: KeyModifiers = [],
        preset: Preset = .proposal,
        scope: Scope = .always,
        origin: Origin = .app,
        submenu: String? = nil,
        separator: Bool = false
    ) -> MenuCommand {
        MenuCommand(
            id: id,
            menu: menu,
            shortcut: key.map { Shortcut(modifiers, $0) },
            preset: preset,
            scope: scope,
            origin: origin,
            submenuKey: submenu,
            separatorBefore: separator
        )
    }
}
