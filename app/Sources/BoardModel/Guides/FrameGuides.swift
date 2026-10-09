import Foundation
import ALFAcolorCore

/// Guides of frames: add, move and remove. A guide lies inside its frame and is measured from the top
/// left corner of the frame, so it moves and scales with the frame. Each command is one undo step.
public enum FrameGuides {
    /// The guides of an item, in the order they were added. Empty for items that are no frame.
    public static func guides(of item: Item) -> [Guide] {
        guard case .frame(_, _, _, _, let guides) = item.content else { return [] }
        return guides ?? []
    }

    /// True when the guide lies on the frame: its position is finite and runs from the corner to the far edge.
    public static func isValid(_ guide: Guide, in rect: Rect) -> Bool {
        guard rect.isFinite, guide.position.isFinite else { return false }
        let extent = guide.axis == .horizontal ? rect.h : rect.w
        return (0...extent).contains(guide.position)
    }

    /// Adds a guide to a frame. Empty when the item is no frame or the guide does not lie on it.
    public static func add(_ guide: Guide, to item: Item) -> [Command] {
        guard isValid(guide, in: item.rect) else { return [] }
        return replace(guides(of: item) + [guide], on: item)
    }

    /// Moves the guide at the index to a new position. Empty for an unknown index, an invalid position,
    /// or when the guide already has that position.
    public static func move(_ item: Item, at index: Int, to position: Double) -> [Command] {
        var list = guides(of: item)
        guard list.indices.contains(index) else { return [] }
        var moved = list[index]
        moved.position = position
        guard isValid(moved, in: item.rect), moved != list[index] else { return [] }
        list[index] = moved
        return replace(list, on: item)
    }

    /// Removes the guide at the index. Empty for an unknown index.
    public static func remove(_ item: Item, at index: Int) -> [Command] {
        var list = guides(of: item)
        guard list.indices.contains(index) else { return [] }
        list.remove(at: index)
        return replace(list, on: item)
    }

    /// Removes all guides of a frame. Empty when it has none.
    public static func removeAll(from item: Item) -> [Command] {
        guard !guides(of: item).isEmpty else { return [] }
        return replace([], on: item)
    }

    /// The guides after a quarter turn of a frame of `width` by `height`, in the order given. A clockwise turn
    /// maps a vertical guide at x to a horizontal one at y = x, and a horizontal guide at y to a vertical one at
    /// x = height - y. A counterclockwise turn maps a horizontal guide at y to a vertical one at x = y, and a
    /// vertical guide at x to a horizontal one at y = width - x. Both keep every valid guide valid.
    public static func turned(_ guides: [Guide], width: Double, height: Double, clockwise: Bool) -> [Guide] {
        guides.map { guide in
            switch (guide.axis, clockwise) {
            case (.vertical, true): Guide(axis: .horizontal, position: guide.position)
            case (.horizontal, true): Guide(axis: .vertical, position: height - guide.position)
            case (.vertical, false): Guide(axis: .horizontal, position: width - guide.position)
            case (.horizontal, false): Guide(axis: .vertical, position: guide.position)
            }
        }
    }

    /// The lines of the guides of the frames that hold the rectangle completely, on the board.
    /// `items` are the items that can be targets. Frames that do not hold the rectangle give no lines.
    public static func snapLines(around rect: Rect?, in items: [Item]) -> [SnapGuide] {
        guard let rect, rect.isFinite else { return [] }
        return items.flatMap { item -> [SnapGuide] in
            let frame = item.rect
            let holds = frame.x <= rect.x && rect.maxX <= frame.maxX && frame.y <= rect.y && rect.maxY <= frame.maxY
            guard holds, frame.isFinite else { return [] }
            return guides(of: item).filter { isValid($0, in: frame) }.map { guide in
                switch guide.axis {
                case .horizontal:
                    SnapGuide(axis: .horizontal, position: frame.y + guide.position, span: frame.x...frame.maxX)
                case .vertical:
                    SnapGuide(axis: .vertical, position: frame.x + guide.position, span: frame.y...frame.maxY)
                }
            }
        }
    }

    /// Where a guide dropped at a point of the board goes: the topmost visible frame that holds the point, and the
    /// guide in that frame. nil when no frame holds the point; a guide is never made without a frame.
    /// Frames on a hidden layer or hidden themselves take no guide.
    public static func drop(axis: GuideAxis, at x: Double, _ y: Double, in space: Space?) -> GuideDrop? {
        guard x.isFinite, y.isFinite else { return nil }
        let items = space?.visibleItems ?? []
        let holding = items.enumerated().filter { _, item in
            if case .frame = item.content { return item.rect.isFinite && item.rect.contains(x: x, y: y) }
            return false
        }
        guard let top = holding.max(by: { ($0.element.z, $0.offset) < ($1.element.z, $1.offset) })?.element else { return nil }
        let position = axis == .horizontal ? y - top.rect.y : x - top.rect.x
        return GuideDrop(frame: top.id, guide: Guide(axis: axis, position: position))
    }

    /// The command that sets the guides of a frame. An empty list is stored as nil, the same as no guides.
    private static func replace(_ list: [Guide], on item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let grid, _) = item.content else { return [] }
        let stored = list.isEmpty ? nil : list
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: grid, guides: stored))]
    }
}

/// A guide that is dropped on a frame: the frame and the guide in its own coordinates.
public struct GuideDrop: Equatable, Sendable {
    public var frame: ItemID
    public var guide: Guide
}

extension BoardStore {
    /// Adds a guide to a frame of the active space. One undo step. Returns false when nothing changes.
    @discardableResult
    public func perform(guideAdd guide: Guide, frame id: ItemID) throws -> Bool {
        guard let target = item(id) else { return false }
        let commands = FrameGuides.add(guide, to: target)
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.guide.add"))
    }

    /// Moves a guide of a frame. One undo step. Returns false when nothing changes.
    @discardableResult
    public func perform(guideMove index: Int, to position: Double, frame id: ItemID) throws -> Bool {
        guard let target = item(id) else { return false }
        let commands = FrameGuides.move(target, at: index, to: position)
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.guide.move"))
    }

    /// Removes a guide of a frame. One undo step. Returns false when nothing changes.
    @discardableResult
    public func perform(guideRemove index: Int, frame id: ItemID) throws -> Bool {
        guard let target = item(id) else { return false }
        let commands = FrameGuides.remove(target, at: index)
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.guide.remove"))
    }

    /// Removes all guides of a frame. One undo step. Returns false when the frame has none.
    @discardableResult
    public func perform(guidesRemoveAllFrom id: ItemID) throws -> Bool {
        guard let target = item(id) else { return false }
        let commands = FrameGuides.removeAll(from: target)
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.guide.removeAll"))
    }
}
