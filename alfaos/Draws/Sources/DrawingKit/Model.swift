import CoreGraphics
import Foundation

public enum DrawingError: Error, Equatable, Sendable {
    case empty
    case duplicateID(String)
    case invalidPart(String)
    case tooLarge(String)
    case unsupportedView(String)
    case invalidCamera
    case overflow
    case pack([String])
}

public struct Part: Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var material: String
    public var x: Double, y: Double, z: Double
    public var w: Double, d: Double, h: Double

    public init(id: String, name: String, material: String,
                x: Double, y: Double, z: Double, w: Double, d: Double, h: Double) {
        self.id = id; self.name = name; self.material = material
        self.x = x; self.y = y; self.z = z; self.w = w; self.d = d; self.h = h
    }

    var maxX: Double { x + w }
    var maxY: Double { y + d }
    var maxZ: Double { z + h }

    func low(_ axis: Int) -> Double { axis == 0 ? x : (axis == 1 ? y : z) }
    func high(_ axis: Int) -> Double { axis == 0 ? maxX : (axis == 1 ? maxY : maxZ) }
    func center(_ axis: Int) -> Double { (low(axis) + high(axis)) / 2 }
}

public struct DrawingObject: Codable, Sendable {
    public var parts: [Part]
    public var project: [String: String]?
    public init(parts: [Part], project: [String: String]? = nil) { self.parts = parts; self.project = project }

    public static func load(_ url: URL) throws -> DrawingObject {
        try JSONDecoder().decode(DrawingObject.self, from: Data(contentsOf: url))
    }
}

public enum Validate {
    public static let limit = 100_000.0

    public static func parts(_ ps: [Part]) throws {
        guard !ps.isEmpty else { throw DrawingError.empty }
        var seen = Set<String>()
        for p in ps {
            if !seen.insert(p.id).inserted { throw DrawingError.duplicateID(p.id) }
            let values = [p.x, p.y, p.z, p.w, p.d, p.h]
            guard values.allSatisfy({ $0.isFinite && abs($0) <= limit }) else { throw DrawingError.tooLarge(p.id) }
            guard p.w > 0, p.d > 0, p.h > 0 else { throw DrawingError.invalidPart(p.id) }
        }
    }
}

public enum ViewKind: String, Codable, Sendable, CaseIterable {
    case front, back, top, left, right, iso, perspective
}

public struct ViewSpec: Codable, Sendable, Equatable {
    public var kind: ViewKind
    public var azimuth: Double
    public var elevation: Double
    public var distance: Double?

    public static let isoElevation = 35.264

    public init(kind: ViewKind, azimuth: Double = 45, elevation: Double = ViewSpec.isoElevation, distance: Double? = nil) {
        self.kind = kind; self.azimuth = azimuth; self.elevation = elevation; self.distance = distance
    }

    enum CodingKeys: String, CodingKey { case kind, azimuth, elevation, distance }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        kind = try c.decode(ViewKind.self, forKey: .kind)
        azimuth = try c.decodeIfPresent(Double.self, forKey: .azimuth) ?? 45
        elevation = try c.decodeIfPresent(Double.self, forKey: .elevation) ?? ViewSpec.isoElevation
        distance = try c.decodeIfPresent(Double.self, forKey: .distance)
    }
}

public struct Face2D: Sendable {
    public var poly: [CGPoint]
    public var partID: String
    public var normal: Int
    public init(poly: [CGPoint], partID: String, normal: Int) {
        self.poly = poly; self.partID = partID; self.normal = normal
    }
}

public enum ProjectionMethod: String, Codable, Sendable { case first, third }
