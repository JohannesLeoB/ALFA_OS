import Foundation

public enum Slope: String, Codable, Sendable { case x, y }

public enum Shape: Codable, Hashable, Sendable {
    case wedge(slope: Slope, start: Double, end: Double)
    case taper(bottomW: Double, bottomD: Double, topW: Double, topD: Double)

    enum Kind: String, Codable { case wedge, taper }
    enum CodingKeys: String, CodingKey { case kind, slope, start, end, bottomW, bottomD, topW, topD }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .kind) {
        case .wedge:
            self = .wedge(slope: try c.decode(Slope.self, forKey: .slope), start: try c.decode(Double.self, forKey: .start),
                          end: try c.decode(Double.self, forKey: .end))
        case .taper:
            self = .taper(bottomW: try c.decode(Double.self, forKey: .bottomW), bottomD: try c.decode(Double.self, forKey: .bottomD),
                          topW: try c.decode(Double.self, forKey: .topW), topD: try c.decode(Double.self, forKey: .topD))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .wedge(slope, start, end):
            try c.encode(Kind.wedge, forKey: .kind)
            try c.encode(slope, forKey: .slope)
            try c.encode(start, forKey: .start)
            try c.encode(end, forKey: .end)
        case let .taper(bottomW, bottomD, topW, topD):
            try c.encode(Kind.taper, forKey: .kind)
            try c.encode(bottomW, forKey: .bottomW)
            try c.encode(bottomD, forKey: .bottomD)
            try c.encode(topW, forKey: .topW)
            try c.encode(topD, forKey: .topD)
        }
    }

    var numbers: [Double] {
        switch self {
        case let .wedge(_, start, end): return [start, end]
        case let .taper(bottomW, bottomD, topW, topD): return [bottomW, bottomD, topW, topD]
        }
    }

    func fits(w: Double, d: Double, h: Double) -> Bool {
        let e = Order.epsilon
        switch self {
        case let .wedge(_, start, end):
            return start >= 0 && end >= 0 && start <= h + e && end <= h + e && abs(max(start, end) - h) <= e
        case let .taper(bottomW, bottomD, topW, topD):
            return bottomW > 0 && bottomD > 0 && topW > 0 && topD > 0
                && abs(max(bottomW, topW) - w) <= e && abs(max(bottomD, topD) - d) <= e
        }
    }

    func grid(_ p: Part) -> [Vec] {
        var out: [Vec] = []
        for ix in 0...1 {
            for iy in 0...1 {
                for iz in 0...1 { out.append(corner(p, ix, iy, iz)) }
            }
        }
        return out
    }

    private func corner(_ p: Part, _ ix: Int, _ iy: Int, _ iz: Int) -> Vec {
        switch self {
        case let .wedge(slope, start, end):
            let height = iz == 0 ? 0 : (slope == .x ? (ix == 0 ? start : end) : (iy == 0 ? start : end))
            return (ix == 0 ? p.x : p.maxX, iy == 0 ? p.y : p.maxY, p.z + height)
        case let .taper(bottomW, bottomD, topW, topD):
            let w = iz == 0 ? bottomW : topW, d = iz == 0 ? bottomD : topD
            let x = p.x + (p.w - w) / 2, y = p.y + (p.d - d) / 2
            return (ix == 0 ? x : x + w, iy == 0 ? y : y + d, iz == 0 ? p.z : p.maxZ)
        }
    }

    static let faceIndex: [[Int]] = [[0, 4, 5, 1], [6, 2, 3, 7], [2, 0, 1, 3], [4, 6, 7, 5], [2, 6, 4, 0], [1, 5, 7, 3]]

    func faces(_ p: Part) -> [(Vec, [Vec])] {
        let g = grid(p)
        return Shape.faceIndex.compactMap { ids in
            var pts = ids.map { g[$0] }
            pts = pts.enumerated().filter { i, q in
                let prev = pts[(i + pts.count - 1) % pts.count]
                return abs(q.0 - prev.0) + abs(q.1 - prev.1) + abs(q.2 - prev.2) > Order.epsilon
            }.map(\.element)
            guard pts.count >= 3 else { return nil }
            var n: Vec = (0, 0, 0)
            for i in pts.indices {
                let a = pts[i], b = pts[(i + 1) % pts.count]
                n.0 += (a.1 - b.1) * (a.2 + b.2)
                n.1 += (a.2 - b.2) * (a.0 + b.0)
                n.2 += (a.0 - b.0) * (a.1 + b.1)
            }
            let len = (n.0 * n.0 + n.1 * n.1 + n.2 * n.2).squareRoot()
            guard len > Order.epsilon else { return nil }
            return ((n.0 / len, n.1 / len, n.2 / len), pts)
        }
    }
}
