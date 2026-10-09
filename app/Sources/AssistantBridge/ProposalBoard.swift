import Foundation
import ALFAcolorCore
import AI
import BoardModel

/// Applies accepted assistant proposals to the board of the app with the app's commands.
@MainActor
public enum ProposalBoard {
    /// Applies the changes in order and returns one outcome per change, in the same order.
    /// A change that fails does not stop the others. All changes of the call are one undo step: the
    /// store's own steps nest in one undo group, so a single undo takes back every change of the call.
    public static func apply(_ changes: [ProposedChange], to store: BoardStore) -> [ApplyOutcome] {
        guard !changes.isEmpty else { return [] }
        let manager = store.undoManager
        let revision = store.revision
        // A unique name marks the group when nothing changed: a group that stays empty is taken back again.
        let marker = UUID().uuidString
        manager.beginUndoGrouping()
        let outcomes = changes.map { translate($0, on: store) }
        let changed = store.revision != revision
        manager.setActionName(changed ? (Command.batch([]).undoName ?? "") : marker)
        manager.endUndoGrouping()
        if !changed, manager.undoActionName == marker {
            manager.undo()
        }
        return outcomes
    }

    static func translate(_ change: ProposedChange, on store: BoardStore) -> ApplyOutcome {
        do {
            switch change {
            case let .note(item, text):
                return try addNote(text, to: item, on: store)
            case let .tip(kind, text, item):
                switch kind {
                case .note:
                    guard let item else { return .failed("the note tip has no item") }
                    return try addNote(text, to: item, on: store)
                case .chat, .lab:
                    // A chat or lab tip shows in the chat or the lab and changes no document.
                    return .applied
                }
            case let .tags(item, tags):
                return try addTags(tags, to: item, on: store)
            case let .noteCard(text):
                let item = Item(title: String(text.prefix(40)), content: .note(text: text), rect: Rect(x: 0, y: 0, w: 240, h: 160))
                return try insert(item, size: (240, 160), on: store)
            case let .codeCard(title, language, files):
                guard let lang = CodeLanguage(rawValue: language) else { return .failed("unknown code language") }
                let item = Item(title: title, content: .code(language: lang, files: files, previewWidth: nil), rect: Rect(x: 0, y: 0, w: 480, h: 320))
                return try insert(item, size: (480, 320), on: store)
            case let .codeVersion(item, language, files):
                return try addCodeVersion(item, language: language, files: files, on: store)
            case let .delete(items, scope):
                return try delete(items, scope: scope, on: store)
            case let .move(items, dx, dy):
                return try move(items, dx: dx, dy: dy, on: store)
            case let .swatches(swatches):
                return try addSwatches(swatches, on: store)
            case let .tokenNames(names):
                return try nameTokens(names, on: store)
            case .designTokens:
                return .failed("the design contract is not part of the document")
            case .download:
                return .failed("downloads are not connected yet")
            case let .link(url, title):
                guard let address = URL(string: url) else { return .failed("the address is not valid") }
                let item = Item(title: title, content: .link(url: address, note: nil), rect: Rect(x: 0, y: 0, w: 240, h: 80),
                                source: Source(url: address, via: "assistant"))
                return try insert(item, size: (240, 80), on: store)
            default:
                return .failed("not translated yet")
            }
        } catch {
            return .failed(reason(for: error))
        }
    }

    // MARK: Changes

    private static func addNote(_ text: String, to item: String, on store: BoardStore) throws -> ApplyOutcome {
        let note = ItemNote(text: text, author: .assistant, createdAt: Date())
        let changed = try store.perform(noteAdd: note, to: [ItemID(item)])
        return changed ? .applied : .failed("nothing changed")
    }

    /// Adds the tags the item does not have yet. There is no tag command in the app, so the field changes in one board change.
    private static func addTags(_ tags: [String], to item: String, on store: BoardStore) throws -> ApplyOutcome {
        guard let spaceID = store.activeSpaceID else { throw CommandError.noActiveSpace }
        let itemID = ItemID(item)
        let changed = try store.changeBoard(nameKey: "undo.batch") { board in
            guard let s = board.spaces.firstIndex(where: { $0.id == spaceID }),
                  let i = board.spaces[s].items.firstIndex(where: { $0.id == itemID }) else {
                throw CommandError.unknownItem(itemID)
            }
            let layerLocked = board.spaces[s].layers.first { $0.id == board.spaces[s].items[i].layerID }?.locked ?? false
            guard !board.spaces[s].items[i].locked, !layerLocked else { throw BridgeError.itemLocked }
            for tag in tags where !board.spaces[s].items[i].tags.contains(tag) {
                board.spaces[s].items[i].tags.append(tag)
            }
        }
        return changed ? .applied : .failed("nothing changed")
    }

