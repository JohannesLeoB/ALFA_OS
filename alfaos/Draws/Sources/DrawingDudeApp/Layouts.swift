import CoreGraphics
import DrawingKit

enum CellForm: String, CaseIterable {
    case ortho, iso, perspective
}

extension Cell {
    var form: CellForm {
        switch view {
        case .iso: return .iso
        case .perspective: return .perspective
        default: return .ortho
        }
    }

    mutating func become(_ next: CellForm) {
        guard next != form else { return }
        let flat = form == .ortho
        switch next {
        case .ortho: view = .front
        case .iso: view = .iso
        case .perspective: view = .perspective
        }
        if flat != (next == .ortho) { scale = nil }
        if next != .ortho { dims = false }
    }
}

struct Guide: Hashable {
    let vertical: Bool
    let at: Double
}

struct Grip {
    let id: String
    var moved = false
}

enum Corner: CaseIterable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    var right: Bool { self == .topTrailing || self == .bottomTrailing }
    var bottom: Bool { self == .bottomLeading || self == .bottomTrailing }
}

enum Presets {
    static func cells(_ kind: Kind, field f: CGRect, gap g: Double, steps: Int) -> [Cell] {
        let cw = ((f.width - g) / 2).rounded(), ch = ((f.height - g) / 2).rounded()
        func cell(_ n: Int, _ view: ViewKind, _ x: Double, _ y: Double, _ w: Double, _ h: Double, step: Int = 0) -> Cell {
            Cell(id: "v\(n)", view: view, frame: CGRect(x: x.rounded(), y: y.rounded(), width: w.rounded(), height: h.rounded()),
                 step: step, dims: view != .iso && view != .perspective)
        }
        switch kind {
        case .presentation, .cover:
            return []
        case .iso:
            return [cell(1, .iso, f.minX, f.minY, f.width, f.height)]
        case .perspective:
            return [cell(1, .perspective, f.minX, f.minY, f.width, f.height)]
        case .steps:
            let n = max(1, steps)
            let cols = f.width > f.height * Proto.stepsRatio ? n : (n == 1 ? 1 : Int(Double(n).squareRoot().rounded(.up)))
            let rows = (n + cols - 1) / cols
            let w = (f.width - Double(cols - 1) * g) / Double(cols), h = (f.height - Double(rows - 1) * g) / Double(rows)
            return (0..<n).map { i in
                cell(i + 1, .iso, f.minX + Double(i % cols) * (w + g), f.minY + Double(i / cols) * (h + g), w, h, step: i + 1)
            }
        case .customer:
            let big = (f.width - g) * Proto.customerShare, rw = f.width - big - g
            return [cell(1, .iso, f.minX, f.minY, big, f.height),
                    cell(2, .front, f.minX + big + g, f.minY, rw, ch),
                    cell(3, .perspective, f.minX + big + g, f.minY + ch + g, rw, ch)]
        case .plan:
            return [cell(1, .front, f.minX, f.minY, cw, ch),
                    cell(2, .right, f.minX + cw + g, f.minY, cw, ch),
                    cell(3, .top, f.minX, f.minY + ch + g, cw, ch),
                    cell(4, .iso, f.minX + cw + g, f.minY + ch + g, cw, ch)]
        }
    }
}

enum Snap {
    static func grid(_ v: Double, origin: Double) -> Double {
        origin + ((v - origin) / Proto.grid).rounded() * Proto.grid
    }

    static func move(_ start: CGRect, by d: CGSize, others: [CGRect], field: CGRect, sheet: CGSize,
                     reach: Double) -> (frame: CGRect, guides: [Guide]) {
        var x = grid(start.minX + d.width, origin: field.minX)
        var y = grid(start.minY + d.height, origin: field.minY)
        var guides: [Guide] = []
        let xs: [Double] = [field.minX, field.maxX] + others.flatMap { [$0.minX, $0.maxX, $0.midX] as [Double] }
        let ys: [Double] = [field.minY, field.maxY] + others.flatMap { [$0.minY, $0.maxY, $0.midY] as [Double] }
        if let hit = nearest(xs, [x, x + start.width, x + start.width / 2], reach: reach) {
            x += hit.shift
            guides.append(Guide(vertical: true, at: hit.at))
        }
        if let hit = nearest(ys, [y, y + start.height, y + start.height / 2], reach: reach) {
            y += hit.shift
            guides.append(Guide(vertical: false, at: hit.at))
        }
        x = min(max(0, x), max(0, sheet.width - start.width))
        y = min(max(0, y), max(0, sheet.height - start.height))
        return (CGRect(x: x, y: y, width: start.width, height: start.height), guides)
    }

    static func resize(_ start: CGRect, corner: Corner, by d: CGSize, field: CGRect, sheet: CGSize) -> CGRect {
        let (x0, x1) = axis(start.minX, start.maxX, high: corner.right, delta: d.width, origin: field.minX, limit: sheet.width)
        let (y0, y1) = axis(start.minY, start.maxY, high: corner.bottom, delta: d.height, origin: field.minY, limit: sheet.height)
        return CGRect(x: x0, y: y0, width: x1 - x0, height: y1 - y0)
    }

    private static func axis(_ lo: Double, _ hi: Double, high: Bool, delta: Double, origin: Double,
                             limit: Double) -> (Double, Double) {
        if high { return (lo, min(limit, max(lo + Proto.minCell, grid(hi + delta, origin: origin)))) }
        return (min(hi - Proto.minCell, max(0, grid(lo + delta, origin: origin))), hi)
    }

    private static func nearest(_ targets: [Double], _ values: [Double], reach: Double) -> (shift: Double, at: Double)? {
        var best: (shift: Double, at: Double)?
        for value in values {
            for target in targets {
                let shift = target - value
                if abs(shift) <= reach, abs(shift) < abs(best?.shift ?? .infinity) { best = (shift, target) }
            }
        }
        return best
    }
}
