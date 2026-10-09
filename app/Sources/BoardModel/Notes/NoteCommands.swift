import Foundation
import ALFAcolorCore

/// Why a note could not be changed. The board is unchanged in each case.
public enum NoteError: Error, Equatable, Sendable {
    /// The item already has `ItemNote.maxPerItem` notes.
    case tooManyNotes
    /// The text is empty after the spaces at its ends are removed.
    case emptyText
    /// No note with this ID is on the item.
    case unknownNote(UUID)
}

/// Commands for the notes of items. Each one is one undo step, named by its undo key in the string catalog.
/// The notes of an item are changed on a copy of the board, so a refused command changes nothing.
extension BoardStore {
    /// Adds a copy of the note to each item in `itemIDs`, in the active space. The copies keep the ID of `note`;
    /// IDs are unique within one item only.
    /// A note with an empty text adds nothing and returns false. Refused, with no change, when an item would
    /// go beyond `ItemNote.maxPerItem`. Returns false when nothing changed.
    @discardableResult
    public func perform(noteAdd note: ItemNote, to itemIDs: [ItemID]) throws -> Bool {
        let text = Self.noteText(note.text)
        guard !text.isEmpty, !itemIDs.isEmpty else { return false }
        return try changeNotes(of: itemIDs, nameKey: "undo.note.add") { notes in
            guard notes.count < ItemNote.maxPerItem else { throw NoteError.tooManyNotes }
            var copy = note
            copy.text = text
            notes.append(copy)
        }
    }

    /// Replaces the text of one note. The text is trimmed and cut to the text limit. An empty text is refused.
    @discardableResult
    public func perform(noteEdit noteID: UUID, text: String, on itemID: ItemID) throws -> Bool {
        let clean = Self.noteText(text)
        guard !clean.isEmpty else { throw NoteError.emptyText }
        return try changeNotes(of: [itemID], nameKey: "undo.note.edit") { notes in
            let index = try Self.index(of: noteID, in: notes)
            notes[index].text = clean
        }
    }

    /// Marks one note as done (`resolved` true) or open again (false). Returns false when it already has that state.
    @discardableResult
    public func perform(noteResolve noteID: UUID, resolved: Bool, on itemID: ItemID) throws -> Bool {
        try changeNotes(of: [itemID], nameKey: resolved ? "undo.note.resolve" : "undo.note.reopen") { notes in
            let index = try Self.index(of: noteID, in: notes)
            notes[index].resolved = resolved
        }
    }

    /// Removes one note. Undo puts it back in its place in the list.
    @discardableResult
    public func perform(noteDelete noteID: UUID, on itemID: ItemID) throws -> Bool {
        try changeNotes(of: [itemID], nameKey: "undo.note.delete") { notes in
            notes.remove(at: try Self.index(of: noteID, in: notes))
        }
    }

    // MARK: Helpers

    /// The text of a note: the spaces and line ends at its ends removed, and cut to the text limit.
    static func noteText(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return String(trimmed.prefix(ItemNote.maxTextLength))
    }

    private static func index(of noteID: UUID, in notes: [ItemNote]) throws -> Int {
        guard let index = notes.firstIndex(where: { $0.id == noteID }) else { throw NoteError.unknownNote(noteID) }
        return index
    }

    /// Changes the notes of the given items of the active space as one undo step named by `nameKey`.
    /// Returns false when no note changed.
    private func changeNotes(of itemIDs: [ItemID], nameKey: String, _ change: (inout [ItemNote]) throws -> Void) throws -> Bool {
        guard let spaceID = activeSpaceID else { throw CommandError.noActiveSpace }
        return try changeBoard(nameKey: nameKey) { board in
            guard let spaceIndex = board.spaces.firstIndex(where: { $0.id == spaceID }) else {
                throw CommandError.unknownSpace(spaceID)
            }
            for itemID in itemIDs {
                guard let itemIndex = board.spaces[spaceIndex].items.firstIndex(where: { $0.id == itemID }) else {
                    throw CommandError.unknownItem(itemID)
                }
                var notes = board.spaces[spaceIndex].items[itemIndex].notes
                try change(&notes)
                board.spaces[spaceIndex].items[itemIndex].notes = notes
            }
        }
    }
}
