import CoreGraphics
import Foundation

public enum DrawingEngine {
    public static func render(_ r: Request) throws -> Sheet {
        try Validate.parts(r.parts)
        var c = Composer(r)
        switch r.layout {
        case .threeView: try c.threeView()
        case .iso: try c.iso()
        }
        c.titleBlock()
        c.sheet.product = r.product
        return c.sheet
    }

    public static func render(_ job: Job) throws -> [Sheet] {
        try Validate.parts(job.parts)
        guard !job.products.isEmpty else { throw DrawingError.empty }
        var out: [Sheet] = []
        for product in job.products {
            var base = Request(parts: job.parts, ci: job.ci, template: job.template, project: job.project,
                               layout: .iso, dimensions: job.dimensions, style: job.style)
            base.product = product.key
            switch product {
            case .plan:
                base.layout = .threeView
                out.append(try render(base))
            case .iso(let view), .customer(let view):
                base.iso = view
                out.append(try render(base))
            case .steps(let view, let groups):
                base.iso = view
                base.fit = job.parts
                let all = try steps(groups, job.parts)
                for (index, step) in all.enumerated() {
                    var r = base
                    r.parts = step.parts
                    r.highlight = step.added
                    r.step = (index + 1, all.count)
                    out.append(try render(r))
                }
            }
        }
        return out
    }

    static func steps(_ groups: [[String]], _ parts: [Part]) throws -> [(parts: [Part], added: Set<String>)] {
        let ids = Set(parts.map(\.id))
        var resolved = groups
        if resolved.isEmpty {
            let levels = Set(parts.map(\.z)).sorted()
            resolved = levels.map { z in parts.filter { $0.z == z }.map(\.id) }
        }
        for id in resolved.joined() where !ids.contains(id) { throw DrawingError.invalidPart(id) }
        var shown = Set<String>()
        return resolved.map { group in
            shown.formUnion(group)
            return (parts.filter { shown.contains($0.id) }, Set(group))
        }
    }
}

struct ViewBox { var w: Double; var h: Double }

enum Placement {
    static func layout(method: ProjectionMethod, front: ViewBox, top: ViewBox, side: ViewBox,
                       gap: Double) -> (origins: [ViewKind: CGPoint], extent: CGSize) {
        switch method {
        case .first:
            let ox = side.w + gap
            let width = ox + max(front.w, top.w)
            return ([.front: CGPoint(x: ox, y: 0), .top: CGPoint(x: ox, y: front.h + gap), .right: CGPoint(x: 0, y: 0)],
                    CGSize(width: width, height: max(front.h + gap + top.h, side.h)))
        case .third:
            let oy = top.h + gap
            return ([.front: CGPoint(x: 0, y: oy), .top: CGPoint(x: 0, y: 0), .right: CGPoint(x: front.w + gap, y: oy)],
                    CGSize(width: max(front.w + gap + side.w, top.w), height: oy + max(front.h, side.h)))
        }
    }
}

enum ScaleSolver {
    static func solve(sizes: [ViewKind: CGSize], method: ProjectionMethod, gap: Double, band: Double,
                      field: CGSize, steps: [Double]) throws -> Double {
        for n in steps.sorted() {
            let l = Placement.layout(method: method, front: box(sizes[.front], n, band), top: box(sizes[.top], n, band),
                                     side: box(sizes[.right], n, band), gap: gap)
            if l.extent.width <= field.width, l.extent.height <= field.height { return n }
        }
        throw DrawingError.overflow
    }

    static func box(_ s: CGSize?, _ n: Double, _ band: Double) -> ViewBox {
        ViewBox(w: Double(s?.width ?? 0) / n + 2 * band, h: Double(s?.height ?? 0) / n + 2 * band)
    }
}

struct Composer {
    let r: Request
    var sheet: Sheet
    let field: CGRect

    init(_ r: Request) {
        self.r = r
        let t = r.template, f = t.frame
        field = CGRect(x: f.left, y: f.top, width: t.width - f.left - f.right, height: t.height - f.top - f.bottom)
        sheet = Sheet(width: t.width, height: t.height, scale: 0, font: r.ci.font, pdfFont: r.ci.pdfFont, paper: r.ci.paper,
                      items: [], dimensions: [], defects: [])
        sheet.items.append(.rect(field, fill: nil, stroke: r.ci.ink, width: r.ci.lineFrame))
    }

