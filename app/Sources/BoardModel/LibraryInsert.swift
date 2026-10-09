import Foundation
import ALFAcolorCore

/// Puts copies of library items on the canvas. The library shows items of all rooms; a copy always lands
/// in the active room. The original stays where it is.
extension CanvasInteraction {
    /// Inserts copies of the items that `refs` name, centred on a board point, and selects them.
    /// Each copy gets a new ID and the top of the stack; a copy on a missing or locked layer goes to the first unlocked layer.
    /// Refs to items that are not in the document are skipped. One undo step, named "undo.library.insert".
    /// Returns false when nothing was inserted.
    @discardableResult
    public func insertLibraryItems(_ refs: [ItemRef], atX x: Double, y: Double) -> Bool {
        guard editing == nil, phase == .idle, x.isFinite, y.isFinite, let space = store.activeSpace else { return false }
        let found: [Item] = refs.compactMap { ref in
            store.board.spaces.first { $0.id == ref.spaceID }?.items.first { $0.id == ref.itemID }
        }
        guard let box = ResizeMath.bounds(of: found.map(\.rect)) else { return false }
        let layers = Set(space.layers.map(\.id))
        let fallback = space.layers.first(where: { !$0.locked })?.id ?? space.layers.first?.id ?? "standard"
        let dx = x - box.x - box.w / 2, dy = y - box.y - box.h / 2
        let top = space.items.map(\.z).max() ?? 0
        let copies = found.enumerated().map { index, original -> Item in
            var made = copy(of: original)
            made.rect = original.rect.translated(dx: dx, dy: dy)
            made.z = top + index + 1
            made.layerID = layers.contains(original.layerID) ? original.layerID : fallback
            return made
        }
        let changed = run(.batch([.insert(copies)], nameKey: "undo.library.insert"))
        refreshDistances()
        return changed
    }
}
