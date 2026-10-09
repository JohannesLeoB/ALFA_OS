import Foundation
import ALFAcolorCore
import Geometry

/// Column grids of frames: set, change and remove. Each command is one undo step.
public enum FrameGrid {
    /// True when a grid fits a frame of this size: at least one column, no negative gutter, margins,
    /// or baseline values, and margins that leave room for the columns and the lines.
    public static func isValid(_ grid: ColumnGrid, in rect: Rect) -> Bool {
        let values = [grid.gutter, grid.marginLeft, grid.marginRight, grid.marginTop, grid.marginBottom,
                      grid.baseline, grid.baselineStart]
        guard rect.isFinite, grid.columns >= 1, values.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return false }
        return grid.marginLeft + grid.marginRight < rect.w && grid.marginTop + grid.marginBottom < rect.h
    }

    /// Sets the grid of a frame. Empty when the item is no frame, the grid does not fit, or it is already set.
    public static func set(_ grid: ColumnGrid, on item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let current) = item.content,
              isValid(grid, in: item.rect), current != grid else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: grid))]
    }

    /// Removes the grid of a frame. Empty when the item is no frame or has no grid.
    public static func remove(from item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let current) = item.content, current != nil else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: nil))]
    }
}

extension BoardStore {
    /// Sets the grid of the selected frames. One undo step. Returns false when no frame changes.
    @discardableResult
    public func perform(frameGrid grid: ColumnGrid) throws -> Bool {
        let commands = selectedItems.flatMap { FrameGrid.set(grid, on: $0) }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.frame.grid"))
    }

    /// Removes the grids of the selected frames. One undo step. Returns false when no frame has a grid.
    @discardableResult
    public func performFrameGridRemoval() throws -> Bool {
        let commands = selectedItems.flatMap { FrameGrid.remove(from: $0) }
        guard !commands.isEmpty else { return false }
        return try perform(.batch(commands, nameKey: "undo.frame.gridRemove"))
    }
}
