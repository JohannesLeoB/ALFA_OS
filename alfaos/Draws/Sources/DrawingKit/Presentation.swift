import CoreGraphics
import Foundation

extension Composer {
    mutating func presentation(_ job: Job) throws {
        let t = r.template, pr = t.presentation, ci = r.ci
        let variants = job.variants.isEmpty ? [Variant(id: "", name: "", slots: [:])] : job.variants
        let raw = Projection.extent(r.parts, .front)
        let e = raw.union(CGRect(x: raw.minX, y: 0, width: raw.width, height: 0))
        let band = job.dims == .given ? t.band : 0
        let count = Double(variants.count)
        let column = (field.width - (count - 1) * pr.columnGap) / count
        let top = variants.contains { !$0.name.isEmpty } ? pr.titleGap : 0
        let roles = labels()
        let side = roles.isEmpty ? 0 : pr.labelGap + (roles.map { Double($0.text.count) }.max() ?? 0) * ci.textDimension * Composer.glyph
        guard let n = (r.scale.map { [$0] } ?? t.scales).sorted().first(where: { s in
            Double(e.width) / s <= column - 2 * band - side && Double(e.height) / s <= field.height - top - 2 * band - pr.stampSize
        }) else { throw DrawingError.overflow }
        sheet.scale = n
        let viewW = Double(e.width) / n, viewH = Double(e.height) / n
        let blockH = top + band + viewH + band
        let y0 = field.minY + pr.stampSize + (field.height - pr.stampSize - blockH) / 2
        for (i, v) in variants.enumerated() {
            let x0 = field.minX + Double(i) * (column + pr.columnGap) + (column - viewW - side) / 2
            let origin = CGPoint(x: x0, y: y0 + top + band)
            if !v.name.isEmpty {
                if t.deck != nil {
                    put(caps(v.name), at: CGPoint(x: x0, y: y0 + top / 2), size: ci.textCaption, mono: true)
                } else {
                    sheet.items.append(.text(v.name, at: CGPoint(x: x0, y: y0 + top / 2), size: ci.textTitle, anchor: .start,
                                             weight: ci.weightTitle, color: ci.ink, rotation: 0))
                }
            }
            try face(v, job, origin: origin, extent: e, scale: n)
            var last = -Double.infinity
            for label in roles {
                let y = max(origin.y + (Double(e.maxY) - label.z) / n + ci.textDimension / 2, last + pr.labelStep)
                last = y
                if t.deck != nil {
                    put(label.text, at: CGPoint(x: origin.x + viewW + pr.labelGap, y: y), size: ci.textCaption, mono: true)
                } else {
                    sheet.items.append(.text(label.text, at: CGPoint(x: origin.x + viewW + pr.labelGap, y: y),
                                             size: ci.textDimension, anchor: .start, weight: 400, color: ci.ink, rotation: 0))
                }
            }
            if job.dims == .given { totals(origin: origin, extent: e, scale: n) }
        }
        guard t.deck == nil, t.column == nil else { return }
        stamp()
        materialBlock(job, variants)
    }

