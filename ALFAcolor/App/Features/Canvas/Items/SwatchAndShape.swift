import SwiftUI
import AppTheme
import BoardModel
import Tokens

/// A swatch fills the body with its color. The name and the hex value are in the header.
struct SwatchBody: View {
    let content: SwatchContent

    var body: some View {
        if let color = content.color {
            Rectangle().fill(Color(color))
        }
    }
}

/// A shape inside its rectangle. The stroke lies inside the edge. A line runs from corner to corner.
struct ShapeBody: View {
    let content: ShapeContent
    let size: CanvasSize

    @Environment(\.theme) private var theme
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        switch content.kind {
        case .rectangle: painted(RoundedRectangle(cornerRadius: content.cornerRadius))
        case .capsule: painted(Capsule())
        case .ellipse: painted(Ellipse())
        case .line: line
        }
    }

    @ViewBuilder
    private func painted<S: InsettableShape>(_ shape: S) -> some View {
        ZStack {
            if let fill = content.fill { shape.fill(Color(fill)) }
            if let stroke = content.stroke, content.strokeWidth > 0 {
                shape.strokeBorder(Color(stroke), lineWidth: content.strokeWidth)
            }
        }
    }

    private var line: some View {
        Path { path in
            path.move(to: .zero)
            path.addLine(to: CGPoint(x: size.width, y: size.height))
        }
        .stroke(content.stroke.map { Color($0) } ?? theme.color(.text, scheme),
                style: StrokeStyle(lineWidth: content.strokeWidth, lineCap: .round))
    }
}
