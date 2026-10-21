import CoreGraphics
import Foundation
import Pages

extension Composer {
    mutating func put(_ text: String, at p: CGPoint, size: Double, mono: Bool = false, anchor: Anchor = .start,
                      color: String? = nil, rotation: Double = 0) {
        guard !text.isEmpty else { return }
        sheet.items.append(.raw(.text(Run(text, origin: p, size: size, color: color ?? r.ci.ink, anchor: anchor,
                                          rotation: rotation, role: mono ? .mono : .sans))))
    }

    mutating func rule(_ a: CGPoint, _ b: CGPoint, width: Double, color: String) {
        sheet.items.append(.raw(.line(a, b, Paint(stroke: color, width: width))))
    }

    mutating func box(_ rect: CGRect, width: Double, color: String? = nil, rotation: Double = 0) {
        sheet.items.append(.raw(.rect(rect, Paint(stroke: color ?? r.ci.ink, width: width, rotation: rotation))))
    }

    func size(_ tier: TemplatePack.Tier) -> Double {
        switch tier {
        case .title: return r.ci.textTitle
        case .value: return r.ci.textValue
        case .note: return r.ci.textNote
        case .label: return r.ci.textLabel
        case .dim: return r.ci.textDimension
        case .mark: return r.ci.textMark
        }
    }

    func values() -> [String: String] {
        let t = r.template
        var v = r.project
        v["scale"] = scaleLabel ?? (r.layout == .iso && r.iso.distance != nil ? t.noScale : "1:\(Int(sheet.scale))")
        v["format"] = v["format"] ?? t.format
        v["layout"] = v["layout.\(r.product)"] ?? v["layout.\(r.layout.rawValue)"] ?? ""
        v["page"] = v["page"] ?? "\(r.number)"
        if v["zip"] == nil, let city = v["city"] {
            let parts = city.split(separator: " ", maxSplits: 1).map(String.init)
            if let first = parts.first, first.allSatisfy(\.isNumber) {
                v["zip"] = first
                v["town"] = parts.count > 1 ? parts[1] : ""
            } else {
                v["town"] = city
            }
        }
        return v
    }

    func expand(_ text: String, _ v: [String: String]) -> String {
        var out = text
        for (key, value) in v { out = out.replacingOccurrences(of: "{\(key)}", with: value) }
        while let open = out.firstIndex(of: "{"), let close = out[open...].firstIndex(of: "}") {
            out.removeSubrange(open...close)
        }
        return out
    }

    static func wrap(_ text: String, room: Int) -> [String] {
        guard room > 0 else { return [text] }
        var lines: [String] = [], current = ""
        for word in text.split(separator: " ") {
            var rest = String(word)
            if !current.isEmpty, current.count + 1 + rest.count <= room {
                current += " " + rest
                continue
            }
            if !current.isEmpty {
                lines.append(current)
                current = ""
            }
            while rest.count > room {
                lines.append(String(rest.prefix(room)))
                rest = String(rest.dropFirst(room))
            }
            current = rest
        }
        lines.append(current)
        return lines
    }

    mutating func studioColumn() {
        guard let c = r.template.column else { return }
        let ci = r.ci, x = c.left, w = c.width
        box(CGRect(x: x, y: c.blocks.top, width: w, height: c.blocks.height), width: ci.lineBlock)
        panels(c)
        box(CGRect(x: x, y: c.notes.top, width: w, height: c.notes.height), width: ci.lineBlock)
        for (i, note) in r.template.block.notes.enumerated() {
            put(note, at: CGPoint(x: c.notes.x, y: c.notes.top + c.notes.base + Double(i) * c.notes.step), size: ci.textNote)
        }
        grid(c, values())
        seal()
        logo(cover: false)
    }

    private func lines(_ entry: Entry, _ c: TemplatePack.Column) -> [String] {
        let room = Int((c.width - 2 * c.inset) / (r.ci.textDimension * c.blocks.glyph))
        let head = entry.label.isEmpty ? "" : entry.label.uppercased() + ": "
        return Composer.wrap(head + entry.value, room: room)
    }

