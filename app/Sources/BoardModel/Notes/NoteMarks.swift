import Foundation
import ALFAcolorCore

/// The notes of one place on an item, shown as one mark: the notes with the same anchor, or all the notes
/// that are pinned to the item as a whole (anchor nil).
public struct NoteMarkGroup: Equatable, Identifiable, Sendable {
    public var anchor: NoteAnchor?
    /// The notes of the place, in the order of the item.
    public var notes: [ItemNote]

    public var id: String {
        anchor.map { "\($0.x),\($0.y)" } ?? "item"
    }

    /// The notes that are not resolved yet. The mark shows this number.
    public var open: Int {
        notes.filter { !$0.resolved }.count
    }
}

/// The marks that notes show on an item: which notes share a mark, and where the mark sits.
public enum NoteMarks {
    /// The groups of the notes, in the order of their first note.
    public static func groups(_ notes: [ItemNote]) -> [NoteMarkGroup] {
        var order: [NoteAnchor?] = []
        var buckets: [NoteAnchor?: [ItemNote]] = [:]
        for note in notes {
            if buckets[note.anchor] == nil { order.append(note.anchor) }
            buckets[note.anchor, default: []].append(note)
        }
        return order.map { NoteMarkGroup(anchor: $0, notes: buckets[$0] ?? []) }
    }

    /// The point of a mark on an item of this size, from the item's top left corner. A mark without an anchor
    /// sits at the top right corner of the item.
    public static func point(anchor: NoteAnchor?, width: Double, height: Double) -> (x: Double, y: Double) {
        guard let anchor else { return (width, 0) }
        return (anchor.x * width, anchor.y * height)
    }
}
