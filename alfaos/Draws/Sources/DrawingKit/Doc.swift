import CoreGraphics
import Foundation

public enum DocError: Error, Equatable, Sendable {
    case newer(Int)
    case corrupt
    case encode
    case pack([String])
    case missing(String)
}

public struct DocPacks: Codable, Hashable, Sendable {
    public var ci: String
    public var template: String
    public var style: String?
    public var material: String?

    public init(ci: String, template: String, style: String? = nil, material: String? = nil) {
        self.ci = ci; self.template = template; self.style = style; self.material = material
    }
}

public struct DocTexture: Codable, Hashable, Sendable {
    public var image: String
    public var normal: String?
    public var tile: Double
    public var roughness: Double

    public init(image: String, normal: String? = nil, tile: Double = 600, roughness: Double = 0.6) {
        self.image = image; self.normal = normal; self.tile = tile; self.roughness = roughness
    }
}

public struct DocInput: Codable, Hashable, Sendable {
    public var name: String
    public var role: String
    public var mediaType: String
    public var note: String
    public var data: Data

    public init(name: String, role: String, mediaType: String, note: String = "", data: Data) {
        self.name = name; self.role = role; self.mediaType = mediaType; self.note = note; self.data = data
    }
}

public struct DocCell: Codable, Hashable, Sendable {
    public var id: String
    public var view: ViewKind
    public var x: Double, y: Double, w: Double, h: Double
    public var scale: Double?
    public var focus: String?
    public var step: Int
    public var dims: Bool

    public init(_ cell: Cell) {
        id = cell.id; view = cell.view
        x = cell.frame.minX; y = cell.frame.minY; w = cell.frame.width; h = cell.frame.height
        scale = cell.scale; focus = cell.focus; step = cell.step; dims = cell.dims
    }

    public var cell: Cell {
        Cell(id: id, view: view, frame: CGRect(x: x, y: y, width: w, height: h), scale: scale, focus: focus, step: step, dims: dims)
    }
}

public struct DocLight: Codable, Hashable, Sendable {
    public var preset: String
    public var azimuth: Double?
    public var elevation: Double?

    public init(preset: String = "studio", azimuth: Double? = nil, elevation: Double? = nil) {
        self.preset = preset; self.azimuth = azimuth; self.elevation = elevation
    }
}

public struct DocRender: Codable, Hashable, Sendable {
    public var layout: String
    public var page: Int
    public var azimuth: Double
    public var elevation: Double
    public var tone: Bool
    public var faces: [String]
    public var edge: Double?
    public var outline: Double?
    public var shadow: Double?
    public var shadowOn: Bool
    public var accent: String?
    public var accentColor: String?
    public var dimensions: Bool
    public var reach: Double

    public static let reach = 4.5

    public init(layout: String = "plan", page: Int = 0, azimuth: Double = 45, elevation: Double = ViewSpec.isoElevation,
                tone: Bool = true, faces: [String] = [], edge: Double? = nil, outline: Double? = nil, shadow: Double? = nil,
                shadowOn: Bool = true, accent: String? = nil, accentColor: String? = nil, dimensions: Bool = true,
                reach: Double = DocRender.reach) {
        self.layout = layout; self.page = page; self.azimuth = azimuth; self.elevation = elevation; self.tone = tone
        self.faces = faces; self.edge = edge; self.outline = outline; self.shadow = shadow; self.shadowOn = shadowOn
        self.accent = accent; self.accentColor = accentColor; self.dimensions = dimensions; self.reach = reach
    }

    enum CodingKeys: String, CodingKey {
        case layout, page, azimuth, elevation, tone, faces, edge, outline, shadow, shadowOn, accent, accentColor, dimensions, reach
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(layout: try c.decodeIfPresent(String.self, forKey: .layout) ?? "plan",
                  page: try c.decodeIfPresent(Int.self, forKey: .page) ?? 0,
                  azimuth: try c.decodeIfPresent(Double.self, forKey: .azimuth) ?? 45,
                  elevation: try c.decodeIfPresent(Double.self, forKey: .elevation) ?? ViewSpec.isoElevation,
                  tone: try c.decodeIfPresent(Bool.self, forKey: .tone) ?? true,
                  faces: try c.decodeIfPresent([String].self, forKey: .faces) ?? [],
                  edge: try c.decodeIfPresent(Double.self, forKey: .edge),
                  outline: try c.decodeIfPresent(Double.self, forKey: .outline),
                  shadow: try c.decodeIfPresent(Double.self, forKey: .shadow),
                  shadowOn: try c.decodeIfPresent(Bool.self, forKey: .shadowOn) ?? true,
                  accent: try c.decodeIfPresent(String.self, forKey: .accent),
                  accentColor: try c.decodeIfPresent(String.self, forKey: .accentColor),
                  dimensions: try c.decodeIfPresent(Bool.self, forKey: .dimensions) ?? true,
                  reach: try c.decodeIfPresent(Double.self, forKey: .reach) ?? DocRender.reach)
    }
}

public struct DocUnderlay: Codable, Hashable, Sendable {
    public var name: String
    public var show: Bool
    public var export: Bool

    public init(name: String, show: Bool = false, export: Bool = false) {
        self.name = name; self.show = show; self.export = export
    }
}

public struct DrawsDoc: Codable, Equatable, Sendable {
    public static let schema = 1

    public var schema: Int
    public var parts: [Part]
    public var units: [Unit]
    public var pose: [String: Double]
    public var cells: [DocCell]
    public var packs: DocPacks
    public var textures: [String: DocTexture]
    public var inputs: [DocInput]
    public var project: [String: String]
    public var variants: [Variant]
    public var blocks: [Panel]
    public var extra: [Material]
    public var hidden: [String]
    public var light: DocLight
    public var render: DocRender
    public var underlay: DocUnderlay?
    public var kitchen: KitchenSpec?

