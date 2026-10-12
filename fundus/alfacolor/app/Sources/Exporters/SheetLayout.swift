import Foundation
import ALFAcolorCore

/// The direction of a dimension line.
enum SheetAxis: Equatable, Sendable {
    case horizontal
    case vertical
}

/// One dimension line: a measure in points of the frame, drawn between two positions on the sheet.
struct SheetDimension: Equatable, Sendable {
    let axis: SheetAxis
    /// Start and end along the axis, in sheet points from the top left corner.
    let from: Double
    let to: Double
    /// Position across the axis, in sheet points.
    let line: Double
    /// The measure in points of the frame, not scaled.
    let value: Double
}

/// The placement of one frame and its pieces on one sheet page. Pure numbers: no drawing happens here.
struct SheetLayout: Equatable, Sendable {
    /// Sheet points per point of the frame.
    let scale: Double
    /// The frame on the sheet, from the top left corner.
    let frame: Rect
    /// The pieces on the sheet, in the order of the input.
    let pieces: [Rect]
    /// The legend area at the foot of the page. Its height is 0 without entries.
    let legend: Rect
    /// The frame measures and, per piece, its gaps to the frame edges.
    let dimensions: [SheetDimension]

    /// Margins and bands in sheet points.
    enum Metrics {
        static let margin = 28.0
        /// Band for the title line at the top.
        static let header = 44.0
        /// Band for the page number at the foot.
        static let footer = 20.0
        /// Room left and below the frame for the frame measures.
        static let chain = 36.0
        /// Distance of a measure line from the frame edge.
        static let chainOffset = 12.0
        /// Gaps that are shorter than this on the sheet get no label.
        static let minimumLabelLength = 18.0
        static let legendColumns = 4
        static let legendRow = 16.0
        static let legendHeader = 20.0
        static let legendGap = 12.0
    }

    /// The height of the legend band for a number of entries.
    static func legendHeight(entries: Int) -> Double {
        guard entries > 0 else { return 0 }
        let rows = (entries + Metrics.legendColumns - 1) / Metrics.legendColumns
        return Metrics.legendGap + Metrics.legendHeader + Double(rows) * Metrics.legendRow
    }

    /// Fits a frame of `frame` size onto the page, as large as the bands allow, and centres it.
    /// `pieces` are the rects of the items relative to the frame, in points.
    static func make(paper: SheetPaper, frame size: Rect, pieces: [Rect], legendEntries: Int) -> SheetLayout {
        let frameW = max(size.w, 1)
        let frameH = max(size.h, 1)
        let legendH = legendHeight(entries: legendEntries)

        let left = Metrics.margin + Metrics.chain
        let right = paper.width - Metrics.margin
        let top = Metrics.margin + Metrics.header
        let bottom = paper.height - Metrics.margin - Metrics.footer - legendH - Metrics.chain
        let availW = right - left
        let availH = bottom - top
        let scale = min(availW / frameW, availH / frameH)

        let w = frameW * scale
        let h = frameH * scale
        let frame = Rect(x: left + (availW - w) / 2, y: top + (availH - h) / 2, w: w, h: h)

        let placed = pieces.map { piece in
            Rect(x: frame.x + piece.x * scale, y: frame.y + piece.y * scale, w: piece.w * scale, h: piece.h * scale)
        }
        let legend = Rect(x: Metrics.margin, y: paper.height - Metrics.margin - Metrics.footer - legendH,
                          w: paper.width - 2 * Metrics.margin, h: legendH)

        var dimensions = [
            SheetDimension(axis: .horizontal, from: frame.x, to: frame.maxX, line: frame.maxY + Metrics.chainOffset, value: frameW),
            SheetDimension(axis: .vertical, from: frame.y, to: frame.maxY, line: frame.x - Metrics.chainOffset, value: frameH),
        ]
        for (piece, box) in zip(pieces, placed) {
            dimensions += gaps(of: piece, box: box, frame: frame, frameSize: (frameW, frameH))
        }
        return SheetLayout(scale: scale, frame: frame, pieces: placed, legend: legend, dimensions: dimensions)
    }

    /// The four gaps of a piece to the frame edges. A gap of zero or less, or one too short to label, is left out.
    private static func gaps(of piece: Rect, box: Rect, frame: Rect, frameSize: (w: Double, h: Double)) -> [SheetDimension] {
        var out: [SheetDimension] = []
        let midY = box.y + box.h / 2
        let midX = box.x + box.w / 2
        let candidates: [(SheetAxis, Double, Double, Double, Double)] = [
            (.horizontal, frame.x, box.x, midY, piece.x),
            (.horizontal, box.maxX, frame.maxX, midY, frameSize.w - piece.maxX),
            (.vertical, frame.y, box.y, midX, piece.y),
            (.vertical, box.maxY, frame.maxY, midX, frameSize.h - piece.maxY),
        ]
        for (axis, from, to, line, value) in candidates where value > 0 && abs(to - from) >= Metrics.minimumLabelLength {
            out.append(SheetDimension(axis: axis, from: from, to: to, line: line, value: value))
        }
        return out
    }
}
