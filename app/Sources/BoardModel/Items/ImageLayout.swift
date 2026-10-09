import Foundation
import ALFAcolorCore

/// How an image sits in its area.
public enum ImageFit: Equatable, Sendable {
    /// All of the image is visible. Space may be left over on two sides.
    case fit
    /// The image covers the area. Parts of it may be cut off.
    case fill
}

/// The maths of an image in a card: which part shows, and where it is drawn.
public enum ImageLayout {
    /// The crop of an image item as a region of 0 to 1 on both axes. nil for no crop, for a crop that is
    /// not a number or has no area, and for a crop that covers the whole image. Parts outside the image are cut off.
    public static func region(crop: Rect?) -> Rect? {
        guard let crop, crop.x.isFinite, crop.y.isFinite, crop.w.isFinite, crop.h.isFinite else { return nil }
        let x0 = min(max(crop.x, 0), 1), y0 = min(max(crop.y, 0), 1)
        let x1 = min(max(crop.maxX, 0), 1), y1 = min(max(crop.maxY, 0), 1)
        guard x1 > x0, y1 > y0 else { return nil }
        let region = Rect(x: x0, y: y0, w: x1 - x0, h: y1 - y0)
        return region == Rect(x: 0, y: 0, w: 1, h: 1) ? nil : region
    }

    /// The size in pixels of the part that shows.
    public static func visiblePixels(of image: CanvasSize, region: Rect?) -> CanvasSize {
        guard let region else { return image }
        return CanvasSize(width: image.width * region.w, height: image.height * region.h)
    }

    /// Where the visible part is drawn inside an area of the given size, with the origin at the area's top left.
    /// The result is centered. For `.fill` it is larger than the area on one axis or on both.
    /// An unusable size gives the whole area.
    public static func drawRect(visible: CanvasSize, in area: CanvasSize, fit: ImageFit) -> Rect {
        let whole = Rect(x: 0, y: 0, w: max(area.width, 0), h: max(area.height, 0))
        guard visible.isUsable, area.isUsable else { return whole }
        let across = area.width / visible.width, down = area.height / visible.height
        let scale = fit == .fit ? min(across, down) : max(across, down)
        let width = visible.width * scale, height = visible.height * scale
        return Rect(x: (area.width - width) / 2, y: (area.height - height) / 2, w: width, h: height)
    }

    /// The part of a downsized copy to cut out, in pixels of the copy. The copy holds the whole image.
    /// The edges are rounded to whole pixels and the result has at least one pixel on each axis.
    public static func cropRect(region: Rect?, copy: CanvasSize) -> Rect {
        guard let region else { return Rect(x: 0, y: 0, w: copy.width, h: copy.height) }
        let x0 = (region.x * copy.width).rounded(.down), y0 = (region.y * copy.height).rounded(.down)
        let x1 = (region.maxX * copy.width).rounded(.up), y1 = (region.maxY * copy.height).rounded(.up)
        let x = min(x0, max(copy.width - 1, 0)), y = min(y0, max(copy.height - 1, 0))
        return Rect(x: x, y: y, w: max(min(x1, copy.width) - x, 1), h: max(min(y1, copy.height) - y, 1))
    }

    /// The longer side, in pixels, that a copy of the whole image needs so that the visible part is sharp
    /// when it is drawn at `drawn` points on a screen with `scale` pixels per point.
    public static func neededEdge(drawn: CanvasSize, visible: CanvasSize, image: CanvasSize, scale: Double) -> Double {
        guard drawn.isUsable, visible.isUsable, image.isUsable, scale.isFinite, scale > 0 else { return 0 }
        let wanted = max(drawn.width / visible.width, drawn.height / visible.height) * scale
        return max(image.width, image.height) * min(wanted, 1)
    }
}
