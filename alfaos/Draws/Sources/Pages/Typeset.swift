import CoreGraphics
import CoreText
import Foundation

enum Tint {
    static func rgb(_ value: String) -> (Double, Double, Double) {
        let s = value.hasPrefix("#") ? String(value.dropFirst()) : value
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return (0, 0, 0) }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    static func cg(_ value: String) -> CGColor {
        let c = rgb(value)
        return CGColor(srgbRed: c.0, green: c.1, blue: c.2, alpha: 1)
    }
}

struct Laid {
    var text: String
    var x: Double
    var y: Double
    var line: CTLine
}

struct Setting {
    var lines: [Laid]
    var fits: Bool
}

enum Typeset {
    static func font(_ family: String, _ size: Double, _ weight: Int) -> CTFont {
        let base = CTFontCreateWithName(family as CFString, size, nil)
        guard weight >= 500 else { return base }
        return CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold) ?? base
    }

    static func attributed(_ text: String, _ font: CTFont, _ color: String, _ style: CTParagraphStyle? = nil) -> NSAttributedString {
        var attributes: [NSAttributedString.Key: Any] = [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): Tint.cg(color)
        ]
        if let style { attributes[NSAttributedString.Key(kCTParagraphStyleAttributeName as String)] = style }
        return NSAttributedString(string: text, attributes: attributes)
    }

    static func line(_ run: Run, _ fonts: [FontFace]) -> CTLine {
        let face = font(FontFace.family(run.role, in: fonts), run.size, run.weight)
        return CTLineCreateWithAttributedString(attributed(run.text, face, run.color))
    }

    static func width(_ line: CTLine) -> Double {
        CTLineGetTypographicBounds(line, nil, nil, nil)
    }

    static func shift(_ anchor: Anchor, _ width: Double) -> Double {
        anchor == .start ? 0 : (anchor == .middle ? -width / 2 : -width)
    }

    static func style(_ align: Align, _ leading: Double) -> CTParagraphStyle {
        var alignment: CTTextAlignment = align == .left ? .left : (align == .center ? .center : .right)
        var height = CGFloat(leading)
        return withUnsafePointer(to: &alignment) { a in
            withUnsafePointer(to: &height) { h in
                var settings = [CTParagraphStyleSetting(spec: .alignment, valueSize: MemoryLayout<CTTextAlignment>.size, value: a)]
                if leading > 0 {
                    settings.append(CTParagraphStyleSetting(spec: .minimumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: h))
                    settings.append(CTParagraphStyleSetting(spec: .maximumLineHeight, valueSize: MemoryLayout<CGFloat>.size, value: h))
                }
                return CTParagraphStyleCreate(settings, settings.count)
            }
        }
    }

    static func lay(_ block: Block, _ fonts: [FontFace]) -> Setting {
        let face = font(FontFace.family(block.role, in: fonts), block.size, block.weight)
        let text = attributed(block.text, face, block.color, style(block.align, block.leading))
        let w = block.frame.width, h = block.frame.height
        let setter = CTFramesetterCreateWithAttributedString(text)
        let frame = CTFramesetterCreateFrame(setter, CFRange(location: 0, length: 0), CGPath(rect: CGRect(x: 0, y: 0, width: w, height: h), transform: nil), nil)
        let lines = CTFrameGetLines(frame) as? [CTLine] ?? []
        var origins = [CGPoint](repeating: .zero, count: lines.count)
        CTFrameGetLineOrigins(frame, CFRange(location: 0, length: 0), &origins)
        let whole = text.string as NSString
        var laid: [Laid] = []
        for (line, origin) in zip(lines, origins) {
            let range = CTLineGetStringRange(line)
            let piece = whole.substring(with: NSRange(location: range.location, length: range.length))
            let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
            laid.append(Laid(text: trimmed, x: block.frame.minX + origin.x, y: block.frame.minY + h - origin.y, line: line))
        }
        let visible = CTFrameGetVisibleStringRange(frame)
        return Setting(lines: laid, fits: visible.location + visible.length >= text.length)
    }
}
