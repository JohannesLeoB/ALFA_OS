import AppKit
import CoreGraphics
import DrawingKit
import Foundation
import Metal
import Pages
import RealityKit
import simd

public enum Photo {
    public static let frames = 4
    public static let idFrames = 2
    public static let pause = 0.06
    static let groundSpan = 40.0
    static let backdropSpan = 14.0

    @MainActor
    public static func render(_ scene: PhotoScene, width: Int, height: Int) async throws -> CGImage {
        guard !scene.parts.isEmpty else { throw PhotoError.empty }
        try Validate.parts(scene.parts)
        guard width >= 16, height >= 16, width <= 8192, height <= 8192 else { throw PhotoError.render("size") }
        let aspect = Double(width) / Double(height)
        let all = scene.parts.flatMap(Facets.points)
        let lamps = Lamps.preset(scene.light.preset)
        let key = Studio.key(lamps, view: scene.view, light: scene.light)
        let angles = Rig.angles(scene.view)
        let wallOn = scene.backdrop && Rig.basis(azimuth: angles.azimuth, elevation: angles.elevation).forward.y > 0
        let top = all.map(\.z).max() ?? 0
        let floor = scene.backdrop ? min(0, all.map(\.z).min() ?? 0) : all.map(\.z).min() ?? 0
        let lo = SIMD3(all.map(\.x).min() ?? 0, all.map(\.y).min() ?? 0, floor)
        let hi = SIMD3(all.map(\.x).max() ?? 0, all.map(\.y).max() ?? 0, top)
        let wallY = hi.y + Studio.wallGap
        let framing = all + Studio.shadowPoints(all, key: key, floor: floor, wall: wallOn ? wallY : nil)
        guard let rig = Rig.fit(points: framing, view: scene.view, aspect: aspect, margin: scene.margin) else { throw PhotoError.empty }
        let mid = (lo + hi) / 2
        let reach = simd_length(hi - lo)

        var made: [String: PhysicallyBasedMaterial] = [:]
        var meshes: [MeshResource] = []
        for part in scene.parts {
            let surface = scene.surfaces[part.material]
            if made[part.material] == nil { made[part.material] = try Studio.material(surface) }
            meshes.append(try Facets.mesh(part, tile: surface?.tile ?? Texture.tile))
        }
        let contact = try Studio.contact(scene.parts, floor: floor)
        let deck = scene.backdrop ? Tone.deck : Tone.floor

        func stage(ids: Bool) -> (Entity, Entity) {
            let root = Entity()
            func flat(_ index: Int) -> UnlitMaterial { UnlitMaterial(color: Occlusion.color(index)) }
            func paint(_ hex: String) -> PhysicallyBasedMaterial {
                var m = PhysicallyBasedMaterial()
                m.baseColor = .init(tint: NSColor(cgColor: Tone.cg(hex)) ?? .white)
                m.roughness = .init(floatLiteral: 0.95)
                m.specular = .init(floatLiteral: 0.1)
                return m
            }
            for (index, part) in scene.parts.enumerated() {
                let material: any RealityKit.Material = ids ? flat(index + 1) : made[part.material]!
                let model = ModelEntity(mesh: meshes[index], materials: [material])
                model.name = part.id
                root.addChild(model)
            }
            let size = Float(reach * Space.metre * (scene.backdrop ? backdropSpan : groundSpan))
            let ground: any RealityKit.Material = ids ? flat(0) : paint(deck)
            let plane = ModelEntity(mesh: .generatePlane(width: size, depth: size), materials: [ground])
            plane.position = Space.point(SIMD3(mid.x, mid.y, floor))
            root.addChild(plane)
            if wallOn {
                let material: any RealityKit.Material = ids ? flat(0) : paint(Tone.wall)
                let wall = ModelEntity(mesh: .generatePlane(width: size, height: size), materials: [material])
                wall.position = Space.point(SIMD3(mid.x, wallY, floor)) + SIMD3(0, size / 2, 0)
                root.addChild(wall)
            }
            if !ids {
                if let contact { root.addChild(contact) }
                for lamp in Studio.lamp(lamps, view: scene.view, light: scene.light, floor: mid, reach: reach) { root.addChild(lamp) }
            }
            let camera = Entity()
            camera.position = Space.point(rig.eye)
            camera.orientation = Space.orientation(right: rig.right, up: rig.up, forward: rig.forward)
            let near = Float(rig.distance * Space.metre * 0.05), far = Float(reach * Space.metre * 40)
            if rig.ortho {
                var ortho = OrthographicCameraComponent()
                ortho.near = near; ortho.far = far; ortho.scale = Float(rig.scale * Space.metre)
                camera.components.set(ortho)
            } else {
                camera.components.set(PerspectiveCameraComponent(near: near, far: far, fieldOfViewInDegrees: Float(rig.fov)))
            }
            root.addChild(camera)
            return (root, camera)
        }

        guard let device = MTLCreateSystemDefaultDevice() else { throw PhotoError.device }
        func capture(ids: Bool) async throws -> [UInt8] {
            let (root, camera) = stage(ids: ids)
            let renderer = try RealityRenderer()
            renderer.entities.append(root)
            renderer.activeCamera = camera
            if ids {
                renderer.cameraSettings.colorBackground = .color(.black)
                renderer.cameraSettings.antialiasing = .none
                renderer.cameraSettings.isToneMappingEnabled = false
            } else {
                renderer.cameraSettings.colorBackground = .color(Tone.cg(scene.backdrop ? Tone.wall : Tone.backdrop))
                renderer.cameraSettings.antialiasing = .multisample4X
                renderer.cameraSettings.isToneMappingEnabled = true
                if let env = Studio.environment() {
                    renderer.lighting.resource = env
                    renderer.lighting.intensityExponent = lamps.ambient - 1.4
                }
            }
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
            descriptor.storageMode = .shared
            guard let target = device.makeTexture(descriptor: descriptor) else { throw PhotoError.device }
            let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: target))
            for frame in 0..<(ids ? idFrames : frames) {
                try await draw(renderer, output, delta: frame == 0 ? 0.0 : pause)
                try await Task.sleep(for: .seconds(pause))
            }
            return bytes(target)
        }

        var lit = try await capture(ids: false)
        if scene.parts.count <= Occlusion.capacity {
            Occlusion.apply(&lit, ids: try await capture(ids: true), width: width, height: height)
        }
        return try image(lit, width: width, height: height)
    }

    @MainActor
    private static func draw(_ renderer: RealityRenderer, _ output: RealityRenderer.CameraOutput, delta: Double) async throws {
        try await withCheckedThrowingContinuation { (done: CheckedContinuation<Void, Error>) in
            do {
                try renderer.updateAndRender(deltaTime: delta, cameraOutput: output, onComplete: { _ in done.resume() })
            } catch {
                done.resume(throwing: error)
            }
        }
    }

    private static func bytes(_ texture: MTLTexture) -> [UInt8] {
        let w = texture.width, h = texture.height
        var out = [UInt8](repeating: 0, count: w * h * 4)
        texture.getBytes(&out, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
        return out
    }

    private static func image(_ source: [UInt8], width w: Int, height h: Int) throws -> CGImage {
        var bytes = source
        for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB), let provider = CGDataProvider(data: Data(bytes) as CFData),
              let cg = CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4, space: space,
                               bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.noneSkipFirst.rawValue),
                               provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent) else {
            throw PhotoError.encode
        }
        return cg
    }

    public static func png(_ image: CGImage) throws -> Data {
        let out = NSMutableData()
        guard let target = CGImageDestinationCreateWithData(out as CFMutableData, "public.png" as CFString, 1, nil) else {
            throw PhotoError.encode
        }
        CGImageDestinationAddImage(target, image, nil)
        guard CGImageDestinationFinalize(target) else { throw PhotoError.encode }
        return out as Data
    }

    public static let sheet = CGSize(width: 297, height: 210)
    public static let border = 10.0

    public static func pdf(_ image: CGImage) throws -> Data {
        let data = try png(image)
        let wide = image.width >= image.height
        let size = wide ? sheet : CGSize(width: sheet.height, height: sheet.width)
        let frame = CGRect(x: border, y: border, width: size.width - 2 * border, height: size.height - 2 * border)
        let page = Page(size: size, background: "#ffffff", items: [.image(Picture(data: data, frame: frame))])
        let out = PDFRenderer().render(Document(pages: [page]))
        guard !out.isEmpty else { throw PhotoError.encode }
        return out
    }
}
