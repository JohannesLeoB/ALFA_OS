import Foundation
import ALFAcolorCore
import Geometry

/// Column grids of frames: set, change and remove. Each command is one undo step.
public enum FrameGrid {
    /// The grid that a frame gets when the grid is switched on: 12 columns, gutter 24, margins 24.
    public static let standard = ColumnGrid(columns: 12, gutter: 24, margin: 24)

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
        guard case .frame(let deviceID, let gridID, let scale, let current, let guides) = item.content,
              isValid(grid, in: item.rect), current != grid else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: grid, guides: guides))]
    }

    /// The column and baseline lines of the frames that hold the rectangle completely. Frames without a grid,
    /// and frames that do not hold it, give no lines. `items` are the items that can be targets.
    public static func snapLines(around rect: Rect?, in items: [Item]) -> [SnapGuide] {
        guard let rect, rect.isFinite else { return [] }
        return items.flatMap { item -> [SnapGuide] in
            guard case .frame(_, _, _, let grid?, _) = item.content, isValid(grid, in: item.rect) else { return [] }
            let frame = item.rect
            let holds = frame.x <= rect.x && rect.maxX <= frame.maxX && frame.y <= rect.y && rect.maxY <= frame.maxY
            return holds ? SnapTargets.frameLines(in: frame, grid: grid) : []
        }
    }

    /// Removes the grid of a frame. Empty when the item is no frame or has no grid.
    public static func remove(from item: Item) -> [Command] {
        guard case .frame(let deviceID, let gridID, let scale, let current, let guides) = item.content, current != nil else { return [] }
        return [.setContent(item.id, .frame(deviceID: deviceID, gridID: gridID, scale: scale, grid: nil, guides: guides))]
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

/// The lines of a column grid in the frame's own coordinates (origin at the top left), for drawing.
public struct FrameGridLines: Equatable, Sendable {
    /// The columns as rectangles.
    public var columns: [Rect]
    /// The baselines as y positions.
    public var baselines: [Double]
    /// The area inside the margins.
    public var inner: Rect

    /// The lines of a grid in a frame of this size. nil when the grid does not fit the frame or would
    /// give more lines than `SnapTargets.lineLimit`.
    public static func make(_ grid: ColumnGrid, width: Double, height: Double) -> FrameGridLines? {
        let local = Rect(x: 0, y: 0, w: width, h: height)
        guard FrameGrid.isValid(grid, in: local), grid.columns <= SnapTargets.lineLimit,
              grid.baseline == 0 || height / grid.baseline <= Double(SnapTargets.lineLimit) else { return nil }
        return FrameGridLines(
            columns: grid.columnRects(in: local),
            baselines: grid.baselines(in: local),
            inner: Rect(x: grid.marginLeft, y: grid.marginTop,
                        w: width - grid.marginLeft - grid.marginRight,
                        h: height - grid.marginTop - grid.marginBottom))
    }
}

/// A saved column grid with a name. Templates live in a file of the app, not in a document.
public struct GridTemplate: Codable, Hashable, Sendable, Identifiable {
    public var id: String
    public var name: String
    public var grid: ColumnGrid

    public init(id: String = UUID().uuidString, name: String, grid: ColumnGrid) {
        self.id = id
        self.name = name
        self.grid = grid
    }
}

/// Reads and writes the grid templates as one JSON file. Every change reads the file first, so a file
/// that cannot be read is never overwritten.
public enum GridTemplates {
    /// The templates in the file. An empty list when there is no file.
    public static func load(from url: URL) throws -> [GridTemplate] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        return try JSONDecoder().decode([GridTemplate].self, from: Data(contentsOf: url))
    }

    /// Adds a template after the ones in the file.
    public static func add(_ template: GridTemplate, to url: URL) throws {
        try write(try load(from: url) + [template], to: url)
    }

    /// Removes the template with this ID. Writes the file unchanged when there is none.
    public static func remove(id: String, from url: URL) throws {
        try write(try load(from: url).filter { $0.id != id }, to: url)
    }

    private static func write(_ templates: [GridTemplate], to url: URL) throws {
        try JSONEncoder().encode(templates).write(to: url, options: .atomic)
    }
}
