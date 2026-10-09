import Foundation
import ALFAcolorCore

/// The keyboard: nudge, select all, deselect, delete, duplicate and Escape.
extension CanvasInteraction {
    /// How far a copy made by the menu lies from the original, in board points.
    public static let duplicateOffset = 16.0

    /// Moves the selection by one step. Shift makes the step larger. One press is one undo step.
    @discardableResult
    public func nudge(_ arrow: Arrow, large: Bool) -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        let step = Arrow.distance(large: large), direction = arrow.direction
        let changed = run(.move(store.selection, dx: direction.x * step, dy: direction.y * step))
        refreshDistances()
        return changed
    }

    /// Selects every item that can be seen.
    public func selectAll() {
        guard editing == nil, phase == .idle else { return }
        store.select(Set(visibleItems.map(\.id)))
        refreshDistances()
    }

    public func deselect() {
        guard phase == .idle else { return }
        store.clearSelection()
        refreshDistances()
    }

    /// Deletes the selection. Undo brings it back. Items inside a deleted frame or group stay.
    @discardableResult
    public func deleteSelection() -> Bool {
        guard editing == nil, phase == .idle, !store.selection.isEmpty else { return false }
        let changed = run(.delete(store.selection))
        refreshDistances()
        return changed
    }

    /// Puts a copy of the selection next to the selection and selects the copy.
    @discardableResult
    public func duplicateSelection(offset: Double = CanvasInteraction.duplicateOffset) -> Bool {
        guard editing == nil, phase == .idle, offset.isFinite else { return false }
        let copies = movingItems(of: store.selection).map { item -> Item in
            var made = copy(of: item)
            made.rect = item.rect.translated(dx: offset, dy: offset)
            return made
        }
        guard !copies.isEmpty else { return false }
        let changed = run(.batch([.insert(copies)], nameKey: "undo.duplicate"))
        refreshDistances()
        return changed
    }

    /// The Escape key. It ends a text edit, or stops a drag, or else clears the selection.
    /// Returns true when it did something.
    @discardableResult
    public func escape() -> Bool {
        if measuring {
            measuring = false
            return true
        }
        if editing != nil {
            commitEdit()
            return true
        }
        if phase != .idle {
            cancelGesture()
            return true
        }
        guard !store.selection.isEmpty else { return false }
        deselect()
        return true
    }
}