    public init(parts: [Part], packs: DocPacks, units: [Unit] = [], pose: [String: Double] = [:], cells: [DocCell] = [],
                textures: [String: DocTexture] = [:], inputs: [DocInput] = [], project: [String: String] = [:],
                variants: [Variant] = [], blocks: [Panel] = [], extra: [Material] = [], hidden: [String] = [],
                light: DocLight = DocLight(), render: DocRender = DocRender(), underlay: DocUnderlay? = nil,
                kitchen: KitchenSpec? = nil) {
        schema = DrawsDoc.schema
        self.parts = parts; self.units = units; self.pose = pose; self.cells = cells; self.packs = packs
        self.textures = textures; self.inputs = inputs; self.project = project; self.variants = variants
        self.blocks = blocks; self.extra = extra; self.hidden = hidden; self.light = light; self.render = render
        self.underlay = underlay; self.kitchen = kitchen
    }

    enum CodingKeys: String, CodingKey {
        case schema, parts, units, pose, cells, packs, textures, inputs, project, variants, blocks, extra, hidden, light, render, underlay, kitchen
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(parts: try c.decode([Part].self, forKey: .parts),
                  packs: try c.decode(DocPacks.self, forKey: .packs),
                  units: try c.decodeIfPresent([Unit].self, forKey: .units) ?? [],
                  pose: try c.decodeIfPresent([String: Double].self, forKey: .pose) ?? [:],
                  cells: try c.decodeIfPresent([DocCell].self, forKey: .cells) ?? [],
                  textures: try c.decodeIfPresent([String: DocTexture].self, forKey: .textures) ?? [:],
                  inputs: try c.decodeIfPresent([DocInput].self, forKey: .inputs) ?? [],
                  project: try c.decodeIfPresent([String: String].self, forKey: .project) ?? [:],
                  variants: try c.decodeIfPresent([Variant].self, forKey: .variants) ?? [],
                  blocks: try c.decodeIfPresent([Panel].self, forKey: .blocks) ?? [],
                  extra: try c.decodeIfPresent([Material].self, forKey: .extra) ?? [],
                  hidden: try c.decodeIfPresent([String].self, forKey: .hidden) ?? [],
                  light: try c.decodeIfPresent(DocLight.self, forKey: .light) ?? DocLight(),
                  render: try c.decodeIfPresent(DocRender.self, forKey: .render) ?? DocRender(),
                  underlay: try c.decodeIfPresent(DocUnderlay.self, forKey: .underlay),
                  kitchen: try c.decodeIfPresent(KitchenSpec.self, forKey: .kitchen))
        schema = try c.decodeIfPresent(Int.self, forKey: .schema) ?? DrawsDoc.schema
    }

    public var shown: [Part] { parts.filter { !hidden.contains($0.id) } }

    public func image(_ name: String) -> Data? { inputs.first { $0.name == name }?.data }

    public func job(ci: CIPack, template: TemplatePack, material: MaterialPack?, fonts: SheetFonts) -> Job {
        let shown = shown
        let ids = Set(shown.map(\.id))
        let running = units.filter { ($0.front + $0.body).allSatisfy(ids.contains) }
        let live = Set(running.map(\.id))
        let size = shown.reduce(0.0) { max($0, $1.w, $1.d, $1.h) }
        let product: Product
        switch render.layout {
        case "presentation": product = .presentation
        case "cover": product = .cover
        default:
            let distance = render.reach * size
            if cells.isEmpty {
                product = Product.named(render.layout, distance: distance) ?? .plan
            } else {
                product = .board(cells.map(\.cell), ViewSpec(kind: .iso, azimuth: render.azimuth, elevation: render.elevation,
                                                             distance: distance))
            }
        }
        var style = ci.iso
        style.edge = render.edge ?? style.edge
        style.outline = render.outline ?? style.outline
        style.shadow = render.shadowOn ? (render.shadow.map { $0 / 100 } ?? style.shadow) : 0
        style.accent = render.accent
        style.accentColor = render.accentColor
        style.faces = render.tone && !render.faces.isEmpty ? render.faces : nil
        return Job(parts: shown, ci: ci, template: template, project: project, products: [product], style: style,
                   dimensions: render.dimensions, material: material, variants: variants,
                   dims: render.dimensions ? .given : .none, fonts: fonts, blocks: blocks, units: running,
                   pose: pose.filter { live.contains($0.key) })
    }
}

public struct PackShelf: Sendable {
    public var root: URL

    public init(root: URL) { self.root = root }

    public func sheets(_ doc: DrawsDoc, fonts: SheetFonts) throws -> [Sheet] {
        let ci = try Packs.loadCI(folder("ci", doc.packs.ci))
        let template = try Packs.loadTemplate(folder("template", doc.packs.template), also: [folder("ci", doc.packs.ci)])
        let material = try doc.packs.material.map { try Packs.loadMaterial(folder("material", $0)) }
        let defects = ci.defects + template.defects + (material?.defects ?? [])
        guard defects.isEmpty else { throw DocError.pack(defects) }
        var pack = ci.pack
        for item in doc.extra { pack.tints[item.code] = item.tone }
        var catalog = material?.pack
        if let known = catalog {
            catalog?.materials += doc.extra.filter { known.material($0.code) == nil }
        }
        return try DrawingEngine.render(doc.job(ci: pack, template: template.pack, material: catalog, fonts: fonts))
    }

    func folder(_ kind: String, _ id: String) -> URL {
        root.appendingPathComponent(kind, isDirectory: true).appendingPathComponent(id, isDirectory: true)
    }
}
