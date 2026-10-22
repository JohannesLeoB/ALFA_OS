import DrawingKit
import DrawsRender
import Foundation

@MainActor
func runPhoto(_ args: [String]) async {
    func value(_ name: String) -> String? {
        guard let i = args.firstIndex(of: name), i + 1 < args.count else { return nil }
        return args[i + 1]
    }
    func number(_ name: String) -> Double? {
        guard let text = value(name) else { return nil }
        guard let n = Double(text), n.isFinite else { fail("bad \(name) \(text)") }
        return n
    }
    guard let source = value("--render"), let target = value("--out") else { fail("usage: drawingdude --render case.json --out x.png") }
    let size = (value("--size") ?? "1600x1000").split(separator: "x").compactMap { Int($0) }
    guard size.count == 2 else { fail("bad --size") }
    guard let kind = ViewKind(rawValue: value("--view") ?? "iso") else { fail("unknown --view") }
    guard let preset = LightPreset(rawValue: value("--light") ?? "studio") else { fail("unknown --light") }
    let amounts: [String: Double] = Dictionary((value("--pose") ?? "").split(separator: ",").map { pair in
        let kv = pair.split(separator: "=").map(String.init)
        guard kv.count == 2, let amount = Double(kv[1]) else { fail("bad --pose \(pair)") }
        return (kv[0], amount)
    }, uniquingKeysWith: { _, last in last })
    do {
        let object = try DrawingObject.load(URL(fileURLWithPath: source))
        try Validate.parts(object.parts)
        try Validate.units(object.units ?? [], parts: object.parts)
        try Validate.pose(amounts, units: object.units ?? [])
        var tones: [String: String] = [:]
        if let folder = value("--ci") { tones = try Packs.loadCI(URL(fileURLWithPath: folder, isDirectory: true)).pack.tints }
        var look = Look(light: LightSpec(preset: preset, azimuth: number("--light-az"), elevation: number("--light-el")))
        var images: [String: Data] = [:]
        for (index, arg) in args.enumerated() where arg == "--tex" && index + 1 < args.count {
            let pair = args[index + 1].split(separator: "=", maxSplits: 1).map(String.init)
            guard pair.count == 2 else { fail("bad --tex \(args[index + 1])") }
            let fields = pair[1].split(separator: "@", omittingEmptySubsequences: false).map(String.init)
            var texture = Texture(image: fields[0])
            if fields.count > 1, let tile = Double(fields[1]) { texture.tile = tile }
            if fields.count > 2, let rough = Double(fields[2]) { texture.roughness = rough }
            if fields.count > 3, !fields[3].isEmpty { texture.normal = fields[3] }
            images[texture.image] = try Data(contentsOf: URL(fileURLWithPath: texture.image))
            if let normal = texture.normal { images[normal] = try Data(contentsOf: URL(fileURLWithPath: normal)) }
            look.textures[pair[0]] = texture
        }
        let parts = pose(object.parts, object.units ?? [], amounts: amounts)
        let codes = Array(Set(parts.map(\.material)))
        let view = ViewSpec(kind: kind, azimuth: number("--azimuth") ?? 45, elevation: number("--elevation") ?? ViewSpec.isoElevation,
                            distance: number("--distance"))
        let scene = PhotoScene(parts: parts, surfaces: look.surfaces(images: images, tones: tones, codes: codes), light: look.light, view: view)
        let picture = try await Photo.render(scene, width: size[0], height: size[1])
        try Photo.png(picture).write(to: URL(fileURLWithPath: target))
        if let pdf = value("--pdf") { try Photo.pdf(picture).write(to: URL(fileURLWithPath: pdf)) }
        print("\(target): \(size[0])x\(size[1])")
    } catch let error as PhotoError {
        fail("render failed: \(error)")
    } catch let error as DrawingError {
        fail("error: \(error)")
    } catch {
        fail("error: \(error.localizedDescription)")
    }
}
