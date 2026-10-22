import CoreGraphics
import Foundation

public struct SVGRenderer: Renderer {
    public init() {}

    public func render(_ doc: Document) -> [String] {
        doc.pages.map { svg($0, fonts: doc.fonts) }
    }

    public func svg(_ page: Page, fonts: [FontFace]) -> String {
        let w = SVGRenderer.f(page.size.width), h = SVGRenderer.f(page.size.height)
        var out = ["<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 \(w) \(h)\" "
                   + "width=\"\(w)mm\" height=\"\(h)mm\" font-family=\"\(SVGRenderer.esc(FontFace.family(.sans, in: fonts)))\">"]
        out += SVGRenderer.elements(page, fonts, scope: "clip")
        out.append("</svg>")
        return out.joined(separator: "\n")
    }

    static func elements(_ page: Page, _ fonts: [FontFace], scope: String) -> [String] {
        var out: [String] = []
        if let background = page.background {
            out.append("<rect width=\"\(f(page.size.width))\" height=\"\(f(page.size.height))\" fill=\"\(background)\"/>")
        }
        var clips = 0
        for item in page.items { SVGRenderer.emit(item, fonts, &out, &clips, scope) }
        return out
    }

    static func emit(_ item: Item, _ fonts: [FontFace], _ out: inout [String], _ clips: inout Int, _ scope: String) {
        switch item {
        case let .line(a, b, paint):
            out.append("<line x1=\"\(f(a.x))\" y1=\"\(f(a.y))\" x2=\"\(f(b.x))\" y2=\"\(f(b.y))\" stroke=\"\(paint.stroke ?? "none")\" "
                       + "stroke-width=\"\(f(paint.width))\"\(dash(paint))/>")
        case let .rect(r, paint):
            out.append("<rect x=\"\(f(r.minX))\" y=\"\(f(r.minY))\" width=\"\(f(r.width))\" height=\"\(f(r.height))\" "
                       + "fill=\"\(paint.fill ?? "none")\" stroke=\"\(paint.stroke ?? "none")\" stroke-width=\"\(f(paint.width))\""
                       + "\(dash(paint))\(turn(paint, CGPoint(x: r.midX, y: r.midY)))/>")
        case let .polygon(points, paint):
            let p = points.map { "\(f($0.x)),\(f($0.y))" }.joined(separator: " ")
            out.append("<polygon points=\"\(p)\" fill=\"\(paint.fill ?? "none")\" stroke=\"\(paint.stroke ?? "none")\" "
                       + "stroke-width=\"\(f(paint.width))\" stroke-linejoin=\"round\"\(dash(paint))\(turn(paint, Metrics.center(points.map(Step.line))))/>")
        case let .path(steps, paint):
            out.append("<path d=\"\(d(steps))\" fill=\"\(paint.fill ?? "none")\" stroke=\"\(paint.stroke ?? "none")\" "
                       + "stroke-width=\"\(f(paint.width))\" stroke-linejoin=\"round\"\(dash(paint))\(turn(paint, Metrics.center(steps)))/>")
        case let .text(run):
            let spin = run.rotation == 0 ? "" : " transform=\"rotate(\(f(run.rotation)) \(f(run.origin.x)) \(f(run.origin.y)))\""
            let family = run.role == .sans ? "" : " font-family=\"\(esc(FontFace.family(run.role, in: fonts)))\""
            out.append("<text x=\"\(f(run.origin.x))\" y=\"\(f(run.origin.y))\" font-size=\"\(f(run.size))\" text-anchor=\"\(run.anchor.rawValue)\" "
                       + "font-weight=\"\(run.weight)\"\(family) fill=\"\(run.color)\"\(spin)>\(esc(run.text))</text>")
        case let .textBlock(block):
            let family = block.role == .sans ? "" : " font-family=\"\(esc(FontFace.family(block.role, in: fonts)))\""
            for laid in Typeset.lay(block, fonts).lines {
                out.append("<text x=\"\(f(laid.x))\" y=\"\(f(laid.y))\" font-size=\"\(f(block.size))\" text-anchor=\"start\" "
                           + "font-weight=\"\(block.weight)\"\(family) fill=\"\(block.color)\">\(esc(laid.text))</text>")
            }
        case let .image(picture):
            let frame = picture.frame
            let source = picture.bytes.map { "data:\(mime($0));base64,\($0.base64EncodedString())" } ?? picture.url?.absoluteString ?? ""
            out.append("<image x=\"\(f(frame.minX))\" y=\"\(f(frame.minY))\" width=\"\(f(frame.width))\" "
                       + "height=\"\(f(frame.height))\" preserveAspectRatio=\"xMidYMid meet\"\(picture.opacity == 1 ? "" : " opacity=\"\(f(picture.opacity))\"") "
                       + "href=\"\(esc(source))\"/>")
        case let .group(transform, items):
            var attributes = ""
            var moves: [String] = []
            if transform.dx != 0 || transform.dy != 0 { moves.append("translate(\(f(transform.dx)) \(f(transform.dy)))") }
            if transform.rotation != 0 { moves.append("rotate(\(f(transform.rotation)))") }
            if transform.scale != 1 { moves.append("scale(\(f(transform.scale)))") }
            if !moves.isEmpty { attributes += " transform=\"\(moves.joined(separator: " "))\"" }
            if let clip = transform.clip {
                clips += 1
                out.append("<clipPath id=\"\(scope)\(clips)\"><rect x=\"\(f(clip.minX))\" y=\"\(f(clip.minY))\" width=\"\(f(clip.width))\" height=\"\(f(clip.height))\"/></clipPath>")
                attributes += " clip-path=\"url(#\(scope)\(clips))\""
            }
            out.append("<g\(attributes)>")
            for child in items { emit(child, fonts, &out, &clips, scope) }
            out.append("</g>")
        }
    }

    static func dash(_ paint: Paint) -> String {
        paint.dash.isEmpty ? "" : " stroke-dasharray=\"\(paint.dash.map { f($0) }.joined(separator: " "))\""
    }

    static func turn(_ paint: Paint, _ c: CGPoint) -> String {
        paint.rotation == 0 ? "" : " transform=\"rotate(\(f(paint.rotation)) \(f(c.x)) \(f(c.y)))\""
    }

    static func d(_ steps: [Step]) -> String {
        steps.map { step -> String in
            switch step {
            case let .move(p): return "M \(f(p.x)) \(f(p.y))"
            case let .line(p): return "L \(f(p.x)) \(f(p.y))"
            case let .curve(a, b, c): return "C \(f(a.x)) \(f(a.y)) \(f(b.x)) \(f(b.y)) \(f(c.x)) \(f(c.y))"
            case .close: return "Z"
            }
        }.joined(separator: " ")
    }

    static func mime(_ data: Data) -> String {
        data.starts(with: [0xff, 0xd8]) ? "image/jpeg" : "image/png"
    }

    static func f(_ v: Double) -> String { String(format: "%.2f", v) }
    static func f(_ v: CGFloat) -> String { f(Double(v)) }

    static func esc(_ t: String) -> String {
        t.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;")
    }
}
