import Foundation
import ALFAcolorCore
import AI
import BoardModel

/// Applies accepted assistant proposals to the board of the app with the app's commands.
@MainActor
public enum ProposalBoard {
    /// Applies the changes in order and returns one outcome per change, in the same order.
    /// A change that fails does not stop the others.
    public static func apply(_ changes: [ProposedChange], to store: BoardStore) -> [ApplyOutcome] {
        changes.map { translate($0, on: store) }
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

    // MARK: Reasons

    /// The reason that is shown when a change is not applied.
    static func reason(for error: Error) -> String {
        if let error = error as? BridgeError { return error.reason }
        if let error = error as? CommandError, case .unknownItem = error { return "the item is not in the current room" }
        if let error = error as? NoteError, error == .tooManyNotes { return "the item has too many notes" }
        return String(describing: error)
    }
}

/// A refusal of the bridge itself, before any command runs.
enum BridgeError: Error, Equatable {
    case itemLocked

    var reason: String {
        switch self {
        case .itemLocked: "the item is locked"
        }
    }
}
