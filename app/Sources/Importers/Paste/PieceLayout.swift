import Foundation
import ALFAcolorCore
import BoardModel

/// Sizes and places for new pieces, in board points.
public struct PieceLayout: Equatable, Sendable {
    /// The height of the header band of a card. A card is this much taller than its body.
    public var headerHeight: Double

    public init(headerHeight: Double) { self.headerHeight = headerHeight }

    /// The longest side of the body of an image, at most. A small image is not enlarged beyond the least.
    static let imageLongSide = 360.0
    static let imageLeastLongSide = 96.0
    static let noteWidth = 280.0
    static let noteLeastBody = 96.0
    static let noteMostBody = 480.0
    static let noteLineHeight = 20.0
    static let noteLinePadding = 24.0
    static let noteCharactersPerLine = 32
    static let linkWidth = 280.0
    static let linkBody = 96.0
    static let swatchWidth = 128.0
    static let swatchBody = 96.0
    static let codeWidth = 480.0
    static let codeBody = 320.0
    /// The gap between swatches in a row, and the number of swatches in a row.
    static let swatchGap = 16.0
    static let swatchColumns = 8
    /// The offset from one piece to the next when pieces are stacked.
    static let cascadeStep = 40.0

    /// The size of the card for a piece.
    public func size(of piece: Piece) -> CanvasSize {
        switch piece.body {
        case .image(_, _, let pixels):
            guard let pixels, pixels.isUsable else { return CanvasSize(width: Self.imageLongSide, height: 240 + headerHeight) }
            let long = min(max(max(pixels.width, pixels.height), Self.imageLeastLongSide), Self.imageLongSide)
            let scale = long / max(pixels.width, pixels.height)
            return CanvasSize(width: (pixels.width * scale).rounded(.up), height: (pixels.height * scale).rounded(.up) + headerHeight)
        case .content(let content):
            switch content {
            case .note(let text):
                let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
                    .reduce(0) { $0 + max(1, ($1.count + Self.noteCharactersPerLine - 1) / Self.noteCharactersPerLine) }
                let body = min(max(Double(lines) * Self.noteLineHeight + Self.noteLinePadding, Self.noteLeastBody), Self.noteMostBody)
                return CanvasSize(width: Self.noteWidth, height: body + headerHeight)
            case .link: return CanvasSize(width: Self.linkWidth, height: Self.linkBody + headerHeight)
            case .swatch: return CanvasSize(width: Self.swatchWidth, height: Self.swatchBody + headerHeight)
            default: return CanvasSize(width: Self.codeWidth, height: Self.codeBody + headerHeight)
            }
        }
    }

    /// The rectangles for the pieces, in the order of the pieces, around a point of the board.
    /// A set of swatches lies in rows. Anything else is stacked with a step down and to the right.
    /// The origins are whole points.
    public func rects(for pieces: [Piece], centerX: Double, centerY: Double) -> [Rect] {
        guard !pieces.isEmpty else { return [] }
        let sizes = pieces.map(size(of:))
        let allSwatches = pieces.allSatisfy { if case .content(.swatch) = $0.body { true } else { false } }
        if allSwatches { return swatchRows(sizes, centerX: centerX, centerY: centerY) }
        return sizes.enumerated().map { index, size in
            let shift = Double(index) * Self.cascadeStep
            return Rect(x: (centerX - size.width / 2 + shift).rounded(), y: (centerY - size.height / 2 + shift).rounded(),
                        w: size.width, h: size.height)
        }
    }

    private func swatchRows(_ sizes: [CanvasSize], centerX: Double, centerY: Double) -> [Rect] {
        let columns = min(sizes.count, Self.swatchColumns)
        let rows = (sizes.count + columns - 1) / columns
        let width = Self.swatchWidth * Double(columns) + Self.swatchGap * Double(columns - 1)
        let cell = sizes[0].height
        let height = cell * Double(rows) + Self.swatchGap * Double(rows - 1)
        let left = centerX - width / 2, top = centerY - height / 2
        return sizes.enumerated().map { index, size in
            let column = index % columns, row = index / columns
            return Rect(x: (left + Double(column) * (Self.swatchWidth + Self.swatchGap)).rounded(),
                        y: (top + Double(row) * (cell + Self.swatchGap)).rounded(), w: size.width, h: size.height)
        }
    }
}
