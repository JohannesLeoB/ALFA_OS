import CoreGraphics
import CoreText
import Foundation
import ALFAcolorCore
import Tokens

/// Drawing primitives for the sheet. Positions are sheet points from the top left corner; the canvas turns them
/// into the bottom left origin of a PDF page.
struct SheetCanvas {
    enum Align {
        case leading
        case centre
        case trailing
    }

    let context: CGContext
    let height: Double

    func cgRect(_ r: Rect) -> CGRect {
        CGRect(x: r.x, y: height - r.maxY, width: r.w, height: r.h)
    }

    func fill(_ r: Rect, _ colour: CGColor) {
        context.setFillColor(colour)
        context.fill(cgRect(r))
    }

    func stroke(_ r: Rect, _ colour: CGColor, width: Double) {
        context.setStrokeColor(colour)
        context.setLineWidth(width)
        context.stroke(cgRect(r))
    }

    func line(_ a: (x: Double, y: Double), _ b: (x: Double, y: Double), _ colour: CGColor, width: Double) {
        context.setStrokeColor(colour)
        context.setLineWidth(width)
        context.move(to: CGPoint(x: a.x, y: height - a.y))
        context.addLine(to: CGPoint(x: b.x, y: height - b.y))
        context.strokePath()
    }

    /// Draws one line of text. `baseline` is the sheet height of the baseline. Returns the width drawn.
    /// With `maxWidth` the line is cut at that width.
    @discardableResult
    func text(_ string: String, x: Double, baseline: Double, size: Double, bold: Bool = false,
              colour: CGColor, align: Align = .leading, maxWidth: Double? = nil) -> Double {
        var line = Self.line(string, size: size, bold: bold, colour: colour)
        var width = CTLineGetTypographicBounds(line, nil, nil, nil)
        if let maxWidth, width > maxWidth {
            guard let cut = CTLineCreateTruncatedLine(line, max(maxWidth, 0), .end, nil) else { return 0 }
            line = cut
            width = min(width, maxWidth)
        }
        let start: Double
        switch align {
        case .leading: start = x
        case .centre: start = x - width / 2
        case .trailing: start = x - width
        }
        context.textPosition = CGPoint(x: start, y: height - baseline)
        CTLineDraw(line, context)
        return width
    }

    /// The width of a line of text, without drawing it.
    func width(of string: String, size: Double, bold: Bool = false) -> Double {
        CTLineGetTypographicBounds(Self.line(string, size: size, bold: bold, colour: Self.grey(0)), nil, nil, nil)
    }

    private static func line(_ string: String, size: Double, bold: Bool, colour: CGColor) -> CTLine {
        let font = CTFontCreateUIFontForLanguage(bold ? .emphasizedSystem : .system, CGFloat(size), nil)
            ?? CTFontCreateWithName("Helvetica" as CFString, CGFloat(size), nil)
        let attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(rawValue: kCTFontAttributeName as String): font,
            NSAttributedString.Key(rawValue: kCTForegroundColorAttributeName as String): colour,
        ]
        return CTLineCreateWithAttributedString(NSAttributedString(string: string, attributes: attributes) as CFAttributedString)
    }

    /// A neutral grey: 0 is black, 1 is white. Used where a value has no colour of its own.
    static func grey(_ level: Double) -> CGColor {
        let space = CGColorSpaceCreateDeviceGray()
        return CGColor(colorSpace: space, components: [CGFloat(level), 1]) ?? CGColor(colorSpace: space, components: [0, 1])!
    }

    /// The colour of a hex value, or nil when the text is no colour.
    static func colour(hex: String) -> CGColor? {
        guard let rgb = RGB(hex: hex) else { return nil }
        return CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(),
                       components: [CGFloat(rgb.r), CGFloat(rgb.g), CGFloat(rgb.b), CGFloat(rgb.a)])
    }
}
