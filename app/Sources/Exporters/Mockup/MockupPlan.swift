import Foundation
import ALFAcolorCore
import Document

/// Chooses the items of a mockup package and places each one on its frame or on the free sheet.
/// Pure logic: no bytes are read here.
struct MockupPlan {
    /// One exported item and the frame it lies on (nil: the free sheet).
    struct Placed {
        let item: Item
        let frame: Item?
    }

    /// Frames in the package, in document order.
    private(set) var frames: [Item] = []
    /// Exported items, in document order.
    private(set) var placed: [Placed] = []
    /// Top left corner of the free sheet. Items without a frame are measured from here.
    private(set) var sheetOrigin: (x: Double, y: Double) = (0, 0)

    init(document: ALFAcolorDocument, scope: ExchangeScope) throws {
        var frames: [Item] = []
        var placed: [Placed] = []
        for space in document.board.spaces {
            let (pieces, picked) = Self.choose(scope, in: space)
            let spaceFrames = space.items.filter { Self.isVisible($0, in: space) && Self.isFrame($0) }
            let assigned = pieces.map { Placed(item: $0, frame: Self.topFrame(containing: $0, in: spaceFrames)) }
            let wanted = Set(assigned.compactMap { $0.frame?.id }).union(picked.map(\.id))
            frames += spaceFrames.filter { wanted.contains($0.id) }
            placed += assigned
        }
        guard !placed.isEmpty || !frames.isEmpty else { throw MockupError.nothingToExport }
        self.frames = frames
        self.placed = placed
        self.sheetOrigin = Self.origin(frames: frames, placed: placed)
    }

    /// The position of a placed item in points: relative to its frame, or to the free sheet.
    func position(of placed: Placed) -> Rect {
        let x0 = placed.frame?.rect.x ?? sheetOrigin.x
        let y0 = placed.frame?.rect.y ?? sheetOrigin.y
        return Rect(x: placed.item.rect.x - x0, y: placed.item.rect.y - y0, w: placed.item.rect.w, h: placed.item.rect.h)
    }

    /// The items and frames that the scope picks from one space.
    /// With a selection, a frame or group that is picked also picks the items whose centre lies inside it.
    private static func choose(_ scope: ExchangeScope, in space: Space) -> (pieces: [Item], frames: [Item]) {
        let visible = space.items.filter { isVisible($0, in: space) }
        let frames = visible.filter(isFrame)
        let pieces = visible.filter { !$0.isContainer }
        switch scope {
        case .document:
            return (pieces, frames)
        case .space(let id):
            return space.id == id ? (pieces, frames) : ([], [])
        case .items(let ids):
            let wanted = Set(ids)
            var chosen = Set(pieces.map(\.id).filter { wanted.contains($0) })
            for box in visible where box.isContainer && wanted.contains(box.id) {
                for piece in pieces where contains(box.rect, piece.rect) {
                    chosen.insert(piece.id)
                }
            }
            return (pieces.filter { chosen.contains($0.id) }, frames.filter { wanted.contains($0.id) })
        }
    }

    private static func isVisible(_ item: Item, in space: Space) -> Bool {
        guard !item.hidden else { return false }
        return space.layers.first { $0.id == item.layerID }?.visible ?? true
    }

    private static func isFrame(_ item: Item) -> Bool {
        if case .frame = item.content { return true }
        return false
    }

    /// The frame that contains the item's centre. With several, the one on top (highest z, then the later one).
    private static func topFrame(containing item: Item, in frames: [Item]) -> Item? {
        let centre = item.rect.center
        return frames.enumerated()
            .filter { $0.element.rect.contains(x: centre.x, y: centre.y) }
            .max { ($0.element.z, $0.offset) < ($1.element.z, $1.offset) }?
            .element
    }

    private static func contains(_ box: Rect, _ piece: Rect) -> Bool {
        let centre = piece.center
        return box.contains(x: centre.x, y: centre.y)
    }

    private static func origin(frames: [Item], placed: [Placed]) -> (x: Double, y: Double) {
        let rects = frames.map(\.rect) + placed.filter { $0.frame == nil }.map(\.item.rect)
        return (rects.map(\.x).min() ?? 0, rects.map(\.y).min() ?? 0)
    }
}
