import DrawingKit
import Foundation

public enum LightPreset: String, Sendable, CaseIterable, Codable {
    case studio, soft, warm, hard
}

public struct LightSpec: Sendable, Equatable, Codable {
    public var preset: LightPreset
    public var azimuth: Double?
    public var elevation: Double?

    public init(preset: LightPreset = .studio, azimuth: Double? = nil, elevation: Double? = nil) {
        self.preset = preset; self.azimuth = azimuth; self.elevation = elevation
    }
}

public struct Texture: Sendable, Equatable, Codable {
    public static let tile = 600.0
    public static let roughness = 0.6

    public var image: String
    public var normal: String?
    public var tile: Double
    public var roughness: Double

    public init(image: String, normal: String? = nil, tile: Double = Texture.tile, roughness: Double = Texture.roughness) {
        self.image = image; self.normal = normal; self.tile = tile; self.roughness = roughness
    }
}

public struct Look: Sendable, Equatable {
    public var textures: [String: Texture]
    public var light: LightSpec

    public init(textures: [String: Texture] = [:], light: LightSpec = LightSpec()) {
        self.textures = textures; self.light = light
    }

    public func surfaces(images: [String: Data], tones: [String: String], codes: [String]) -> [String: Surface] {
        var out: [String: Surface] = [:]
        for code in codes {
            let link = textures[code]
            out[code] = Surface(color: link.flatMap { images[$0.image] }, normal: link?.normal.flatMap { images[$0] },
                                tile: link?.tile ?? Texture.tile, roughness: link?.roughness ?? Texture.roughness,
                                tone: tones[code])
        }
        return out
    }
}

public struct Surface: Sendable, Equatable {
    public var color: Data?
    public var normal: Data?
    public var tile: Double
    public var roughness: Double
    public var tone: String?

    public init(color: Data? = nil, normal: Data? = nil, tile: Double = Texture.tile, roughness: Double = Texture.roughness,
                tone: String? = nil) {
        self.color = color; self.normal = normal; self.tile = tile; self.roughness = roughness; self.tone = tone
    }
}

public struct PhotoScene: Sendable {
    public var parts: [Part]
    public var surfaces: [String: Surface]
    public var light: LightSpec
    public var view: ViewSpec
    public var backdrop: Bool
    public var margin: Double

    public init(parts: [Part], surfaces: [String: Surface] = [:], light: LightSpec = LightSpec(),
                view: ViewSpec = ViewSpec(kind: .iso), backdrop: Bool = false, margin: Double = Rig.margin) {
        self.parts = parts; self.surfaces = surfaces; self.light = light; self.view = view
        self.backdrop = backdrop; self.margin = min(0.4, max(0, margin))
    }
}

public enum PhotoError: Error, Sendable, Equatable {
    case empty
    case device
    case texture(String)
    case render(String)
    case encode
}
