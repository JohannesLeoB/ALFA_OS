import Foundation

typealias Vec = (Double, Double, Double)

func axisValue(_ v: Vec, _ axis: Int) -> Double { axis == 0 ? v.0 : (axis == 1 ? v.1 : v.2) }

public enum TurnAxis: String, Codable, Sendable { case x, y, z }

public struct Point3: Codable, Hashable, Sendable {
    public var x: Double, y: Double, z: Double
    public init(x: Double, y: Double, z: Double) { self.x = x; self.y = y; self.z = z }
}

public struct Turn: Codable, Hashable, Sendable {
    public var pivot: Point3
    public var axis: TurnAxis
    public var deg: Double
    public init(pivot: Point3, axis: TurnAxis, deg: Double) { self.pivot = pivot; self.axis = axis; self.deg = deg }

    func tilt(_ v: Vec) -> Vec {
        let t = deg * .pi / 180, c = cos(t), s = sin(t)
        switch axis {
        case .x: return (v.0, c * v.1 - s * v.2, s * v.1 + c * v.2)
        case .y: return (c * v.0 + s * v.2, v.1, c * v.2 - s * v.0)
        case .z: return (c * v.0 - s * v.1, s * v.0 + c * v.1, v.2)
        }
    }

    func spin(_ p: Vec) -> Vec {
        let r = tilt((p.0 - pivot.x, p.1 - pivot.y, p.2 - pivot.z))
        return (pivot.x + r.0, pivot.y + r.1, pivot.z + r.2)
    }
}

public enum UnitKind: String, Codable, Sendable, CaseIterable { case drawer, pullout, door, flap, fixed }

public enum Motion: Codable, Hashable, Sendable {
    case slide(dx: Double, dy: Double, dz: Double)
    case hinge(pivot: Point3, axis: TurnAxis, degrees: Double)

    enum Kind: String, Codable { case slide, hinge }
    enum CodingKeys: String, CodingKey { case type, dx, dy, dz, px, py, pz, axis, deg }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(Kind.self, forKey: .type) {
        case .slide:
            self = .slide(dx: try c.decodeIfPresent(Double.self, forKey: .dx) ?? 0,
                          dy: try c.decodeIfPresent(Double.self, forKey: .dy) ?? 0,
                          dz: try c.decodeIfPresent(Double.self, forKey: .dz) ?? 0)
        case .hinge:
            self = .hinge(pivot: Point3(x: try c.decode(Double.self, forKey: .px), y: try c.decode(Double.self, forKey: .py),
                                        z: try c.decode(Double.self, forKey: .pz)),
                          axis: try c.decode(TurnAxis.self, forKey: .axis), degrees: try c.decode(Double.self, forKey: .deg))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .slide(dx, dy, dz):
            try c.encode(Kind.slide, forKey: .type)
            try c.encode(dx, forKey: .dx); try c.encode(dy, forKey: .dy); try c.encode(dz, forKey: .dz)
        case let .hinge(pivot, axis, degrees):
            try c.encode(Kind.hinge, forKey: .type)
            try c.encode(pivot.x, forKey: .px); try c.encode(pivot.y, forKey: .py); try c.encode(pivot.z, forKey: .pz)
            try c.encode(axis, forKey: .axis); try c.encode(degrees, forKey: .deg)
        }
    }

    var sound: Bool {
        switch self {
        case let .slide(dx, dy, dz): return [dx, dy, dz].allSatisfy { $0.isFinite && abs($0) <= Validate.limit }
        case let .hinge(p, _, degrees):
            return [p.x, p.y, p.z].allSatisfy { $0.isFinite && abs($0) <= Validate.limit } && degrees.isFinite && abs(degrees) <= 360
        }
    }

    var travel: Double {
        switch self {
        case let .slide(dx, dy, dz): return (dx * dx + dy * dy + dz * dz).squareRoot()
        case let .hinge(_, _, degrees): return abs(degrees)
        }
    }

    var measure: Measure {
        switch self {
        case .slide: return .mm
        case .hinge: return .deg
        }
    }
}

public struct Unit: Codable, Hashable, Sendable {
    public var id: String
    public var kind: UnitKind
    public var front: [String]
    public var body: [String]
    public var motion: Motion
    public init(id: String, kind: UnitKind, front: [String], body: [String] = [], motion: Motion) {
        self.id = id; self.kind = kind; self.front = front; self.body = body; self.motion = motion
    }
}

public extension Validate {
    static func units(_ units: [Unit], parts: [Part]) throws {
        let known = Set(parts.map(\.id))
        var seen = Set<String>(), owned = Set<String>()
        for u in units {
            if !seen.insert(u.id).inserted { throw DrawingError.duplicateID(u.id) }
            guard !u.front.isEmpty, u.motion.sound else { throw DrawingError.invalidUnit(u.id) }
            for id in u.front + u.body {
                guard known.contains(id) else { throw DrawingError.invalidPart(id) }
                if !owned.insert(id).inserted { throw DrawingError.sharedPart(id) }
            }
        }
    }

    static func pose(_ amounts: [String: Double], units: [Unit]) throws {
        let known = Set(units.map(\.id))
        for (id, amount) in amounts where !known.contains(id) || !(0...1).contains(amount) {
            throw DrawingError.invalidUnit(id)
        }
    }
}

public func pose(_ parts: [Part], _ units: [Unit], amounts: [String: Double]) -> [Part] {
    var out = parts
    let index = Dictionary(parts.enumerated().map { ($1.id, $0) }, uniquingKeysWith: { first, _ in first })
    for u in units {
        guard let raw = amounts[u.id], raw.isFinite, raw > 0 else { continue }
        let a = min(1, raw)
        for id in u.front + u.body {
            guard let i = index[id] else { continue }
            switch u.motion {
            case let .slide(dx, dy, dz):
                out[i].x += dx * a; out[i].y += dy * a; out[i].z += dz * a
                out[i].turn?.pivot.x += dx * a; out[i].turn?.pivot.y += dy * a; out[i].turn?.pivot.z += dz * a
            case let .hinge(pivot, axis, degrees):
                out[i].turn = Turn(pivot: pivot, axis: axis, deg: degrees * a)
            }
        }
    }
    return out
}

public func openFronts(_ units: [Unit], amounts: [String: Double]) -> Set<String> {
    Set(units.filter { (amounts[$0.id] ?? 0) > 0 }.flatMap(\.front))
}

public enum Measure: String, Sendable { case mm, deg }

public struct Readout: Equatable, Sendable {
    public var unit: String
    public var kind: UnitKind
    public var width: Double
    public var fronts: Int
    public var measure: Measure
    public var now: Double
    public var max: Double
    public var step: Int
    public var total: Int

    public static func make(_ parts: [Part], _ units: [Unit], amounts: [String: Double]) -> [Readout] {
        units.enumerated().map { index, u in
            let ps = parts.filter { u.front.contains($0.id) }
            let spans = (0...1).map { axis in
                (ps.map { $0.high(axis) }.max() ?? 0) - (ps.map { $0.low(axis) }.min() ?? 0)
            }
            let a = Swift.min(1, Swift.max(0, amounts[u.id] ?? 0))
            return Readout(unit: u.id, kind: u.kind, width: spans.max() ?? 0, fronts: u.front.count,
                           measure: u.motion.measure, now: u.motion.travel * a, max: u.motion.travel,
                           step: index + 1, total: units.count)
        }
    }
}
