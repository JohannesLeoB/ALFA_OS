import AppKit
import CryptoKit
import CoreGraphics
import DrawingKit
import Foundation
import ImageIO
import RealityKit
import simd

enum Tone {
    static let floor = "#a8a49d"
    static let backdrop = "#aca79d"
    static let deck = "#c9c5be"
    static let wall = "#d2cec7"
    static let fallback = "#e8e4dc"

    static func cg(_ hex: String?) -> CGColor {
        let s = (hex ?? fallback).trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard s.count == 6, let v = Int(s, radix: 16) else { return cg(fallback) }
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        return CGColor(colorSpace: space, components: [CGFloat((v >> 16) & 255) / 255, CGFloat((v >> 8) & 255) / 255,
                                                       CGFloat(v & 255) / 255, 1])!
    }
}

struct Lamps {
    var key: Float
    var fill: Float
    var rim: Float
    var keyColor: SIMD3<Float>
    var keyOffset: Double
    var keyElevation: Double
    var fillOffset: Double
    var fillElevation: Double
    var rimOffset: Double
    var rimElevation: Double
    var ambient: Float
    var spread: Double

    static func preset(_ p: LightPreset) -> Lamps {
        switch p {
        case .studio:
            return Lamps(key: 4600, fill: 1100, rim: 900, keyColor: SIMD3(1, 0.98, 0.95), keyOffset: -40, keyElevation: 55,
                         fillOffset: 75, fillElevation: 15, rimOffset: 160, rimElevation: 35, ambient: 0, spread: 3.2)
        case .soft:
            return Lamps(key: 3500, fill: 1600, rim: 700, keyColor: SIMD3(1, 1, 1), keyOffset: -25, keyElevation: 62,
                         fillOffset: 55, fillElevation: 25, rimOffset: 165, rimElevation: 40, ambient: 0.6, spread: 6)
        case .warm:
            return Lamps(key: 4200, fill: 600, rim: 800, keyColor: SIMD3(1, 0.9, 0.78), keyOffset: -45, keyElevation: 45,
                         fillOffset: 70, fillElevation: 15, rimOffset: 155, rimElevation: 30, ambient: 0, spread: 3.6)
        case .hard:
            return Lamps(key: 4300, fill: 600, rim: 600, keyColor: SIMD3(1, 0.99, 0.97), keyOffset: -55, keyElevation: 52,
                         fillOffset: 80, fillElevation: 10, rimOffset: 150, rimElevation: 30, ambient: -0.3, spread: 1.2)
        }
    }
}

struct Map: Sendable {
    var key: String
    var image: CGImage
}

final class Decoded: @unchecked Sendable {
    static let shared = Decoded()
    static let capacity = 32
    private let lock = NSLock()
    private var images: [String: CGImage] = [:]

    func map(_ data: Data) throws -> Map {
        let key = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        lock.lock()
        let hit = images[key]
        lock.unlock()
        if let hit { return Map(key: key, image: hit) }
        guard let cg = Studio.image(data) else { throw PhotoError.texture("image") }
        lock.lock()
        if images.count >= Self.capacity { images.removeAll() }
        images[key] = cg
        lock.unlock()
        return Map(key: key, image: cg)
    }
}

struct Maps: Sendable {
    var color: Map?
    var normal: Map?
}

enum Studio {
    static func image(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    @MainActor static var resources: [String: TextureResource] = [:]

    @MainActor
    static func texture(_ map: Map, normal: Bool) throws -> TextureResource {
        let key = map.key + (normal ? "n" : "c")
        if let hit = resources[key] { return hit }
        let made = try TextureResource(image: map.image, options: .init(semantic: normal ? .normal : .color))
        if resources.count >= Decoded.capacity { resources.removeAll() }
        resources[key] = made
        return made
    }

    @MainActor
    static func material(_ surface: Surface?, maps: Maps) throws -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        let rough = Float(min(1, max(0.02, surface?.roughness ?? Texture.roughness)))
        m.roughness = .init(floatLiteral: rough)
        m.metallic = .init(floatLiteral: 0)
        if rough < 0.35 {
            m.clearcoat = .init(floatLiteral: 0.7)
            m.clearcoatRoughness = .init(floatLiteral: rough)
        }
        if let map = maps.color {
            m.baseColor = .init(tint: .white, texture: .init(try texture(map, normal: false)))
        } else {
            m.baseColor = .init(tint: NSColor(cgColor: Tone.cg(surface?.tone)) ?? .gray)
        }
        if let map = maps.normal { m.normal = .init(texture: .init(try texture(map, normal: true))) }
        return m
    }