    private mutating func panels(_ c: TemplatePack.Column) {
        let b = c.blocks, ci = r.ci, x = c.left, w = c.width
        let needs = r.blocks.map { $0.rows.reduce(0) { $0 + lines($1, c).count } }
        var quota = r.blocks.indices.map { max(needs[$0], r.blocks[$0].quota ?? (b.split.indices.contains($0) ? b.split[$0] : 0)) }
        let total = quota.reduce(r.blocks.count) { $0 + $1 }
        if total > b.rows, !sheet.defects.contains("template.column.blocks") { sheet.defects.append("template.column.blocks") }
        if total < b.rows, !quota.isEmpty { quota[quota.count - 1] += b.rows - total }
        var y = b.top
        for (index, panel) in r.blocks.enumerated() {
            box(CGRect(x: x, y: y, width: w, height: b.head), width: ci.lineEdge)
            put(panel.title, at: CGPoint(x: x + c.inset, y: y + b.headBase), size: ci.textValue)
            y += b.head
            var row = 0
            for entry in panel.rows {
                for (n, text) in lines(entry, c).enumerated() {
                    put(text, at: CGPoint(x: x + c.inset, y: y + Double(row + n) * b.row + b.rowBase), size: ci.textDimension, mono: true)
                }
                row += lines(entry, c).count
            }
            for k in 0..<quota[index] where k < quota[index] - 1 {
                let at = y + Double(k + 1) * b.row
                rule(CGPoint(x: x, y: at), CGPoint(x: x + w, y: at), width: ci.lineRow, color: ci.colorRow)
            }
            y += Double(quota[index]) * b.row
        }
    }

    private mutating func grid(_ c: TemplatePack.Column, _ v: [String: String]) {
        let t = c.title, ci = r.ci
        box(CGRect(x: c.left, y: t.top, width: c.width, height: t.height), width: ci.lineBlock)
        var y = t.top
        for (index, band) in t.bands.enumerated() {
            if index > 0 {
                rule(CGPoint(x: c.left, y: y), CGPoint(x: c.left + c.width, y: y),
                     width: band.heavy ? ci.lineBlock : ci.lineCell, color: band.heavy ? ci.ink : ci.colorCell)
            }
            var x = c.left
            for (n, slot) in band.slots.enumerated() {
                if n > 0, band.cut { rule(CGPoint(x: x, y: y), CGPoint(x: x, y: y + band.height), width: ci.lineCell, color: ci.colorCell) }
                for piece in slot.pieces { place(piece, v, x: x, y: y) }
                x += slot.width
            }
            y += band.height
        }
    }

    private mutating func place(_ p: TemplatePack.Piece, _ v: [String: String], x: Double, y: Double) {
        let value = p.literal.isEmpty ? (v[p.key] ?? "") : expand(p.literal, v)
        let at = CGPoint(x: x + p.x, y: y + p.base), s = size(p.tier)
        guard !p.label.isEmpty else { return put(value, at: at, size: s, mono: p.mono) }
        if p.gap > 0 {
            put(p.label, at: at, size: s, mono: p.mono)
            put(value, at: CGPoint(x: at.x + p.gap, y: at.y), size: s, mono: p.mono)
        } else {
            put(value.isEmpty ? p.label : p.label + " " + value, at: at, size: s, mono: p.mono)
        }
    }

    private mutating func seal() {
        let pr = r.template.presentation, ci = r.ci
        guard let s = r.template.seal, !pr.stamp.isEmpty,
              let status = r.project["status"]?.trimmingCharacters(in: .whitespaces).lowercased(),
              pr.stampStatuses.contains(status) else { return }
        box(CGRect(x: s.x - s.width / 2, y: s.y - s.height / 2, width: s.width, height: s.height),
            width: ci.lineBlock, color: ci.signal, rotation: -s.angle)
        let turn = -s.angle * .pi / 180, drop = pr.stampSize * 0.35
        put(pr.stamp, at: CGPoint(x: s.x - drop * sin(turn), y: s.y + drop * cos(turn)), size: pr.stampSize,
            anchor: .middle, color: ci.signal, rotation: -s.angle)
    }

    mutating func logo(cover: Bool) {
        guard let l = r.template.logo, cover || !l.cover else { return }
        if let data = l.data {
            sheet.items.append(.raw(.image(Picture(data: data, frame: l.frame))))
        } else {
            put(values()["wordmark"] ?? "", at: CGPoint(x: l.x, y: l.base), size: l.size > 0 ? l.size : r.ci.textMark, mono: true, anchor: l.anchor)
        }
    }
}
