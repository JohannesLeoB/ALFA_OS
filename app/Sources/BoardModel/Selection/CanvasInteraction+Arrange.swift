import Foundation
import ALFAcolorCore

/// Actions on the selection that the menus and the toolbar run: arranging, stacking and grouping.
/// Each call is one undo step. Nothing happens while a text is edited or a gesture runs.
extension CanvasInteraction {
    /// Aligns, spreads or sizes the selection.
    @discardableResult
    public func arrangeSelection(_ how: Arrangement) -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        let changed = run(.arrange(how, store.selection))
        refreshDistances()
        return changed
    }

    /// Moves the selection one step or all the way in the paint order of each layer.
    @discardableResult
    public func stackSelection(_ how: StackMove) -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        return run(.reorder(store.selection, how))
    }

    /// Puts the selection into a new group. The group takes the title and the ID it is given.
    @discardableResult
    public func groupSelection(title: String, groupID: ItemID = ItemID()) -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        let changed = run(.group(store.selection, title: title, groupID: groupID))
        refreshDistances()
        return changed
    }

    /// Removes the groups in the selection. Their items stay and are selected.
    @discardableResult
    public func ungroupSelection() -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        let changed = run(.ungroup(store.selection))
        refreshDistances()
        return changed
    }
}
