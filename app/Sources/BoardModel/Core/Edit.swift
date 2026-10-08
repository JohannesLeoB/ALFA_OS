import Foundation
import ALFAcolorCore

/// An item and its position in the item list of a space.
public struct IndexedItem: Hashable, Sendable {
    public var index: Int
    public var item: Item
    public init(index: Int, item: Item) { self.index = index; self.item = item }
}

/// The change of a set of items: how they were before and how they are after.
/// An item that is only in `before` was removed. An item that is only in `after` was added.
/// All other items of the space keep their order.
public struct ItemDelta: Hashable, Sendable {
    /// Sorted by index, indexes are positions in the list before the change.
    public var before: [IndexedItem]
    /// Sorted by index, indexes are positions in the list after the change.
    public var after: [IndexedItem]

    public init(before: [IndexedItem], after: [IndexedItem]) { self.before = before; self.after = after }

    public var isEmpty: Bool { before == after }
    public var reversed: ItemDelta { ItemDelta(before: after, after: before) }

    /// Replaces the items of `before` with the items of `after`. The list must be in the state before the change.
    func apply(to items: inout [Item]) {
        let gone = Set(before.map(\.item.id))
        let rest = items.filter { !gone.contains($0.id) }
        var merged: [Item] = []
        merged.reserveCapacity(rest.count + after.count)
        var next = 0
        var pending = 0
        while next < rest.count || pending < after.count {
            if pending < after.count, after[pending].index <= merged.count || next >= rest.count {
                merged.append(after[pending].item)
                pending += 1
            } else {
                merged.append(rest[next])
                next += 1
            }
        }
        items = merged
    }

    /// The items with these IDs and their positions.
    static func entries(of ids: Set<ItemID>, in items: [Item]) -> [IndexedItem] {
        var out: [IndexedItem] = []
        for (index, item) in items.enumerated() where ids.contains(item.id) {
            out.append(IndexedItem(index: index, item: item))
        }
        return out
    }
}

/// What a command did to a space: the record that undoes it, and that applies it again.
/// An edit is a value. `reversed` is the inverse command.
public struct Edit: Hashable, Sendable {
    public var spaceID: String
    /// The changes in the order in which they were made. A batch has more than one.
    public var steps: [ItemDelta]
    public var selectionBefore: Set<ItemID>
    public var selectionAfter: Set<ItemID>

    public init(spaceID: String, steps: [ItemDelta], selectionBefore: Set<ItemID>, selectionAfter: Set<ItemID>) {
        self.spaceID = spaceID; self.steps = steps; self.selectionBefore = selectionBefore; self.selectionAfter = selectionAfter
    }

    /// An edit without any change to an item changes nothing in the document.
    public var changesItems: Bool { steps.contains { !$0.isEmpty } }

    public var reversed: Edit {
        Edit(spaceID: spaceID, steps: steps.reversed().map(\.reversed), selectionBefore: selectionAfter, selectionAfter: selectionBefore)
    }

    /// Applies the edit. The space must be in the state in which the edit was made (or, for a reversed edit, after it).
    /// Returns false when the space does not exist.
    @discardableResult
    public func apply(to board: inout Board) -> Bool {
        guard let index = board.spaces.firstIndex(where: { $0.id == spaceID }) else { return false }
        for step in steps { step.apply(to: &board.spaces[index].items) }
        return true
    }
}