    mutating func tint(_ material: String) -> String? {
        if let t = r.ci.tints[material] { return t }
        let defect = "ci.tints.\(material)"
        if !sheet.defects.contains(defect) { sheet.defects.append(defect) }
        return nil
    }

    mutating func threeView() throws {
        let t = r.template, kinds: [ViewKind] = [.front, .top, .right]
        var extents: [ViewKind: CGRect] = [:]
        for k in kinds { extents[k] = Projection.extent(r.parts, k) }
        let n = try ScaleSolver.solve(sizes: extents.mapValues(\.size), method: t.method, gap: t.gap, band: t.band,
                                      field: field.size, steps: t.scales)
        sheet.scale = n
        func box(_ k: ViewKind) -> ViewBox { ScaleSolver.box(extents[k]?.size, n, t.band) }
        let l = Placement.layout(method: t.method, front: box(.front), top: box(.top), side: box(.right), gap: t.gap)
        let origin = CGPoint(x: field.minX + (field.width - l.extent.width) / 2, y: field.minY + (field.height - l.extent.height) / 2)
        for k in kinds {
            guard let o = l.origins[k], let e = extents[k] else { continue }
            try view(k, at: CGPoint(x: origin.x + o.x, y: origin.y + o.y), extent: e, scale: n)
        }
    }

    mutating func view(_ k: ViewKind, at o: CGPoint, extent e: CGRect, scale n: Double) throws {
        let t = r.template, ci = r.ci
        let band = t.band
        func px(_ u: Double) -> Double { o.x + band + (u - e.minX) / n }
        func py(_ v: Double) -> Double { o.y + band + (e.maxY - v) / n }
        func paper(_ rect: CGRect) -> CGRect {
            CGRect(x: px(rect.minX), y: py(rect.maxY), width: rect.width / n, height: rect.height / n)
        }
        let visible = try Projection.visibleRects(r.parts, k)
        let material = Dictionary(uniqueKeysWithValues: r.parts.map { ($0.id, $0.material) })
        for entry in visible.reversed() {
            let fill = tint(material[entry.id] ?? "")
            for piece in entry.rects {
                sheet.items.append(.rect(paper(piece), fill: fill, stroke: ci.ink, width: ci.lineEdge))
            }
        }
        let title = t.viewTitles[k.rawValue] ?? ""
        if title.isEmpty { sheet.defects.append("template.viewTitles.\(k.rawValue)") }
        sheet.items.append(.text("\(title)  1:\(Int(n))", at: CGPoint(x: o.x + band, y: o.y + band - t.titleOffset),
                                 size: ci.textTitle, anchor: .start, weight: ci.weightTitle, color: ci.ink, rotation: 0))
        guard r.dimensions else { return }
        let rects = r.parts.map { Projection.rect($0, k) }
        let us = rects.flatMap { [Double($0.minX), Double($0.maxX)] }
        let vs = rects.flatMap { [Double($0.minY), Double($0.maxY)] }
        let horizontal = Dimensioner.chain(edges: us, scale: n, minPaperLen: t.minPaperLength,
                                           baseOffset: t.chainOffset, step: t.chainStep, horizontal: true)
        let vertical = Dimensioner.chain(edges: vs, datum: k == .top ? nil : 0, scale: n, minPaperLen: t.minPaperLength,
                                         baseOffset: t.chainOffset, step: t.chainStep, horizontal: false)
        let bottom = py(e.minY), left = px(e.minX)
        for d in horizontal {
            sheet.dimensions.append(PlacedDimension(view: k, dimension: d))
            let y = bottom + d.offsetPaper, a = px(d.from), b = px(d.to)
            dimension(from: CGPoint(x: a, y: y), to: CGPoint(x: b, y: y),
                      extFrom: CGPoint(x: a, y: bottom + t.extensionGap), extFrom2: CGPoint(x: b, y: bottom + t.extensionGap),
                      text: d.text, rotation: 0)
        }
        for d in vertical {
            sheet.dimensions.append(PlacedDimension(view: k, dimension: d))
            let x = left - d.offsetPaper, a = py(d.from), b = py(d.to)
            dimension(from: CGPoint(x: x, y: a), to: CGPoint(x: x, y: b),
                      extFrom: CGPoint(x: left - t.extensionGap, y: a), extFrom2: CGPoint(x: left - t.extensionGap, y: b),
                      text: d.text, rotation: -90)
        }
    }

