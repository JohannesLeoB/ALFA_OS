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

    /// The command that sets the guides of a frame. An empty list is stored as nil, the same as no guides.
    private static func replace(_ list: [Guide], on item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let grid, _) = item.content else { return [] }
        let stored = list.isEmpty ? nil : list
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: grid, guides: stored))]
    }
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
