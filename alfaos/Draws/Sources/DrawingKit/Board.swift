import CoreGraphics
import Foundation

extension Composer {
    mutating func board(_ cells: [Cell]) throws {
        guard !cells.isEmpty else { throw DrawingError.empty }
        var ids = Set<String>(), scales: [Double] = []
        for cell in cells {
            guard ids.insert(cell.id).inserted else { throw DrawingError.duplicateID(cell.id) }
            let (request, count) = try cellRequest(cell)
            var sub = Composer(request, frame: false)
            let (scale, fits) = try sub.cellDraw(cell)
            sheet.items += sub.sheet.items
            sheet.dimensions += sub.sheet.dimensions
            for defect in sub.sheet.defects where !sheet.defects.contains(defect) { sheet.defects.append(defect) }
            if !fits { sheet.defects.append("board.\(cell.id)") }
            sheet.cells.append(Placed(id: cell.id, scale: scale, fits: fits, steps: count))
            if cell.view != .perspective, !scales.contains(scale) { scales.append(scale) }
        }
        scaleLabel = scales.isEmpty ? r.template.noScale : scales.map { "1:\(Int($0))" }.joined(separator: " · ")
        sheet.scale = scales.first ?? 0
    }

    private func cellRequest(_ cell: Cell) throws -> (Request, Int) {
        var parts = r.parts
        if let id = cell.focus {
            parts = parts.filter { $0.id == id }
            guard !parts.isEmpty else { throw DrawingError.invalidPart(id) }
        }
        if let s = cell.scale, !(s.isFinite && s > 0) { throw DrawingError.overflow }
        var q = r
        q.parts = parts
        q.scale = cell.scale
        q.dimensions = cell.dims
        q.highlight = []
        q.fit = nil
        q.step = (0, 0)
        guard cell.view == .iso || cell.view == .perspective else {
            q.layout = .threeView
            return (q, 0)
        }
        let perspective = cell.view == .perspective
        q.layout = .iso
        q.iso = ViewSpec(kind: cell.view, azimuth: r.iso.azimuth, elevation: r.iso.elevation, distance: perspective ? r.iso.distance : nil)
        q.product = perspective ? "perspective" : "iso"
        let all = try DrawingEngine.steps([], parts)
        if cell.step >= 1 {
            let index = min(cell.step, all.count) - 1
            q.parts = all[index].parts
            q.highlight = all[index].added
            q.fit = parts
            q.step = (index + 1, all.count)
            q.product = "steps"
        }
        return (q, all.count)
    }

    private mutating func cellDraw(_ cell: Cell) throws -> (Double, Bool) {
        let t = r.template, f = cell.frame
        if r.layout == .iso {
            let room = CGRect(x: f.minX, y: f.minY + 2 * t.titleOffset, width: f.width, height: f.height - 2 * t.titleOffset)
            let drawn = try isoDraw(in: room, title: CGPoint(x: f.minX, y: f.minY + t.titleOffset),
                                    scales: r.scale.map { [$0] } ?? t.isoScales, force: true)
            return (drawn.scale, drawn.fits)
        }
        let raw = Projection.extent(r.parts, cell.view)
        let e = cell.view == .top ? raw : raw.union(CGRect(x: raw.minX, y: 0, width: raw.width, height: 0))
        let sorted = (r.scale.map { [$0] } ?? t.scales).sorted()
        let found = sorted.first { Double(e.width) / $0 + 2 * t.band <= f.width && Double(e.height) / $0 + 2 * t.band <= f.height }
        guard let n = found ?? sorted.last else { throw DrawingError.overflow }
        let w = Double(e.width) / n + 2 * t.band, h = Double(e.height) / n + 2 * t.band
        try view(cell.view, at: CGPoint(x: f.minX + (f.width - w) / 2, y: f.minY + (f.height - h) / 2), extent: e, scale: n)
        return (n, found != nil)
    }
}