    mutating func dimension(from a: CGPoint, to b: CGPoint, extFrom ea: CGPoint, extFrom2 eb: CGPoint, text: String, rotation: Double) {
        let ci = r.ci, tk = r.template.tick
        sheet.items.append(.line(a, b, width: ci.lineDimension, color: ci.ink))
        let vertical = rotation != 0
        for (end, ext) in [(a, ea), (b, eb)] {
            let over = vertical ? CGPoint(x: end.x - tk, y: end.y) : CGPoint(x: end.x, y: end.y + tk)
            sheet.items.append(.line(ext, over, width: ci.lineExtension, color: ci.ink))
            sheet.items.append(.line(CGPoint(x: end.x - tk / 2, y: end.y + tk / 2), CGPoint(x: end.x + tk / 2, y: end.y - tk / 2),
                                     width: ci.lineTick, color: ci.ink))
        }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        let at = vertical ? CGPoint(x: mid.x - tk / 2, y: mid.y) : CGPoint(x: mid.x, y: mid.y - tk / 2)
        sheet.items.append(.text(text, at: at, size: ci.textDimension, anchor: .middle, weight: 400, color: ci.ink, rotation: rotation))
    }

    mutating func iso() throws {
        let t = r.template, ci = r.ci, s = r.style ?? ci.iso
        let faces = try Projection.faces(r.parts, spec: r.iso, shadow: s.shadow > 0 ? s.spread : nil, around: r.fit)
        let frame = try r.fit.map { try Projection.faces($0, spec: r.iso, shadow: s.shadow > 0 ? s.spread : nil) } ?? faces
        let xs = frame.flatMap { $0.poly.map { Double($0.x) } }, ys = frame.flatMap { $0.poly.map { Double($0.y) } }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { throw DrawingError.empty }
        let room = CGSize(width: field.width - t.isoMargin.left - t.isoMargin.right,
                          height: field.height - t.isoMargin.top - t.isoMargin.bottom)
        guard let n = t.isoScales.sorted().first(where: { (x1 - x0) / $0 <= room.width && (y1 - y0) / $0 <= room.height }) else {
            throw DrawingError.overflow
        }
        sheet.scale = n
        let cx = field.minX + t.isoMargin.left + room.width / 2, cy = field.minY + t.isoMargin.top + room.height / 2
        let mx = (x0 + x1) / 2, my = (y0 + y1) / 2
        let material = Dictionary(uniqueKeysWithValues: r.parts.map { ($0.id, $0.material) })
        func paper(_ f: Face2D) -> [CGPoint] {
            f.poly.map { CGPoint(x: cx + (Double($0.x) - mx) / n, y: cy - (Double($0.y) - my) / n) }
        }
        let shadows = faces.filter { $0.normal == Projection.shadowNormal }
        let solids = faces.filter { $0.normal != Projection.shadowNormal }
        for f in shadows {
            sheet.items.append(.polygon(paper(f), fill: Hex.mix(ci.ink, ci.paper, s.shadow), stroke: nil, width: 0))
        }
        if s.outline > 0 {
            for f in solids {
                sheet.items.append(.polygon(paper(f), fill: ci.ink, stroke: ci.ink, width: 2 * s.outline))
            }
        }
        for f in solids {
            let shade: Double = f.normal == 5 ? s.top : (f.normal == 2 || f.normal == 3 ? s.side : s.front)
            let lit = f.partID == s.accent || r.highlight.contains(f.partID)
            let base = lit ? ci.accent : tint(material[f.partID] ?? "")
            sheet.items.append(.polygon(paper(f), fill: base.map { Hex.scale($0, shade) }, stroke: ci.ink, width: s.edge))
        }
        let key = r.product.isEmpty ? "iso" : r.product
        let pattern = t.titles[key] ?? ""
        if pattern.isEmpty { sheet.defects.append("template.titles.\(key)") }
        let title = pattern
            .replacingOccurrences(of: "{az}", with: String(format: "%.0f", r.iso.azimuth))
            .replacingOccurrences(of: "{el}", with: String(format: "%.3f", r.iso.elevation))
            .replacingOccurrences(of: "{n}", with: "\(r.step.0)")
            .replacingOccurrences(of: "{of}", with: "\(r.step.1)") + "   1:\(Int(n))"
        sheet.items.append(.text(title, at: CGPoint(x: field.minX + t.isoMargin.left, y: field.minY + t.titleOffset),
                                 size: ci.textTitle, anchor: .start, weight: ci.weightTitle, color: ci.ink, rotation: 0))
    }

