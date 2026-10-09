import Foundation
import ALFAcolorCore

/// Copy, cut and paste of pieces. The pieces stay in the window. The system pasteboard carries `clipboardMark`,
/// so a paste can tell its own pieces from other content.
extension CanvasInteraction {
    /// Puts the selection on the clipboard. Returns the mark for the system pasteboard, nil when nothing can be copied.
    @discardableResult
    public func copySelection() -> String? {
        guard editing == nil, phase == .idle else { return nil }
        let pieces = movingItems(of: store.selection)
        guard !pieces.isEmpty else { return nil }
        clipboard = pieces
        clipboardMark = "alfacolor-pieces:" + UUID().uuidString
        return clipboardMark
    }

    /// Copies the selection and deletes it. One undo step takes the pieces back.
    @discardableResult
    public func cutSelection() -> String? {
        guard let mark = copySelection() else { return nil }
        deleteSelection()
        return mark
    }

    /// Pastes the clipboard as new pieces, centred on a board point, and selects them. Pieces on a layer that
    /// the space does not have go to its first unlocked layer. One undo step.
    @discardableResult
    public func pasteClipboard(atX x: Double, y: Double) -> Bool {
        guard editing == nil, phase == .idle, !clipboard.isEmpty, x.isFinite, y.isFinite,
              let space = store.activeSpace, let box = ResizeMath.bounds(of: clipboard.map(\.rect)) else { return false }
        let layers = Set(space.layers.map(\.id))
        let fallback = space.layers.first(where: { !$0.locked })?.id ?? space.layers.first?.id ?? "standard"
        let dx = x - box.x - box.w / 2, dy = y - box.y - box.h / 2
        let top = space.items.map(\.z).max() ?? 0
        let pieces = clipboard.enumerated().map { index, piece -> Item in
            var made = copy(of: piece)
            made.rect = piece.rect.translated(dx: dx, dy: dy)
            made.z = top + index + 1
            made.layerID = layers.contains(piece.layerID) ? piece.layerID : fallback
            return made
        }
        let changed = run(.batch([.insert(pieces)], nameKey: "undo.paste"))
        refreshDistances()
        return changed
    }

    /// Asks the canvas to show the file chooser. The chosen files are placed like a paste.
    public func requestFileImport() {
        importRequest += 1
    }
}