    /// Removes the items as one board change. The scope decides where to look: the active room, or every room.
    /// An item that is not found in the scope refuses the whole change, and nothing is removed.
    private static func delete(_ items: [String], scope: ChangeScope, on store: BoardStore) throws -> ApplyOutcome {
        let ids = items.map { ItemID($0) }
        let spaces = try rooms(holding: ids, scope: scope, on: store)
        let changed = try store.changeBoard(nameKey: "undo.delete") { board in
            for spaceID in spaces {
                guard let s = board.spaces.firstIndex(where: { $0.id == spaceID }) else { continue }
                let present = Set(ids.filter { id in board.spaces[s].items.contains { $0.id == id } })
                _ = try Command.delete(present).apply(to: &board, spaceID: spaceID)
            }
        }
        return changed ? .applied : .failed("nothing changed")
    }

    /// Moves the items of the active room by a distance. A move has no scope of its own: it reaches the active room only.
    private static func move(_ items: [String], dx: Double, dy: Double, on store: BoardStore) throws -> ApplyOutcome {
        let ids = items.map { ItemID($0) }
        _ = try rooms(holding: ids, scope: .room, on: store)
        return try store.perform(.move(Set(ids), dx: dx, dy: dy)) ? .applied : .failed("nothing changed")
    }

    /// The rooms that the scope reaches, after checking that every item is in them.
    /// An item that exists only in another room is refused as not in the current room; an item that exists nowhere is unknown.
    private static func rooms(holding ids: [ItemID], scope: ChangeScope, on store: BoardStore) throws -> [String] {
        let reached = scope == .room ? (store.activeSpace.map { [$0] } ?? []) : store.board.spaces
        for id in ids where !reached.contains(where: { space in space.items.contains { $0.id == id } }) {
            let elsewhere = store.board.spaces.contains { space in space.items.contains { $0.id == id } }
            throw elsewhere ? BridgeError.notInRoom : BridgeError.unknownItem
        }
        return reached.map(\.id)
    }

    /// Adds the colour fields as one token change. An unnamed field gets the lowest free name "Color n".
    private static func addSwatches(_ swatches: [Swatch], on store: BoardStore) throws -> ApplyOutcome {
        let changed = try store.changeTokenSets(nameKey: "undo.color.add") { sets in
            for swatch in swatches {
                let color = try ColorFields.color(hex: swatch.hex)
                let name = swatch.name ?? ColorFields.freeName(base: "Color", in: sets)
                _ = try ColorFields.add(name: name, color: color, to: &sets)
            }
        }
        return changed ? .applied : .failed("nothing changed")
    }

    /// Gives colour fields their new names as one token change.
    private static func nameTokens(_ names: [TokenName], on store: BoardStore) throws -> ApplyOutcome {
        let changed = try store.changeTokenSets(nameKey: "undo.color.rename") { sets in
            for entry in names {
                try ColorFields.rename(entry.id, to: entry.name, in: &sets)
            }
        }
        return changed ? .applied : .failed("nothing changed")
    }

    /// Puts a new item to the right of the room, on the top of the stack, on the first unlocked layer.
    private static func insert(_ item: Item, size: (w: Double, h: Double), on store: BoardStore) throws -> ApplyOutcome {
        guard let space = store.activeSpace else { throw CommandError.noActiveSpace }
        let right = space.items.map { $0.rect.maxX }.max() ?? 0
        let top = space.items.map(\.z).max() ?? 0
        let layerID = space.layers.first { !$0.locked }?.id ?? space.layers.first?.id ?? "standard"
        var placed = item
        placed.rect = Rect(x: right + 48, y: 0, w: size.w, h: size.h)
        placed.z = top + 1
        placed.layerID = layerID
        return try store.perform(.insert([placed])) ? .applied : .failed("nothing changed")
    }

    /// Keeps the code the card has now as a version, then sets the new code. The preview width stays.
    private static func addCodeVersion(_ item: String, language: String, files: [String: String], on store: BoardStore) throws -> ApplyOutcome {
        guard let lang = CodeLanguage(rawValue: language) else { return .failed("unknown code language") }
        let id = ItemID(item)
        guard let space = store.activeSpace, let card = space.items.first(where: { $0.id == id }) else {
            throw CommandError.unknownItem(id)
        }
        let layerLocked = space.layers.first { $0.id == card.layerID }?.locked ?? false
        guard !card.locked, !layerLocked else { throw BridgeError.itemLocked }
        guard case let .code(_, _, width) = card.content else { throw VersionError.notCode(id) }
        _ = try store.keepVersion(of: id)
        let changed = try store.perform(.setContent(id, .code(language: lang, files: files, previewWidth: width)))
        return changed ? .applied : .failed("nothing changed")
    }

    // MARK: Reasons

    /// The reason that is shown when a change is not applied.
    static func reason(for error: Error) -> String {
        if let error = error as? BridgeError { return error.reason }
        if let error = error as? CommandError, case .unknownItem = error { return "the item is not in the current room" }
        if let error = error as? NoteError, error == .tooManyNotes { return "the item has too many notes" }
        if let error = error as? VersionError, case .notCode = error { return "the item is not a code card" }
        return String(describing: error)
    }
}

/// A refusal of the bridge itself, before any command runs.
enum BridgeError: Error, Equatable {
    case itemLocked
    case notInRoom
    case unknownItem

    var reason: String {
        switch self {
        case .itemLocked: "the item is locked"
        case .notInRoom: "the item is not in the current room"
        case .unknownItem: "the item does not exist"
        }
    }
}
