import CoreGraphics
import CoreText
import Foundation

enum Metrics {
    static func bounds(_ item: Item, _ fonts: [FontFace]) -> CGRect? {
        switch item {
        case let .line(a, b, paint):
            let box = CGRect(x: min(a.x, b.x), y: min(a.y, b.y), width: abs(a.x - b.x), height: abs(a.y - b.y))
            return box.insetBy(dx: -paint.width / 2, dy: -paint.width / 2)
        case let .rect(r, paint):
            return turned(grow(r, paint), paint.rotation)
        case let .polygon(points, paint):
            return span(points).map { turned(grow($0, paint), paint.rotation) }
        case let .path(steps, paint):
            return span(steps.flatMap(points)).map { turned(grow($0, paint), paint.rotation) }
        case let .text(run):
            let line = Typeset.line(run, fonts)
            var ascent: CGFloat = 0, descent: CGFloat = 0
            let width = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
            let box = CGRect(x: run.origin.x + Typeset.shift(run.anchor, width), y: run.origin.y - ascent, width: width, height: ascent + descent)
            return rotate(box, run.rotation, about: run.origin)
        case let .textBlock(block):
            return block.frame
        case let .image(picture):
            return picture.frame
        case let .group(transform, items):
            let parts = items.compactMap { bounds($0, fonts) }
            guard let first = parts.first else { return nil }
            return parts.dropFirst().reduce(first) { $0.union($1) }.applying(transform.matrix)
        }
    }

    static func grow(_ r: CGRect, _ paint: Paint) -> CGRect {
        paint.stroke == nil ? r : r.insetBy(dx: -paint.width / 2, dy: -paint.width / 2)
    }

    static func span(_ points: [CGPoint]) -> CGRect? {
        guard let first = points.first else { return nil }
        let xs = points.map(\.x), ys = points.map(\.y)
        return CGRect(x: xs.min() ?? first.x, y: ys.min() ?? first.y,
                      width: (xs.max() ?? first.x) - (xs.min() ?? first.x), height: (ys.max() ?? first.y) - (ys.min() ?? first.y))
    }

    static func points(_ step: Step) -> [CGPoint] {
        switch step {
        case let .move(p), let .line(p): return [p]
        case let .curve(a, b, c): return [a, b, c]
        case .close: return []
        }
    }

    static func turned(_ r: CGRect, _ degrees: Double) -> CGRect {
        rotate(r, degrees, about: CGPoint(x: r.midX, y: r.midY))
    }

    static func rotate(_ r: CGRect, _ degrees: Double, about c: CGPoint) -> CGRect {
        guard degrees != 0 else { return r }
        let t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: degrees * .pi / 180).translatedBy(x: -c.x, y: -c.y)
        return r.applying(t)
    }

    static func center(_ steps: [Step]) -> CGPoint {
        let box = span(steps.flatMap(points)) ?? .zero
        return CGPoint(x: box.midX, y: box.midY)
    }
}
