import CoreGraphics
import DrawingKit
import Foundation
import Intake

public enum Prepare {
    static let noteLimit = 6000
    static let paletteCount = 5
    static let pages = 6
    static let edges = 12
    static let captions = 20
    static let spans = 20
    static let snippet = 40

    public static func brief(_ brief: Brief) async -> Brief {
        var next = brief
        next.attachments = []
        for item in brief.attachments { next.attachments.append(await attachment(item)) }
        return next
    }

    public static func attachment(_ a: Attachment) async -> Attachment {
        guard a.note.isEmpty, let item = try? await ingest(data: a.data, name: a.name) else { return a }
        var out = a
        switch item.kind {
        case .dxf:
            out.note = dxf(item.drawing)
        case .idml:
            out.note = layout(item)
        case .pdf, .png, .jpeg, .gif, .webp:
            switch a.role {
            case .moodboard: out.note = moodboard(item, a.data)
            case .template: out.note = layout(item)
            case .drawing: out.note = words(item)
            case .material: out.note = moodboard(item, a.data)
            case .sketch, .reference: break
            }
        default: break
        }
        if item.kind == .dxf || item.kind == .idml {
            out.mediaType = Attachment.text
            out.data = Data()
        }
        out.note = String(out.note.prefix(noteLimit))
        return out
    }

    public static func underlay(_ a: Attachment, side: Int) -> Data? {
        if Attachment.images.contains(a.mediaType) { return a.data }
        return a.mediaType == Attachment.document ? raster(ofPDF: a.data, page: 0, side: side) : nil
    }

    public static func suggest(_ data: Data, tones: [String: String], among codes: [String]) -> String? {
        guard let hex = palette(of: data, count: 1).first, let target = rgb(hex) else { return nil }
        var best: (code: String, gap: Int)?
        for code in codes.sorted() {
            guard let tone = tones[code], let value = rgb(tone) else { continue }
            let gap = (value.0 - target.0) * (value.0 - target.0) + (value.1 - target.1) * (value.1 - target.1)
                + (value.2 - target.2) * (value.2 - target.2)
            if gap < (best?.gap ?? Int.max) { best = (code, gap) }
        }
        return best?.code
    }

    static func rgb(_ hex: String) -> (Int, Int, Int)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = Int(s, radix: 16) else { return nil }
        return ((v >> 16) & 255, (v >> 8) & 255, v & 255)
    }

    static func flat(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " | ")
    }

    static func num(_ v: Double) -> String {
        let r = (v * 10).rounded() / 10
        return r == r.rounded() ? String(Int(r)) : String(r)
    }

    static func box(_ r: CGRect, _ k: Double) -> String {
        [r.minX, r.minY, r.width, r.height].map { num(Double($0) * k) }.joined(separator: ",")
    }

    static func words(_ item: Ingested) -> String {
        let text = flat(item.text)
        return text.isEmpty ? "" : "text: " + text
    }

    static func moodboard(_ item: Ingested, _ data: Data) -> String {
        var lines: [String] = []
        let text = flat(item.text)
        if !text.isEmpty { lines.append("text: " + text) }
        let sets = item.kind == .pdf ? palettes(ofPDF: data, count: paletteCount, pages: pages) : [palette(of: data, count: paletteCount)]
        for (index, set) in sets.enumerated() where !set.isEmpty {
            lines.append("palette \(index + 1): " + set.joined(separator: " "))
        }
        return lines.joined(separator: "\n")
    }

    static func layout(_ item: Ingested) -> String {
        var lines: [String] = []
        if let book = item.layout {
            for folio in book.spreads.flatMap(\.pages) {
                lines.append("page \(folio.name) \(num(folio.size.width)) x \(num(folio.size.height)) mm")
                for frame in folio.frames.prefix(spans) {
                    let text = frame.text.isEmpty ? "" : " \"" + flat(String(frame.text.prefix(snippet))) + "\""
                    lines.append("\(frame.kind.rawValue) \(box(frame.rect, 1))\(text)")
                }
            }
            return lines.joined(separator: "\n")
        }
        let k = item.kind == .pdf ? 25.4 / 72 : 1
        let unit = item.kind == .pdf ? "mm" : "px"
        for leaf in item.pages {
            lines.append("page \(leaf.index + 1) \(num(Double(leaf.size.width) * k)) x \(num(Double(leaf.size.height) * k)) \(unit)")
            for run in leaf.runs.prefix(spans) {
                lines.append("zone \(box(run.rect, k)) \"" + flat(String(run.text.prefix(snippet))) + "\"")
            }
        }
        return lines.joined(separator: "\n")
    }

    struct Edge {
        var from: CGPoint
        var to: CGPoint

        var length: Double { Double(hypot(to.x - from.x, to.y - from.y)) }
        var key: [Double] { [Double(from.x), Double(from.y), Double(to.x), Double(to.y)] }
    }

    static func longer(_ a: Edge, _ b: Edge) -> Bool {
        if a.length != b.length { return a.length > b.length }
        return a.key.lexicographicallyPrecedes(b.key)
    }

    static func dxf(_ drawing: Drawing?) -> String {
        guard let d = drawing else { return "" }
        var edges = d.segments.map { Edge(from: $0.from, to: $0.to) }
        for line in d.polylines {
            edges += zip(line.points, line.points.dropFirst()).map { Edge(from: $0, to: $1) }
            if line.closed, line.points.count > 2, let first = line.points.first, let last = line.points.last {
                edges.append(Edge(from: last, to: first))
            }
        }
        var points = edges.flatMap { [$0.from, $0.to] } + d.captions.map(\.at)
        for round in d.rounds {
            points.append(CGPoint(x: round.center.x - round.radius, y: round.center.y - round.radius))
            points.append(CGPoint(x: round.center.x + round.radius, y: round.center.y + round.radius))
        }
        var lines = ["units \(d.units)", "layers " + d.layers.joined(separator: " ")]
        if let x0 = points.map(\.x).min(), let x1 = points.map(\.x).max(), let y0 = points.map(\.y).min(), let y1 = points.map(\.y).max() {
            lines.append("extent \(num(Double(x0))),\(num(Double(y0))) to \(num(Double(x1))),\(num(Double(y1))) size \(num(Double(x1 - x0))) x \(num(Double(y1 - y0)))")
        }
        lines.append("lines \(d.segments.count) polylines \(d.polylines.count) rounds \(d.rounds.count) texts \(d.captions.count)")
        for edge in edges.sorted(by: longer).prefix(Self.edges) {
            lines.append("line \(num(Double(edge.from.x))),\(num(Double(edge.from.y))) to \(num(Double(edge.to.x))),\(num(Double(edge.to.y))) length \(num(edge.length))")
        }
        for caption in d.captions.prefix(captions) {
            lines.append("text \"\(flat(caption.text))\" at \(num(Double(caption.at.x))),\(num(Double(caption.at.y))) height \(num(caption.height))")
        }
        return lines.joined(separator: "\n")
    }
}
