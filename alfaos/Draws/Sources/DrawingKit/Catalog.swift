import CoreGraphics
import Foundation

public enum Catalog {
    public struct Entry: Sendable {
        public var name: String
        public var size: Kitchen.Size
        public var parts: [Part]
    }

    public static let margin = 15.0
    public static let pad = 4.0
    public static let labelRoom = 13.0
    public static let nameLine = 4.2
    public static let sizeLine = 8.6
    public static let ink = "#000000"
    public static let paper = "#ffffff"
    public static let sizeFormat = "%g × %g × %g mm"
    public static let scaleFormat = "1:%d"

    public static func entries(_ spec: KitchenSpec, pack: KitchenPack) throws -> [Entry] {
        let built = try Kitchen.generate(spec, pack: pack)
        let sizes = try Kitchen.sizes(spec, pack: pack)
        var out: [Entry] = []
        for (run, items) in spec.all.map(\.items).enumerated() {
            let named = items.indices.filter { !(items[$0].name ?? "").isEmpty }
            guard let first = named.first, named.count == 1 else { throw KitchenError.empty }
            let parts = built.parts.filter { part in
                guard let slot = Kitchen.slot(part.id, prefix: spec.prefix ?? ""), slot.run == run else { return false }
                return slot.item.map { $0 == first } ?? (named.count == items.count)
            }
            let floor = parts.map(\.z).min() ?? 0
            out.append(Entry(name: items[first].name ?? "", size: sizes[run][first],
                             parts: parts.map { part in var p = part; p.z -= floor; return p }))
        }
        return out
    }

    public static func style(_ ci: CIPack) -> IsoStyle {
        var s = ci.iso
        s.shadow = 0
        s.faces = Array(repeating: paper, count: 3)
        s.accent = nil
        return s
    }

    public static func sheet(_ entries: [Entry], ci: CIPack, template: TemplatePack, fonts: SheetFonts,
                             page: CGSize, cols: Int) throws -> Sheet {
        guard !entries.isEmpty, cols > 0, page.width > 0, page.height > 0 else { throw DrawingError.empty }
        var ci = ci
        ci.ink = ink
        ci.paper = paper
        var t = template
        t.width = Double(page.width)
        t.height = Double(page.height)
        let rows = (entries.count + cols - 1) / cols
        let cellW = (Double(page.width) - 2 * margin) / Double(cols)
        let cellH = (Double(page.height) - 2 * margin) / Double(rows)
        let roomW = cellW - 2 * pad, roomH = cellH - labelRoom - 2 * pad
        let iso = ViewSpec(kind: .iso)
        let s = style(ci)
        var reach: [(w: Double, h: Double)] = []
        for e in entries {
            let faces = try Projection.faces(e.parts, spec: iso)
            let xs = faces.flatMap { $0.poly.map { Double($0.x) } }, ys = faces.flatMap { $0.poly.map { Double($0.y) } }
            guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { throw DrawingError.empty }
            reach.append((x1 - x0, y1 - y0))
        }
        let n = reach.map { max($0.w / roomW, $0.h / roomH) }.max().map { $0.rounded(.up) } ?? 0
        guard n.isFinite, n > 0 else { throw DrawingError.overflow }
        var sheet = Sheet(width: t.width, height: t.height, scale: n, fonts: fonts, paper: paper, items: [], dimensions: [], defects: [])
        for (index, e) in entries.enumerated() {
            let col = index % cols, row = index / cols
            let cell = CGRect(x: margin + Double(col) * cellW, y: margin + Double(row) * cellH, width: cellW, height: cellH)
            let drawn = reach[index].h / n
            let room = CGRect(x: cell.minX + pad, y: cell.minY + pad + (roomH - drawn), width: roomW, height: drawn)
            var request = Request(parts: e.parts, ci: ci, template: t, project: [:], layout: .iso, iso: iso, dimensions: false,
                                  style: s, fonts: fonts)
            request.product = "iso"
            var sub = Composer(request, frame: false)
            _ = try sub.isoDraw(in: room, title: .zero, scales: [n], force: true)
            sheet.items += sub.sheet.items.dropLast()
            let mid = cell.midX, base = cell.minY + 2 * pad + roomH
            sheet.items.append(.text(e.name, at: CGPoint(x: mid, y: base + nameLine), size: ci.textValue, anchor: .middle,
                                     weight: ci.weightTitle, color: ink, rotation: 0))
            let size = String(format: sizeFormat, e.size.width, e.size.height, e.size.depth)
            sheet.items.append(.text(size, at: CGPoint(x: mid, y: base + sizeLine), size: ci.textNote, anchor: .middle,
                                     weight: 400, color: ink, rotation: 0))
        }
        sheet.items.append(.text(String(format: scaleFormat, Int(n)), at: CGPoint(x: Double(page.width) - margin, y: Double(page.height) - margin / 2),
                                 size: ci.textValue, anchor: .end, weight: ci.weightTitle, color: ink, rotation: 0))
        return sheet
    }
}