    private mutating func face(_ v: Variant, _ job: Job, origin o: CGPoint, extent e: CGRect, scale n: Double) throws {
        func px(_ u: Double) -> Double { o.x + (u - Double(e.minX)) / n }
        func py(_ w: Double) -> Double { o.y + (Double(e.maxY) - w) / n }
        let shown = pose(r.parts, r.units, amounts: r.pose), open = openFronts(r.units, amounts: r.pose)
        let fronts = Set(r.units.flatMap(\.front))
        if Projection.hulls(shown) {
            for f in try Projection.faces(shown, spec: Projection.spec(.front), flat: true) {
                guard let p = shown.first(where: { $0.id == f.partID }) else { continue }
                let poly = f.poly.map { CGPoint(x: px(Double($0.x)), y: py(Double($0.y))) }
                sheet.items.append(.polygon(poly, fill: open.contains(p.id) ? (r.style ?? r.ci.iso).accentColor ?? r.ci.accent : tone(p, v, job),
                                            stroke: r.ci.ink, width: r.ci.lineEdge))
                if fronts.contains(p.id) { sheet.hits[p.id, default: []].append(poly) }
            }
            return
        }
        let visible = try Projection.visibleRects(shown, .front)
        for entry in visible.reversed() {
            guard !entry.rects.isEmpty, let p = shown.first(where: { $0.id == entry.id }) else { continue }
            let rect = Projection.rect(p, .front)
            let box = CGRect(x: px(Double(rect.minX)), y: py(Double(rect.maxY)), width: rect.width / n, height: rect.height / n)
            sheet.items.append(.rect(box, fill: open.contains(p.id) ? (r.style ?? r.ci.iso).accentColor ?? r.ci.accent : tone(p, v, job),
                                     stroke: nil, width: 0))
            if fronts.contains(p.id) {
                sheet.hits[p.id, default: []].append([CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY),
                                                      CGPoint(x: box.maxX, y: box.maxY), CGPoint(x: box.minX, y: box.maxY)])
            }
            for (a, b) in Composer.outline(entry.rects) {
                sheet.items.append(.line(CGPoint(x: px(Double(a.x)), y: py(Double(a.y))), CGPoint(x: px(Double(b.x)), y: py(Double(b.y))),
                                         width: r.ci.lineEdge, color: r.ci.ink))
            }
        }
    }

    func code(_ p: Part, _ v: Variant, _ job: Job) -> String? {
        let keys = [p.role, p.material].compactMap { $0 }
        return keys.lazy.compactMap { v.slots[$0] }.first ?? keys.lazy.compactMap { job.material?.slots[$0] }.first
    }

    private mutating func tone(_ p: Part, _ v: Variant, _ job: Job) -> String? {
        if let c = code(p, v, job), let m = job.material?.material(c), !m.tone.isEmpty { return m.tone }
        return tint(p.material)
    }

    private func labels() -> [(text: String, z: Double)] {
        var spans: [String: (Double, Double)] = [:]
        for p in r.parts {
            guard let role = p.role else { continue }
            let old = spans[role] ?? (p.z, p.maxZ)
            spans[role] = (min(old.0, p.z), max(old.1, p.maxZ))
        }
        return spans.map { (text: $0.key.uppercased(), z: ($0.value.0 + $0.value.1) / 2) }
            .sorted { $0.z != $1.z ? $0.z > $1.z : $0.text < $1.text }
    }

    private mutating func totals(origin o: CGPoint, extent e: CGRect, scale n: Double) {
        let ci = r.ci, pad = r.template.presentation.totalPad, eps = Order.epsilon
        let width = r.parts.first { $0.isGiven("w") && abs($0.x - Double(e.minX)) < eps && abs($0.maxX - Double(e.maxX)) < eps }
        if let p = width {
            let y = o.y + Double(e.height) / n + r.template.chainOffset
            box(Dimensioner.label(p.w), at: CGPoint(x: o.x + Double(e.width) / n / 2, y: y - pad), rotation: 0)
            sheet.items.append(.line(CGPoint(x: o.x, y: y), CGPoint(x: o.x + Double(e.width) / n, y: y), width: ci.lineDimension, color: ci.ink))
        }
        let topPart = r.parts.filter { abs($0.maxZ - Double(e.maxY)) < eps }.first { $0.isGiven("z") && $0.isGiven("h") }
        if let p = topPart {
            let x = o.x - r.template.chainOffset
            box(Dimensioner.label(p.maxZ), at: CGPoint(x: x - pad, y: o.y + Double(e.height) / n / 2), rotation: -90)
            sheet.items.append(.line(CGPoint(x: x, y: o.y), CGPoint(x: x, y: o.y + Double(e.height) / n), width: ci.lineDimension, color: ci.ink))
        }
    }

    private mutating func box(_ text: String, at p: CGPoint, rotation: Double) {
        let ci = r.ci, pad = r.template.presentation.totalPad
        let w = Double(text.count) * ci.textDimension * Composer.glyph + 2 * pad, h = ci.textDimension + 2 * pad
        let rect = rotation == 0 ? CGRect(x: p.x - w / 2, y: p.y - h + pad, width: w, height: h)
                                 : CGRect(x: p.x - h + pad, y: p.y - w / 2, width: h, height: w)
        sheet.items.append(.rect(rect, fill: ci.paper, stroke: ci.ink, width: ci.lineDimension))
        sheet.items.append(.text(text, at: p, size: ci.textDimension, anchor: .middle, weight: 400, color: ci.ink, rotation: rotation))
    }

    private mutating func stamp() {
        let pr = r.template.presentation
        guard let status = r.project["status"], pr.stampStatuses.contains(status) else { return }
        sheet.items.append(.text(pr.stamp, at: CGPoint(x: field.maxX - r.template.block.inset, y: field.minY + pr.stampSize),
                                 size: pr.stampSize, anchor: .end, weight: r.ci.weightTitle, color: r.ci.ink, rotation: 0))
    }

    private mutating func materialBlock(_ job: Job, _ variants: [Variant]) {
        let t = r.template, b = t.block, pr = t.presentation, ci = r.ci
        let x = field.maxX + b.inset, w = t.frame.right - 2 * b.inset
        var y = field.minY + b.rowsTop + Double(b.rows.count) * b.rowHeight + pr.blockGap
        let limit = field.maxY - b.footerHeight
        for v in variants {
            if !v.name.isEmpty {
                sheet.items.append(.text(Composer.fit(v.name, width: w - 2 * b.inset, size: ci.textValue), at: CGPoint(x: x + b.inset, y: y),
                                         size: ci.textValue, anchor: .start, weight: ci.weightTitle, color: ci.ink, rotation: 0))
                y += pr.blockRow
            }
            var groups: [String: [String]] = [:]
            for p in r.parts {
                let key = code(p, v, job) ?? p.material
                let role = (p.role ?? p.name).uppercased()
                if !(groups[key]?.contains(role) ?? false) { groups[key, default: []].append(role) }
            }
            for (key, roles) in groups.sorted(by: { $0.key < $1.key }) {
                let m = job.material?.material(key)
                let name = (m?.name ?? key).uppercased()
                let fill = m.flatMap { $0.tone.isEmpty ? nil : $0.tone } ?? ci.tints[key]
                sheet.items.append(.rect(CGRect(x: x + b.inset, y: y - pr.swatch, width: pr.swatch, height: pr.swatch),
                                         fill: fill, stroke: ci.ink, width: ci.lineDimension))
                let text = roles.joined(separator: ", ") + " – " + name
                sheet.items.append(.text(Composer.fit(text, width: w - 3 * b.inset - pr.swatch, size: ci.textNote),
                                         at: CGPoint(x: x + 2 * b.inset + pr.swatch, y: y), size: ci.textNote, anchor: .start, weight: 400,
                                         color: ci.ink, rotation: 0))
                y += pr.blockRow
            }
            y += pr.blockGap / 2
        }
        if y > limit, !sheet.defects.contains("template.presentation.block") { sheet.defects.append("template.presentation.block") }
    }
}
