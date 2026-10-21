import CoreGraphics
import CoreText
import Foundation

public enum SheetExporter {
    public static func svg(_ s: Sheet) -> Data {
        var out = ["<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(f(s.width)) \(f(s.height))\" "
                   + "width=\"\(f(s.width))mm\" height=\"\(f(s.height))mm\" font-family=\"\(esc(s.font))\">",
                   "<rect width=\"\(f(s.width))\" height=\"\(f(s.height))\" fill=\"\(s.paper)\"/>"]
        for item in s.items {
            switch item {
            case let .line(a, b, width, color):
                out.append("<line x1=\"\(f(a.x))\" y1=\"\(f(a.y))\" x2=\"\(f(b.x))\" y2=\"\(f(b.y))\" stroke=\"\(color)\" stroke-width=\"\(f(width))\"/>")
            case let .rect(r, fill, stroke, width):
                out.append("<rect x=\"\(f(r.minX))\" y=\"\(f(r.minY))\" width=\"\(f(r.width))\" height=\"\(f(r.height))\" "
                           + "fill=\"\(fill ?? "none")\" stroke=\"\(stroke ?? "none")\" stroke-width=\"\(f(width))\"/>")
            case let .polygon(pts, fill, stroke, width):
                let p = pts.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " ")
                out.append("<polygon points=\"\(p)\" fill=\"\(fill ?? "none")\" stroke=\"\(stroke ?? "none")\" "
                           + "stroke-width=\"\(f(width))\" stroke-linejoin=\"round\"/>")
            case let .text(text, at, size, anchor, weight, color, rotation):
                let turn = rotation == 0 ? "" : " transform=\"rotate(\(f(rotation)) \(f(at.x)) \(f(at.y)))\""
                out.append("<text x=\"\(f(at.x))\" y=\"\(f(at.y))\" font-size=\"\(f(size))\" text-anchor=\"\(anchor.rawValue)\" "
                           + "font-weight=\"\(weight)\" fill=\"\(color)\"\(turn)>\(esc(text))</text>")
            }
        }
        out.append("</svg>")
        return Data(out.joined(separator: "\n").utf8)
    }

    public static func pdf(_ s: Sheet) -> Data {
        let k = 72 / 25.4
        let data = NSMutableData()
        var box = CGRect(x: 0, y: 0, width: s.width * k, height: s.height * k)
        guard let consumer = CGDataConsumer(data: data as CFMutableData),
              let ctx = CGContext(consumer: consumer, mediaBox: &box, nil) else { return Data() }
        ctx.beginPDFPage(nil)
        ctx.translateBy(x: 0, y: box.height)
        ctx.scaleBy(x: k, y: -k)
        draw(s, in: ctx)
        ctx.endPDFPage()
        ctx.closePDF()
        return data as Data
    }

    public static func draw(_ s: Sheet, in ctx: CGContext) {
        ctx.setFillColor(color(s.paper))
        ctx.fill(CGRect(x: 0, y: 0, width: s.width, height: s.height))
        ctx.setLineJoin(.round)
        for item in s.items {
            switch item {
            case let .line(a, b, width, c):
                ctx.setStrokeColor(color(c)); ctx.setLineWidth(width)
                ctx.strokeLineSegments(between: [a, b])
            case let .rect(r, fill, stroke, width):
                if let fill { ctx.setFillColor(color(fill)); ctx.fill(r) }
                if let stroke { ctx.setStrokeColor(color(stroke)); ctx.setLineWidth(width); ctx.stroke(r) }
            case let .polygon(pts, fill, stroke, width):
                guard pts.count > 2 else { continue }
                let path = CGMutablePath(); path.addLines(between: pts); path.closeSubpath()
                if let fill { ctx.addPath(path); ctx.setFillColor(color(fill)); ctx.fillPath() }
                if let stroke { ctx.addPath(path); ctx.setStrokeColor(color(stroke)); ctx.setLineWidth(width); ctx.strokePath() }
            case let .text(text, at, size, anchor, weight, c, rotation):
                let font = CTFontCreateWithName(s.pdfFont as CFString, size, nil)
                let face = weight >= 500 ? (CTFontCreateCopyWithSymbolicTraits(font, size, nil, .traitBold, .traitBold) ?? font) : font
                let attributed = NSAttributedString(string: text, attributes: [
                    NSAttributedString.Key(kCTFontAttributeName as String): face,
                    NSAttributedString.Key(kCTForegroundColorAttributeName as String): color(c)
                ])
                let line = CTLineCreateWithAttributedString(attributed)
                let w = CTLineGetTypographicBounds(line, nil, nil, nil)
                let shift = anchor == .start ? 0 : (anchor == .middle ? -w / 2 : -w)
                ctx.saveGState()
                ctx.translateBy(x: at.x, y: at.y)
                ctx.rotate(by: rotation * .pi / 180)
                ctx.scaleBy(x: 1, y: -1)
                ctx.textPosition = CGPoint(x: shift, y: 0)
                CTLineDraw(line, ctx)
                ctx.restoreGState()
            }
        }
    }

    static func color(_ hex: String) -> CGColor {
        let c = Hex.rgb(hex) ?? (0, 0, 0)
        return CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
    }

    static func f(_ v: Double) -> String { String(format: "%.2f", v) }
    static func f(_ v: CGFloat) -> String { f(Double(v)) }

    static func esc(_ t: String) -> String {
        t.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
