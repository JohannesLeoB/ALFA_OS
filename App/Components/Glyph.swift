import Design
import Shell
import SwiftUI

struct Glyph: View {
    let glyph: Icon
    var size = SheetValues.iconSize
    var stroke = SheetValues.iconStroke

    init(_ glyph: Icon, size: Double = SheetValues.iconSize, stroke: Double = SheetValues.iconStroke) {
        self.glyph = glyph
        self.size = size
        self.stroke = stroke
    }

    var body: some View {
        GlyphOutline(glyph: glyph)
            .stroke(style: StrokeStyle(lineWidth: CGFloat(stroke * size / SheetValues.iconBox), lineCap: .round, lineJoin: .round))
            .frame(width: CGFloat(size), height: CGFloat(size))
    }
}

extension Glyph {
    static func small(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.smallIcon, stroke: SheetValues.smallIconStroke)
    }

    static func tiny(_ glyph: Icon) -> Glyph {
        Glyph(glyph, size: SheetValues.tinyIcon, stroke: SheetValues.tinyIconStroke)
    }
}

struct GlyphOutline: Shape {
    let glyph: Icon

    func path(in rect: CGRect) -> Path {
        let scale = rect.width / CGFloat(SheetValues.iconBox)
        func point(_ x: Double, _ y: Double) -> CGPoint {
            CGPoint(x: rect.minX + CGFloat(x) * scale, y: rect.minY + CGFloat(y) * scale)
        }
        var path = Path()
        for segment in glyph.path.segments {
            switch segment {
            case .move(let x, let y): path.move(to: point(x, y))
            case .line(let x, let y): path.addLine(to: point(x, y))
            case .cubic(let c1x, let c1y, let c2x, let c2y, let x, let y):
                path.addCurve(to: point(x, y), control1: point(c1x, c1y), control2: point(c2x, c2y))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}

struct PressScaleButtonStyle: ButtonStyle {
    let scale: Double

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? CGFloat(scale) : 1)
    }
}
