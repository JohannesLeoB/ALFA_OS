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
    public static let pause = 0.06

    @MainActor
    public static func render(_ scene: PhotoScene, width: Int, height: Int) async throws -> CGImage {
        guard !scene.parts.isEmpty else { throw PhotoError.empty }
        try Validate.parts(scene.parts)
        guard width >= 16, height >= 16, width <= 8192, height <= 8192 else { throw PhotoError.render("size") }
        let aspect = Double(width) / Double(height)
        let all = scene.parts.flatMap(Facets.points)
        guard let rig = Rig.fit(points: all, view: scene.view, aspect: aspect) else { throw PhotoError.empty }
        let floor = all.map(\.z).min() ?? 0
        let lo = SIMD3(all.map(\.x).min() ?? 0, all.map(\.y).min() ?? 0, floor)
        let hi = SIMD3(all.map(\.x).max() ?? 0, all.map(\.y).max() ?? 0, all.map(\.z).max() ?? 0)
        let mid = (lo + hi) / 2
        let reach = simd_length(hi - lo)

        let root = Entity()
        var made: [String: PhysicallyBasedMaterial] = [:]
        for part in scene.parts {
            let surface = scene.surfaces[part.material]
            if made[part.material] == nil { made[part.material] = try Studio.material(surface) }
            let mesh = try Facets.mesh(part, tile: surface?.tile ?? Texture.tile)
            let model = ModelEntity(mesh: mesh, materials: [made[part.material]!])
            model.name = part.id
            root.addChild(model)
        }

        var ground = PhysicallyBasedMaterial()
        ground.baseColor = .init(tint: NSColor(cgColor: Tone.cg(Tone.floor)) ?? .white)
        ground.roughness = .init(floatLiteral: 0.95)
        ground.specular = .init(floatLiteral: 0.1)
        let size = Float(reach * Space.metre * 40)
        let plane = ModelEntity(mesh: .generatePlane(width: size, depth: size), materials: [ground])
        plane.position = Space.point(SIMD3(mid.x, mid.y, floor))
        root.addChild(plane)
        if let contact = try Studio.contact(scene.parts, floor: floor) { root.addChild(contact) }

        let lamps = Studio.lamp(Lamps.preset(scene.light.preset), view: scene.view, light: scene.light, floor: mid, reach: reach)
        for lamp in lamps { root.addChild(lamp) }

        let camera = Entity()
        camera.position = Space.point(rig.eye)
        camera.orientation = Space.orientation(right: rig.right, up: rig.up, forward: rig.forward)
        camera.components.set(PerspectiveCameraComponent(near: Float(rig.distance * Space.metre * 0.05), far: Float(reach * Space.metre * 40),
                                                         fieldOfViewInDegrees: Float(rig.fov)))
        root.addChild(camera)

        let renderer = try RealityRenderer()
        renderer.entities.append(root)
        renderer.activeCamera = camera
        renderer.cameraSettings.colorBackground = .color(Tone.cg(Tone.backdrop))
        renderer.cameraSettings.antialiasing = .multisample4X
        renderer.cameraSettings.isToneMappingEnabled = true
        if let env = Studio.environment() {
            renderer.lighting.resource = env
            renderer.lighting.intensityExponent = Lamps.preset(scene.light.preset).ambient - 1.4
        }

        guard let device = MTLCreateSystemDefaultDevice() else { throw PhotoError.device }
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm_srgb, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead, .shaderWrite]
        descriptor.storageMode = .shared
        guard let target = device.makeTexture(descriptor: descriptor) else { throw PhotoError.device }
        let output = try RealityRenderer.CameraOutput(.singleProjection(colorTexture: target))
        for frame in 0..<frames {
            try await draw(renderer, output, delta: frame == 0 ? 0.0 : pause)
            try await Task.sleep(for: .seconds(pause))
        }
        return try image(target)
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

    private static func image(_ texture: MTLTexture) throws -> CGImage {
        let w = texture.width, h = texture.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        texture.getBytes(&bytes, bytesPerRow: w * 4, from: MTLRegionMake2D(0, 0, w, h), mipmapLevel: 0)
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
