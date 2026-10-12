import Foundation
import ALFAcolorCore
import Tokens

/// The numbers to draw a shape. The shape is drawn inside its rectangle, and the stroke lies inside the edge.
enum ShapeGeometry {
    static func content(kind: ShapeKind, style: ShapeStyle, size: Rect) -> ShapeContent {
        let width = style.strokeWidth.isFinite ? max(style.strokeWidth, 0) : 0
        let stroke = style.stroke.flatMap(RGB.init(hex:))
        let shorter = max(min(size.w, size.h), 0)
        let radius = style.cornerRadius.isFinite ? min(max(style.cornerRadius, 0), shorter / 2) : 0
        return ShapeContent(kind: kind, fill: kind == .line ? nil : style.fill.flatMap(RGB.init(hex:)),
                            stroke: stroke, strokeWidth: stroke == nil && kind != .line ? 0 : width, cornerRadius: kind == .rectangle ? radius : 0)
    }
}
