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
        try Validate.units(job.units, parts: job.parts)
        try Validate.pose(job.pose, units: job.units)
        guard !job.products.isEmpty else { throw DrawingError.empty }
        var out: [Sheet] = []
        var panels = job.blocks
        if let title = job.template.column?.blocks.materials, !title.isEmpty, !panels.contains(where: { $0.title == title }) {
            panels.append(materials(job, title: title))
        }
        for (index, product) in job.products.enumerated() {
            var base = Request(parts: job.parts, ci: job.ci, template: job.template, project: job.project,
                               layout: .iso, dimensions: job.dimensions, style: job.style, fonts: job.fonts)
            base.product = product.key
            base.scale = job.scale
            base.blocks = panels
            base.number = index + 1
            base.units = job.units
            base.pose = job.pose
            base.hold = job.hold
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
            case .presentation:
                var c = Composer(base)
                try c.presentation(job)
                c.titleBlock()
                c.sheet.product = base.product
                out.append(c.sheet)
            case .board(let cells, let view):
                base.iso = view
                var c = Composer(base)
                try c.board(cells)
                c.titleBlock()
                c.sheet.product = base.product
                out.append(c.sheet)
            case .cover:
                guard job.template.deck != nil else { throw DrawingError.pack(["template.deck"]) }
                var c = Composer(base)
                c.furniture(cover: true)
                c.sheet.product = base.product
                out.append(c.sheet)
            }
        }
        return out
    }

    static func materials(_ job: Job, title: String) -> Panel {
        let variant = job.variants.first ?? Variant(id: "", name: "", slots: [:])
        var groups: [String: [String]] = [:]
        for p in job.parts {
            let keys = [p.role, p.material].compactMap { $0 }
            let code = keys.lazy.compactMap { variant.slots[$0] }.first ?? keys.lazy.compactMap { job.material?.slots[$0] }.first
            let role = (p.role ?? p.name).uppercased()
            if !(groups[code ?? p.material]?.contains(role) ?? false) { groups[code ?? p.material, default: []].append(role) }
        }
        let rows = groups.sorted { $0.key < $1.key }.map { key, roles in
            Entry(label: roles.joined(separator: ", "), value: job.material?.material(key)?.name ?? key)
        }
        return Panel(title: title, rows: rows)
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
    var scaleLabel: String?

    init(_ r: Request, frame: Bool = true) {
        self.r = r
        let t = r.template, f = t.frame
        field = CGRect(x: f.left, y: f.top, width: t.width - f.left - f.right, height: t.height - f.top - f.bottom)
        sheet = Sheet(width: t.width, height: t.height, scale: 0, fonts: r.fonts, paper: r.ci.paper,
                      items: [], dimensions: [], defects: [])
        guard frame, t.deck == nil else { return }
        if let o = t.outer {
            let outer = CGRect(x: o.left, y: o.top, width: t.width - o.left - o.right, height: t.height - o.top - o.bottom)
            sheet.items.append(.rect(outer, fill: nil, stroke: r.ci.ink, width: r.ci.lineFrame))
            if t.divider {
                sheet.items.append(.line(CGPoint(x: field.maxX, y: field.minY), CGPoint(x: field.maxX, y: field.maxY),
                                         width: r.ci.lineFrame, color: r.ci.ink))
            }
        } else {
            sheet.items.append(.rect(field, fill: nil, stroke: r.ci.ink, width: r.ci.lineFrame))
        }
    }

    mutating func tint(_ material: String) -> String? {
        if let t = r.ci.tints[material], !t.isEmpty { return t }
        let defect = "ci.tints.\(material)"
        if !sheet.defects.contains(defect) { sheet.defects.append(defect) }
        return nil
    }

    mutating func threeView() throws {
        let t = r.template, kinds: [ViewKind] = [.front, .top, .right]
        var extents: [ViewKind: CGRect] = [:]
        for k in kinds {
            let e = Projection.extent(r.parts, k)
            extents[k] = k == .top ? e : e.union(CGRect(x: e.minX, y: 0, width: e.width, height: 0))
        }
        let n = try ScaleSolver.solve(sizes: extents.mapValues(\.size), method: t.method, gap: t.gap, band: t.band,
                                      field: field.size, steps: r.scale.map { [$0] } ?? t.scales)
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
        let material = Dictionary(uniqueKeysWithValues: r.parts.map { ($0.id, $0.material) })
        if Projection.hulls(r.parts) {
            for f in try Projection.faces(r.parts, spec: Projection.spec(k), flat: true) {
                let poly = f.poly.map { CGPoint(x: px(Double($0.x)), y: py(Double($0.y))) }
                sheet.items.append(.polygon(poly, fill: tint(material[f.partID] ?? ""), stroke: ci.ink, width: ci.lineEdge))
                sheet.picks.append(Pick(id: f.partID, polygon: poly))
            }
        } else {
            for entry in try Projection.visibleRects(r.parts, k).reversed() {
                let fill = tint(material[entry.id] ?? "")
                if !entry.rects.isEmpty, let p = r.parts.first(where: { $0.id == entry.id }) {
                    let box = paper(Projection.rect(p, k))
                    sheet.items.append(.rect(box, fill: fill, stroke: nil, width: 0))
                    sheet.picks.append(Pick(id: p.id, polygon: [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)]))
                }
                for (a, b) in Composer.outline(entry.rects) {
                    sheet.items.append(.line(CGPoint(x: px(Double(a.x)), y: py(Double(a.y))),
                                             CGPoint(x: px(Double(b.x)), y: py(Double(b.y))), width: ci.lineEdge, color: ci.ink))
                }
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

    static func outline(_ pieces: [CGRect]) -> [(CGPoint, CGPoint)] {
        let e = CGFloat(Order.epsilon)
        var out: [(CGPoint, CGPoint)] = []
        for (i, p) in pieces.enumerated() {
            let others = pieces.enumerated().filter { $0.offset != i }.map(\.element)
            let edges: [(fixed: CGFloat, from: CGFloat, to: CGFloat, horizontal: Bool, outside: (CGRect) -> CGFloat)] = [
                (p.minY, p.minX, p.maxX, true, { $0.maxY }), (p.maxY, p.minX, p.maxX, true, { $0.minY }),
                (p.minX, p.minY, p.maxY, false, { $0.maxX }), (p.maxX, p.minY, p.maxY, false, { $0.minX })
            ]
            for edge in edges {
                var free = [(edge.from, edge.to)]
                for o in others where abs(edge.outside(o) - edge.fixed) <= e {
                    let (lo, hi) = edge.horizontal ? (o.minX, o.maxX) : (o.minY, o.maxY)
                    free = free.flatMap { s -> [(CGFloat, CGFloat)] in
                        [(s.0, min(s.1, lo)), (max(s.0, hi), s.1)].filter { $0.1 - $0.0 > e }
                    }
                }
                for s in free {
                    out.append(edge.horizontal ? (CGPoint(x: s.0, y: edge.fixed), CGPoint(x: s.1, y: edge.fixed))
                                               : (CGPoint(x: edge.fixed, y: s.0), CGPoint(x: edge.fixed, y: s.1)))
                }
            }
        }
        return out
    }

    static let glyph = 0.72

    static func fit(_ text: String, width: Double, size: Double) -> String {
        let room = Int(max(0, width / (size * glyph)))
        guard text.count > room, room > 1 else { return text }
        return String(text.prefix(room - 1)) + "…"
    }

    mutating func dimension(from a: CGPoint, to b: CGPoint, extFrom ea: CGPoint, extFrom2 eb: CGPoint, text: String, rotation: Double) {
        if let d = r.template.dim { return styled(d, from: a, to: b, extFrom: ea, extFrom2: eb, text: text, rotation: rotation) }
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
        let t = r.template, m = t.isoMargin
        let room = CGRect(x: field.minX + m.left, y: field.minY + m.top,
                          width: field.width - m.left - m.right, height: field.height - m.top - m.bottom)
        _ = try isoDraw(in: room, title: CGPoint(x: field.minX + m.left, y: field.minY + t.titleOffset),
                        scales: r.scale.map { [$0] } ?? t.isoScales, force: false)
    }

    mutating func isoDraw(in room: CGRect, title at: CGPoint, scales: [Double], force: Bool) throws -> (scale: Double, fits: Bool) {
        let t = r.template, ci = r.ci, s = r.style ?? ci.iso
        let reach = r.hold ? Dictionary(r.units.map { ($0.id, 1.0) }, uniquingKeysWith: { first, _ in first }) : r.pose
        let shown = pose(r.parts, r.units, amounts: r.pose), fitted = (r.fit ?? (r.hold ? r.parts : nil)).map { pose($0, r.units, amounts: reach) }
        let open = openFronts(r.units, amounts: r.pose), fronts = Set(r.units.flatMap(\.front))
        let faces = try Projection.faces(shown, spec: r.iso, shadow: s.shadow > 0 ? s.spread : nil, around: fitted)
        let frame = try fitted.map { try Projection.faces($0, spec: r.iso, shadow: s.shadow > 0 ? s.spread : nil) } ?? faces
        let xs = frame.flatMap { $0.poly.map { Double($0.x) } }, ys = frame.flatMap { $0.poly.map { Double($0.y) } }
        guard let x0 = xs.min(), let x1 = xs.max(), let y0 = ys.min(), let y1 = ys.max() else { throw DrawingError.empty }
        let sorted = scales.sorted()
        let found = sorted.first(where: { (x1 - x0) / $0 <= room.width && (y1 - y0) / $0 <= room.height })
        guard let n = found ?? (force ? sorted.last : nil) else { throw DrawingError.overflow }
        sheet.scale = n
        let cx = room.minX + room.width / 2, cy = room.minY + room.height / 2
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
            let face = f.normal == 5 ? 0 : (f.normal == 2 || f.normal == 3 ? 1 : 2)
            let shade = [s.top, s.side, s.front][face]
            let lit = f.partID == s.accent || r.highlight.contains(f.partID) || open.contains(f.partID)
            let fill: String?
            if lit {
                fill = Hex.scale(s.accentColor ?? ci.accent, shade)
            } else if let tones = s.faces, tones.count == 3 {
                fill = tones[face]
            } else {
                fill = tint(material[f.partID] ?? "").map { Hex.scale($0, shade) }
            }
            let outline = paper(f)
            if fronts.contains(f.partID) { sheet.hits[f.partID, default: []].append(outline) }
            sheet.picks.append(Pick(id: f.partID, polygon: outline))
            sheet.items.append(.polygon(outline, fill: fill, stroke: ci.ink, width: s.edge))
        }
        let key = r.product.isEmpty ? "iso" : r.product
        let pattern = t.titles[key] ?? ""
        if pattern.isEmpty { sheet.defects.append("template.titles.\(key)") }
        let title = pattern
            .replacingOccurrences(of: "{az}", with: String(format: "%.0f", r.iso.azimuth))
            .replacingOccurrences(of: "{el}", with: String(format: "%.3f", r.iso.elevation))
            .replacingOccurrences(of: "{n}", with: "\(r.step.0)")
            .replacingOccurrences(of: "{of}", with: "\(r.step.1)") + (r.iso.distance == nil ? "   1:\(Int(n))" : "")
        sheet.items.append(.text(title, at: at, size: ci.textTitle, anchor: .start, weight: ci.weightTitle, color: ci.ink, rotation: 0))
        return (n, found != nil)
    }

    mutating func styled(_ d: TemplatePack.Dim, from a: CGPoint, to b: CGPoint, extFrom ea: CGPoint, extFrom2 eb: CGPoint,
                         text: String, rotation: Double) {
        let ci = r.ci, ink = ci.colorDimension
        let length = hypot(b.x - a.x, b.y - a.y)
        let u = length > 0 ? CGPoint(x: (b.x - a.x) / length, y: (b.y - a.y) / length) : CGPoint(x: 1, y: 0)
        rule(CGPoint(x: a.x - u.x * d.stub, y: a.y - u.y * d.stub), CGPoint(x: b.x + u.x * d.stub, y: b.y + u.y * d.stub),
             width: ci.lineDimension, color: ink)
        let vertical = rotation != 0, half = d.tick / (2 * 2.0.squareRoot())
        for (end, ext) in [(a, ea), (b, eb)] {
            let over = vertical ? CGPoint(x: end.x - d.overrun, y: end.y) : CGPoint(x: end.x, y: end.y + d.overrun)
            rule(ext, over, width: ci.lineExtension, color: ink)
            rule(CGPoint(x: end.x - half, y: end.y + half), CGPoint(x: end.x + half, y: end.y - half), width: ci.lineTick, color: ink)
        }
        let mid = CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        put(text, at: vertical ? CGPoint(x: mid.x - d.text, y: mid.y) : CGPoint(x: mid.x, y: mid.y - d.text),
            size: ci.textDimension, mono: true, anchor: .middle, color: ink, rotation: rotation)
    }

    mutating func titleBlock() {
        if r.template.deck != nil { return furniture(cover: false) }
        if r.template.column != nil { return studioColumn() }
        let t = r.template, b = t.block, ci = r.ci
        let x = field.maxX + b.inset, w = t.frame.right - 2 * b.inset
        sheet.items.append(.rect(CGRect(x: x, y: field.minY, width: w, height: field.height), fill: nil, stroke: ci.ink, width: ci.lineBlock))
        for (i, note) in b.notes.enumerated() {
            sheet.items.append(.text(note, at: CGPoint(x: x + b.inset, y: field.minY + b.notesTop + Double(i) * b.notesStep),
                                     size: ci.textNote, anchor: .start, weight: i == 0 ? ci.weightTitle : 400, color: ci.ink, rotation: 0))
        }
        var values = r.project
        values["scale"] = scaleLabel ?? (r.layout == .iso && r.iso.distance != nil ? t.noScale : "1:\(Int(sheet.scale))")
        values["format"] = values["format"] ?? t.format
        var y = field.minY + b.rowsTop
        for row in b.rows {
            sheet.items.append(.line(CGPoint(x: x, y: y), CGPoint(x: x + w, y: y), width: ci.lineDimension, color: ci.ink))
            sheet.items.append(.text(row.label, at: CGPoint(x: x + b.inset, y: y + b.labelBaseline), size: ci.textLabel,
                                     anchor: .start, weight: 400, color: ci.muted, rotation: 0))
            let layout = values["layout.\(r.product)"] ?? values["layout.\(r.layout.rawValue)"] ?? ""
            let value = Composer.fit(row.key == "layout" ? layout : (values[row.key] ?? ""), width: w - 2 * b.inset, size: ci.textValue)
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
