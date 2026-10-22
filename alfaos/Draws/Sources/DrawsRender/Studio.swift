import AppKit
import CoreGraphics
import DrawingKit
import Foundation
import ImageIO
import RealityKit
import simd

enum Tone {
    static let floor = "#a8a49d"
    static let backdrop = "#aca79d"
    static let fallback = "#cfcac2"

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
    var keyColor: SIMD3<Float>
    var keyOffset: Double
    var keyElevation: Double
    var fillOffset: Double
    var fillElevation: Double
    var ambient: Float
    var shadow: Float

    static func preset(_ p: LightPreset) -> Lamps {
        switch p {
        case .studio:
            return Lamps(key: 4200, fill: 800, keyColor: SIMD3(1, 0.98, 0.95), keyOffset: -40, keyElevation: 50,
                         fillOffset: 70, fillElevation: 20, ambient: 0, shadow: 1)
        case .soft:
            return Lamps(key: 1800, fill: 1400, keyColor: SIMD3(1, 1, 1), keyOffset: -25, keyElevation: 60,
                         fillOffset: 55, fillElevation: 30, ambient: 0.3, shadow: 0.7)
        case .warm:
            return Lamps(key: 3800, fill: 700, keyColor: SIMD3(1, 0.9, 0.78), keyOffset: -45, keyElevation: 40,
                         fillOffset: 70, fillElevation: 15, ambient: 0, shadow: 1)
        case .hard:
            return Lamps(key: 5200, fill: 400, keyColor: SIMD3(1, 0.99, 0.97), keyOffset: -55, keyElevation: 35,
                         fillOffset: 80, fillElevation: 10, ambient: -0.3, shadow: 1)
        }
    }
}

@MainActor
enum Studio {
    static func image(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    static func texture(_ data: Data, normal: Bool) throws -> TextureResource {
        guard let cg = image(data) else { throw PhotoError.texture("image") }
        return try TextureResource(image: cg, options: .init(semantic: normal ? .normal : .color))
    }

    static func material(_ surface: Surface?) throws -> PhysicallyBasedMaterial {
        var m = PhysicallyBasedMaterial()
        let rough = Float(min(1, max(0.02, surface?.roughness ?? Texture.roughness)))
        m.roughness = .init(floatLiteral: rough)
        m.metallic = .init(floatLiteral: 0)
        if rough < 0.35 {
            m.clearcoat = .init(floatLiteral: 0.7)
            m.clearcoatRoughness = .init(floatLiteral: rough)
        }
        if let data = surface?.color {
            m.baseColor = .init(tint: .white, texture: .init(try texture(data, normal: false)))
        } else {
            m.baseColor = .init(tint: NSColor(cgColor: Tone.cg(surface?.tone)) ?? .gray)
        }
        if let data = surface?.normal { m.normal = .init(texture: .init(try texture(data, normal: true))) }
        return m
    }

    static func environment() -> EnvironmentResource? {
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
        guard let cg = ctx.makeImage() else { return nil }
        return try? EnvironmentResource(equirectangular: cg)
    }

    static let spread: [(Double, Double)] = [(0, 0), (1.5, 0.5), (-1.5, -0.5), (1, -1.2), (-1, 1.2), (2.5, -0.6), (-2.5, 0.6), (3.2, 0.9), (-3.2, -0.9),
                                              (0.6, 2), (-0.6, -2)]

    static func lamp(_ lamps: Lamps, view: ViewSpec, light: LightSpec, floor: SIMD3<Double>, reach: Double) -> [Entity] {
        let base = Rig.angles(view).azimuth
        let az = light.azimuth ?? (base + lamps.keyOffset)
        let el = light.elevation ?? lamps.keyElevation
        func entity(_ azimuth: Double, _ elevation: Double, _ component: DirectionalLightComponent, shadow: Bool) -> Entity {
            let b = Rig.basis(azimuth: azimuth, elevation: elevation)
            let e = Entity()
            e.position = Space.point(floor - b.forward * reach)
            e.orientation = Space.orientation(right: b.right, up: b.up, forward: b.forward)
            e.components.set(component)
            if shadow {
                e.components.set(DirectionalLightComponent.Shadow(shadowProjection: .fixed(zNear: 0.01, zFar: Float(reach * Space.metre * 2), orthographicScale: Float(reach * Space.metre * 0.75)),
                                                                  depthBias: 1))
            }
            return e
        }
        let tint = NSColor(red: CGFloat(lamps.keyColor.x), green: CGFloat(lamps.keyColor.y), blue: CGFloat(lamps.keyColor.z), alpha: 1)
        let key = DirectionalLightComponent(color: tint, intensity: lamps.key / Float(spread.count))
        let fill = DirectionalLightComponent(color: .white, intensity: lamps.fill)
        var out = spread.map { entity(az + $0.0, el + $0.1, key, shadow: lamps.shadow > 0) }
        out.append(entity(base + lamps.fillOffset, lamps.fillElevation, fill, shadow: false))
        return out
    }

    static func contact(_ parts: [Part], floor: Double) throws -> ModelEntity? {
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
        let tex = try TextureResource(image: cg, options: .init(semantic: .color))
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: .black, texture: .init(tex))
        m.roughness = .init(floatLiteral: 1)
        m.specular = .init(floatLiteral: 0)
        m.blending = .transparent(opacity: .init(scale: 1, texture: .init(tex)))
        let plane = MeshResource.generatePlane(width: Float(size.x * Space.metre), depth: Float(size.y * Space.metre))
        let e = ModelEntity(mesh: plane, materials: [m])
        e.position = Space.point(SIMD3((lo.x + hi.x) / 2, (lo.y + hi.y) / 2, floor + 0.3))
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
