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
        /// Shifts an item on the free sheet, so that the items of different spaces lie side by side.
        var offset: (x: Double, y: Double) = (0, 0)
    }

    /// Frames in the package, in document order.
    private(set) var frames: [Item] = []
    /// Exported items, in document order.
    private(set) var placed: [Placed] = []
    /// Top left corner of the free sheet. Items without a frame are measured from here.
    private(set) var sheetOrigin: (x: Double, y: Double) = (0, 0)

    /// Space between the free items of two spaces on the sheet, in points.
    private static let sheetGap = 32.0

    init(document: ALFAcolorDocument, scope: ExchangeScope) throws {
        var frames: [Item] = []
        var groups: [[Placed]] = []
        for space in document.board.spaces {
            let (pieces, picked) = Self.choose(scope, in: space)
            let spaceFrames = space.items.filter { Self.isVisible($0, in: space) && Self.isFrame($0) }
            // Canvas order: layer by layer, and by z inside a layer.
            let rank = { (item: Item) in space.layers.firstIndex { $0.id == item.layerID } ?? 0 }
            let ordered = pieces.sorted { (rank($0), $0.z) < (rank($1), $1.z) }
            let assigned = ordered.map { Placed(item: $0, frame: Self.topFrame(containing: $0, in: spaceFrames)) }
            let wanted = Set(assigned.compactMap { $0.frame?.id }).union(picked.map(\.id))
            frames += spaceFrames.filter { wanted.contains($0.id) }
            groups.append(assigned)
        }
        guard groups.contains(where: { !$0.isEmpty }) || !frames.isEmpty else { throw MockupError.nothingToExport }
        self.frames = frames
        let origin = Self.sheetOrigin(of: groups.flatMap { $0 }.filter { $0.frame == nil }.map(\.item.rect))
        self.sheetOrigin = origin
        self.placed = Self.sideBySide(groups, origin: origin.x)
    }

    /// The position of a placed item in points: relative to its frame, or to the free sheet.
    func position(of placed: Placed) -> Rect {
        let rect = placed.item.rect
        guard let frame = placed.frame else {
            return Rect(x: rect.x + placed.offset.x - sheetOrigin.x, y: rect.y + placed.offset.y - sheetOrigin.y, w: rect.w, h: rect.h)
        }
        return Rect(x: rect.x - frame.rect.x, y: rect.y - frame.rect.y, w: rect.w, h: rect.h)
    }

    /// Puts the free items of each space in a row, so that they do not lie on each other.
    private static func sideBySide(_ groups: [[Placed]], origin: Double) -> [Placed] {
        var cursor = origin
        var out: [Placed] = []
        for group in groups {
            let free = group.filter { $0.frame == nil }
            if let left = free.map(\.item.rect.x).min(), let right = free.map(\.item.rect.maxX).max() {
                let shift = cursor - left
                out += group.map { placed in
                    guard placed.frame == nil else { return placed }
                    return Placed(item: placed.item, frame: nil, offset: (shift, 0))
                }
                cursor += right - left + sheetGap
            } else {
                out += group
            }
        }
        return out
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

    /// The top left corner of the free items. The frames do not count: they are not on the sheet.
    private static func sheetOrigin(of rects: [Rect]) -> (x: Double, y: Double) {
        (rects.map(\.x).min() ?? 0, rects.map(\.y).min() ?? 0)
    }
}
