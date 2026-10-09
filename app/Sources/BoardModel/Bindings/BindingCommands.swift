import Foundation
import ALFAcolorCore
import Tokens

/// Commands for colour bindings and colour fields that touch items. Each one is one undo step.
extension BoardStore {
    /// Binds a slot of the items to the colour field `name`. The stored value takes the colour of the field.
    /// Items without the slot and locked items are skipped. Returns false when nothing changed.
    @discardableResult
    public func bindColor(_ ids: Set<ItemID>, slot: ColorBinding.Slot, to name: String) throws -> Bool {
        guard let field = ColorFields.fields(in: document.tokenSets).first(where: { $0.name == name }) else {
            throw ColorFields.Failure.unknownField(name)
        }
        return try changeActiveItems(ids, nameKey: "undo.binding.bind") { item in
            ColorBinding.bound(item, slot: slot, name: name, color: field.color)
        }
    }

    /// Releases a slot. It keeps its stored value and no longer follows the field. Returns false when nothing changed.
    @discardableResult
    public func releaseColor(_ ids: Set<ItemID>, slot: ColorBinding.Slot) throws -> Bool {
        try changeActiveItems(ids, nameKey: "undo.binding.release") { ColorBinding.released($0, slot: slot) }
    }

    /// Gives a colour field another name and moves every binding to the new name, in one undo step.
    /// Throws, and changes nothing, when the name is refused.
    @discardableResult
    public func renameColorField(_ old: String, to new: String) throws -> Bool {
        let manager = undoManager
        manager.beginUndoGrouping()
        defer { manager.endUndoGrouping() }
        let renamed = try changeTokenSets(nameKey: "undo.color.rename") { try ColorFields.rename(old, to: new, in: &$0) }
        let name = new.trimmingCharacters(in: .whitespacesAndNewlines)
        let moved = try changeBoard(nameKey: "undo.color.rename") { board in
            for space in board.spaces.indices {
                for index in board.spaces[space].items.indices {
                    if let next = ColorBinding.renamed(board.spaces[space].items[index], from: old, to: name) {
                        board.spaces[space].items[index] = next
                    }
                }
            }
        }
        return renamed || moved
    }

    /// Changes the colour of a field. Bound items store the new colour as their last known value, in the same undo step.
    @discardableResult
    public func setColorField(_ name: String, to color: RGB) throws -> Bool {
        let manager = undoManager
        manager.beginUndoGrouping()
        defer { manager.endUndoGrouping() }
        let changed = try changeTokenSets(nameKey: "undo.color.value") { try ColorFields.setColor(name, to: color, in: &$0) }
        let moved = try changeBoard(nameKey: "undo.color.value") { board in
            for space in board.spaces.indices {
                for index in board.spaces[space].items.indices {
                    if let next = ColorBinding.refreshed(board.spaces[space].items[index], field: name, color: color) {
                        board.spaces[space].items[index] = next
                    }
                }
            }
        }
        return changed || moved
    }

    /// Changes the items with these IDs in the active room. Locked items and items on locked layers are skipped.
    private func changeActiveItems(_ ids: Set<ItemID>, nameKey: String, _ change: (Item) -> Item?) throws -> Bool {
        guard let spaceID = activeSpaceID else { return false }
        return try changeBoard(nameKey: nameKey) { board in
            guard let space = board.spaces.firstIndex(where: { $0.id == spaceID }) else { return }
            let lockedLayers = Set(board.spaces[space].layers.filter(\.locked).map(\.id))
            for index in board.spaces[space].items.indices {
                let item = board.spaces[space].items[index]
                guard ids.contains(item.id), !item.locked, !lockedLayers.contains(item.layerID), let next = change(item) else { continue }
                board.spaces[space].items[index] = next
            }
        }
    }
}
