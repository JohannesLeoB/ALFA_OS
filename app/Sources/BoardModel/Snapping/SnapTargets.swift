import Foundation
import ALFAcolorCore
import Geometry

/// The kinds of snap target. When two targets are both in tolerance, the lower kind wins;
/// within one kind the smaller way wins.
public enum SnapKind: Int, Sendable {
    /// A guide that the user set.
    case guide = 0
    /// A column edge or a baseline of the frame.
    case column = 1
    /// An edge or the middle of another item.
    case edge = 2
    /// The distance to a neighbour that a spacing token names.
    case spacing = 3
    /// A point of the background grid.
    case grid = 4
}

/// A distance that a spacing token names, in board points.
public struct SpacingStop: Equatable, Sendable {
    public var name: String
    public var value: Double

    public init(name: String, value: Double) {
        self.name = name
        self.value = value
    }
}

/// Which edge a resize moves. `lower` is the left or top edge, `upper` the right or bottom edge.
public enum SnapEdge: Equatable, Sendable {
    case lower, upper
}

/// How a rectangle moves: as a whole, or by one edge per axis (nil keeps that axis as it is).
public enum SnapMotion: Equatable, Sendable {
    case move
    case resize(x: SnapEdge?, y: SnapEdge?)
}

/// What a rectangle may snap to. The caller leaves out the moving item itself.
public struct SnapTargets: Equatable, Sendable {
    /// Grid step in board points. 0 or less turns the grid off.
    public var gridStep: Double
    /// Other items of the space. Their edges and middles are targets. Fixed on creation, because the
    /// edges are indexed then.
    public let rects: [Rect]
    /// Guides that the user set.
    public var guides: [SnapGuide]
    /// Column edges and baselines of the frame that holds the rectangle. See `frameLines(in:grid:)`.
    public var frameLines: [SnapGuide]
    /// Distances that spacing tokens name. Empty turns the spacing snap off.
    public var spacing: [SpacingStop]
    /// The sorted edges of `rects`, read by `Snapper`.
    let index: SnapIndex

    public init(gridStep: Double = 0, rects: [Rect] = [], guides: [SnapGuide] = [],
                frameLines: [SnapGuide] = [], spacing: [SpacingStop] = []) {
        self.gridStep = gridStep
        self.rects = rects
        self.guides = guides
        self.frameLines = frameLines
        self.spacing = spacing
        index = SnapIndex(rects: rects)
    }
}

public extension SnapTargets {
    /// The most columns or baselines that a frame gives lines for. Keeps a tiny baseline step
    /// from making millions of lines.
    static let lineLimit = 1_000

    /// The column edges and the baselines of a frame as guides. Column edges run along the height
    /// of their column, baselines along the width of the frame. Empty when the grid has no usable
    /// columns or would give more than `lineLimit` lines.
    static func frameLines(in frame: Rect, grid: ColumnGrid) -> [SnapGuide] {
        guard frame.isFinite, (1...lineLimit).contains(grid.columns) else { return [] }
        var lines: [SnapGuide] = []
        for column in grid.columnRects(in: frame) where column.isFinite {
            let span = column.y...column.maxY
            lines.append(SnapGuide(axis: .vertical, position: column.x, span: span))
            lines.append(SnapGuide(axis: .vertical, position: column.maxX, span: span))
        }
        if grid.baseline > 0, frame.h / grid.baseline <= Double(lineLimit) {
            let span = frame.x...frame.maxX
            for y in grid.baselines(in: frame) {
                lines.append(SnapGuide(axis: .horizontal, position: y, span: span))
            }
        }
        return lines
    }
}