    mutating func titleBlock() {
        let t = r.template, b = t.block, ci = r.ci
        let x = field.maxX + b.inset, w = t.frame.right - 2 * b.inset
        sheet.items.append(.rect(CGRect(x: x, y: field.minY, width: w, height: field.height), fill: nil, stroke: ci.ink, width: ci.lineBlock))
        for (i, note) in b.notes.enumerated() {
            sheet.items.append(.text(note, at: CGPoint(x: x + b.inset, y: field.minY + b.notesTop + Double(i) * b.notesStep),
                                     size: ci.textNote, anchor: .start, weight: i == 0 ? ci.weightTitle : 400, color: ci.ink, rotation: 0))
        }
        var values = r.project
        values["scale"] = "1:\(Int(sheet.scale))"
        values["format"] = values["format"] ?? t.format
        var y = field.minY + b.rowsTop
        for row in b.rows {
            sheet.items.append(.line(CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), width: ci.lineDimension, color: ci.ink))
            sheet.items.append(.text(row.label, at: CGPoint(x: x + b.inset, y: y + b.labelBaseline), size: ci.textLabel,
                                     anchor: .start, weight: 400, color: ci.muted, rotation: 0))
            let layout = values["layout.\(r.product)"] ?? values["layout.\(r.layout.rawValue)"] ?? ""
            let value = row.key == "layout" ? layout : (values[row.key] ?? "")
            sheet.items.append(.text(value, at: CGPoint(x: x + b.inset, y: y + b.valueBaseline), size: ci.textValue,
                                     anchor: .start, weight: ci.weightTitle, color: ci.ink, rotation: 0))
            y += b.rowHeight
        }
        let footer = field.maxY - b.footerHeight
        sheet.items.append(.line(CGPoint(x: x, y: footer), CGPoint(x: x + w, y: footer), width: ci.lineBlock, color: ci.ink))
        for (i, line) in b.footer.enumerated() {
            sheet.items.append(.text(line, at: CGPoint(x: x + b.inset, y: footer + b.footerStep * Double(i + 1)),
                                     size: i == 0 ? ci.textValue : ci.textNote, anchor: .start, weight: i == 0 ? ci.weightTitle : 400,
                                     color: ci.ink, rotation: 0))
        }
        if r.ci.placeholder || t.placeholder {
            sheet.items.append(.text(b.stamp, at: CGPoint(x: x + b.inset, y: field.maxY - b.inset), size: ci.textLabel,
                                     anchor: .start, weight: 400, color: ci.signal, rotation: 0))
        }
    }
}

enum Hex {
    static func rgb(_ hex: String) -> (Double, Double, Double)? {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        return (Double((v >> 16) & 0xff) / 255, Double((v >> 8) & 0xff) / 255, Double(v & 0xff) / 255)
    }

    static func scale(_ hex: String, _ k: Double) -> String {
        guard let c = rgb(hex) else { return hex }
        func byte(_ v: Double) -> Int { Int((min(1, max(0, v * k)) * 255).rounded(.down)) }
        return String(format: "#%02x%02x%02x", byte(c.0), byte(c.1), byte(c.2))
    }

    static func mix(_ a: String, _ b: String, _ k: Double) -> String {
        guard let x = rgb(a), let y = rgb(b) else { return b }
        let t = min(1, max(0, k))
        func byte(_ u: Double, _ v: Double) -> Int { Int(((u * t + v * (1 - t)) * 255).rounded()) }
        return String(format: "#%02x%02x%02x", byte(x.0, y.0), byte(x.1, y.1), byte(x.2, y.2))
    }
}
