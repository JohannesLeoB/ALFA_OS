import Foundation
import ALFAcolorCore

/// The two areas of a card: the header with the title and the body with the content.
/// Both lie in the coordinates of the card, with the origin at its top left.
public struct CardRegions: Equatable, Sendable {
    /// nil when the card is too small to carry a header.
    public var header: Rect?
    public var body: Rect
}

public enum CardLayout {
    /// A card gets a header only when the body is at least as tall as the header.
    /// A card of a different height shows the body alone, over the whole card.
    public static func regions(size: CanvasSize, headerHeight: Double) -> CardRegions {
        let width = max(size.width, 0), height = max(size.height, 0)
        guard headerHeight.isFinite, headerHeight > 0, height >= 2 * headerHeight else {
            return CardRegions(header: nil, body: Rect(x: 0, y: 0, w: width, h: height))
        }
        return CardRegions(header: Rect(x: 0, y: 0, w: width, h: headerHeight),
                           body: Rect(x: 0, y: headerHeight, w: width, h: height - headerHeight))
    }

    /// The band of a group: always there, but never taller than the group.
    public static func band(size: CanvasSize, headerHeight: Double) -> Rect {
        Rect(x: 0, y: 0, w: max(size.width, 0), h: min(max(headerHeight, 0), max(size.height, 0)))
    }
}

/// How much of an item is drawn. Items that are small on the screen skip text and shadow.
public enum DetailLevel: Equatable, Sendable {
    case full, reduced

    /// An item whose longer side is shorter than this on the screen, in points, is drawn reduced.
    public static let reducedBelow = 64.0

    public static func level(for size: CanvasSize, zoom: Double) -> DetailLevel {
        guard zoom.isFinite, zoom > 0 else { return .reduced }
        return max(size.width, size.height) * zoom < reducedBelow ? .reduced : .full
    }
}

public enum Hairline {
    /// The width in board points of a line that is one device pixel wide on the screen.
    /// `zoom` is the zoom of the canvas, `scale` the device pixels per screen point.
    public static func width(zoom: Double, scale: Double) -> Double {
        guard zoom.isFinite, zoom > 0, scale.isFinite, scale > 0 else { return 0 }
        return 1 / (zoom * scale)
    }
}