    static func environmentImage() -> CGImage? {
        let w = 512, h = 256
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        let colors = [CGColor(srgbRed: 0.34, green: 0.33, blue: 0.32, alpha: 1), CGColor(srgbRed: 0.78, green: 0.78, blue: 0.78, alpha: 1),
                      CGColor(srgbRed: 0.97, green: 0.97, blue: 0.98, alpha: 1)] as CFArray
        if let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 0.5, 1]) {
            ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: CGFloat(h)), options: [])
        }
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 60, y: 150, width: 110, height: 60))
        ctx.fill(CGRect(x: 330, y: 130, width: 90, height: 70))
        ctx.setFillColor(CGColor(srgbRed: 1, green: 0.96, blue: 0.9, alpha: 1))
        ctx.fill(CGRect(x: 180, y: 190, width: 60, height: 40))
        return ctx.makeImage()
    }

    @MainActor
    static func environment(_ image: CGImage?) -> EnvironmentResource? {
        image.flatMap { try? EnvironmentResource(equirectangular: $0) }
    }

    static let samples = 20
    static let golden = 2.39996
    static let shadowReach = 1.1
    static let wallGap = 1.0

    static func key(_ lamps: Lamps, view: ViewSpec, light: LightSpec) -> (azimuth: Double, elevation: Double) {
        (light.azimuth ?? (Rig.angles(view).azimuth + lamps.keyOffset), light.elevation ?? lamps.keyElevation)
    }

    static func shadowPoints(_ points: [SIMD3<Double>], key: (azimuth: Double, elevation: Double), floor: Double,
                             wall: Double?) -> [SIMD3<Double>] {
        let d = Rig.basis(azimuth: key.azimuth, elevation: key.elevation).forward
        guard d.z < -1e-6 else { return [] }
        return points.compactMap { p in
            var t = (p.z - floor) / -d.z
            if let wall, d.y > 1e-6 { t = min(t, (wall - p.y) / d.y) }
            return t.isFinite && t > 0 ? p + d * t : nil
        }
    }

    @MainActor
    static func lamp(_ lamps: Lamps, view: ViewSpec, light: LightSpec, floor: SIMD3<Double>, reach: Double) -> [Entity] {
        let base = Rig.angles(view).azimuth
        let (az, el) = key(lamps, view: view, light: light)
        func entity(_ azimuth: Double, _ elevation: Double, _ component: DirectionalLightComponent, shadow: Bool) -> Entity {
            let b = Rig.basis(azimuth: azimuth, elevation: elevation)
            let e = Entity()
            e.position = Space.point(floor - b.forward * reach)
            e.orientation = Space.orientation(right: b.right, up: b.up, forward: b.forward)
            e.components.set(component)
            if shadow {
                e.components.set(DirectionalLightComponent.Shadow(shadowProjection: .fixed(zNear: 0.01, zFar: Float(reach * Space.metre * 3),
                                                                                           orthographicScale: Float(reach * Space.metre * shadowReach)),
                                                                  depthBias: 1))
            }
            return e
        }
        let tint = NSColor(red: CGFloat(lamps.keyColor.x), green: CGFloat(lamps.keyColor.y), blue: CGFloat(lamps.keyColor.z), alpha: 1)
        let key = DirectionalLightComponent(color: tint, intensity: lamps.key / Float(samples))
        var out: [Entity] = (0..<samples).map { i in
            let r = lamps.spread * (Double(i) + 0.5).squareRoot() / Double(samples).squareRoot(), t = Double(i) * golden
            return entity(az + r * cos(t), el + r * sin(t) * 0.7, key, shadow: true)
        }
        out.append(entity(base + lamps.fillOffset, lamps.fillElevation, DirectionalLightComponent(color: .white, intensity: lamps.fill), shadow: false))
        out.append(entity(base + lamps.rimOffset, lamps.rimElevation, DirectionalLightComponent(color: .white, intensity: lamps.rim), shadow: false))
        return out
    }

    struct Contact: Sendable {
        var image: CGImage
        var lo: SIMD2<Double>
        var hi: SIMD2<Double>
        var floor: Double
    }

    static func contact(_ parts: [Part], floor: Double) -> Contact? {
        var lo = SIMD2<Double>(.infinity, .infinity), hi = SIMD2<Double>(-.infinity, -.infinity)
        var rects: [(SIMD2<Double>, SIMD2<Double>)] = []
        for part in parts {
            let ps = Facets.points(part)
            guard let z = ps.map(\.z).min(), z <= floor + 1 else { continue }
            let a = SIMD2(ps.map(\.x).min() ?? 0, ps.map(\.y).min() ?? 0), b = SIMD2(ps.map(\.x).max() ?? 0, ps.map(\.y).max() ?? 0)
            rects.append((a, b))
            lo = simd_min(lo, a); hi = simd_max(hi, b)
        }
        guard !rects.isEmpty else { return nil }
        let span = max(hi.x - lo.x, hi.y - lo.y)
        let pad = span * 0.05
        lo -= SIMD2(pad, pad); hi += SIMD2(pad, pad)
        let side = 512
        let size = hi - lo
        var mask = [Float](repeating: 0, count: side * side)
        for (a, b) in rects {
            let x0 = Int((a.x - lo.x) / size.x * Double(side)), x1 = Int((b.x - lo.x) / size.x * Double(side))
            let y0 = Int((a.y - lo.y) / size.y * Double(side)), y1 = Int((b.y - lo.y) / size.y * Double(side))
            for y in max(0, y0)..<min(side, max(y1, y0 + 1)) {
                for x in max(0, x0)..<min(side, max(x1, x0 + 1)) { mask[y * side + x] = 1 }
            }
        }
        let radius = max(2, Int(Double(side) * pad / max(size.x, size.y) * 0.5))
        for _ in 0..<3 { mask = blur(mask, side: side, radius: radius) }
        let peak = mask.max() ?? 1
        var rgba = [UInt8](repeating: 0, count: side * side * 4)
        for y in 0..<side {
            for x in 0..<side {
                let v = mask[(side - 1 - y) * side + x] / max(peak, 0.0001)
                let byte = UInt8(min(255, max(0, v * 0.8 * 255)))
                for c in 0..<4 { rgba[(y * side + x) * 4 + c] = byte }
            }
        }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData),
              let cg = CGImage(width: side, height: side, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: side * 4, space: space,
                               bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue), provider: provider,
                               decode: nil, shouldInterpolate: true, intent: .defaultIntent) else { return nil }
        return Contact(image: cg, lo: lo, hi: hi, floor: floor)
    }

    @MainActor
    static func contactEntity(_ c: Contact) throws -> ModelEntity {
        let lo = c.lo, hi = c.hi, size = hi - lo
        let tex = try TextureResource(image: c.image, options: .init(semantic: .color))
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .black, texture: .init(tex))
        m.roughness = .init(floatLiteral: 1)
        m.specular = .init(floatLiteral: 0)
        m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
        let plane = MeshResource.generatePlane(width: Float(size.x * Space.metre), depth: Float(size.y * Space.metre))
        let e = ModelEntity(mesh: plane, materials: [m])
        e.position = Space.point(SIMD3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, c.floor + 0.3))
        return e
    }

    static func blur(_ src: [Float], side: Int, radius: Int) -> [Float] {
        var tmp = src, out = src
        let n = Float(2 * radius + 1)
        for y in 0..<side {
            var sum: Float = 0
            for x in -radius...radius { sum += src[y * side + min(side - 1, max(0, x))] }
            for x in 0..<side {
                tmp[y * side + x] = sum / n
                sum += src[y * side + min(side - 1, x + radius + 1)] - src[y * side + max(0, x - radius)]
            }
        }
        for x in 0..<side {
            var sum: Float = 0
            for y in -radius...radius { sum += tmp[min(side - 1, max(0, y)) * side + x] }
            for y in 0..<side {
                out[y * side + x] = sum / n
                sum += tmp[min(side - 1, y + radius + 1) * side + x] - tmp[max(0, y - radius) * side + x]
            }
        }
        return out
    }
}
