import CoreGraphics
import Foundation
import Pages

public typealias TextAnchor = Anchor

public enum SheetItem: Sendable {
    case line(CGPoint, CGPoint, width: Double, color: String)
    case rect(CGRect, fill: String?, stroke: String?, width: Double)
    case polygon([CGPoint], fill: String?, stroke: String?, width: Double)
    case text(String, at: CGPoint, size: Double, anchor: TextAnchor, weight: Int, color: String, rotation: Double)
    case raw(Item)

    var item: Item {
        switch self {
        case let .raw(item): return item
        case let .line(a, b, width, color): return .line(a, b, Paint(stroke: color, width: width))
        case let .rect(r, fill, stroke, width): return .rect(r, Paint(fill: fill, stroke: stroke, width: width))
        case let .polygon(points, fill, stroke, width): return .polygon(points, Paint(fill: fill, stroke: stroke, width: width))
        case let .text(text, at, size, anchor, weight, color, rotation):
            return .text(Run(text, origin: at, size: size, weight: weight, color: color, anchor: anchor, rotation: rotation))
        }
    }
}

public struct PlacedDimension: Sendable {
    public var view: ViewKind
    public var dimension: Dimension
}

public struct Sheet: Sendable {
    public var width: Double
    public var height: Double
    public var scale: Double
    public var fonts: SheetFonts
    public var paper: String
    public var items: [SheetItem]
    public var dimensions: [PlacedDimension]
    public var defects: [String]
    public var product = ""
    public var cells: [Placed] = []

    public var page: Page {
        Page(size: CGSize(width: width, height: height), background: paper, items: items.map(\.item))
    }

    public var faces: [FontFace] {
        [FontFace(role: .sans, family: fonts.sans), FontFace(role: .mono, family: fonts.mono)]
    }

    public var document: Document {
        Document(pages: [page], fonts: faces)
    }

    public func underlaid(_ image: Data, in frame: CGRect, opacity: Double) -> Sheet {
        var next = self
        next.items.insert(.raw(.image(Picture(data: image, frame: frame, opacity: opacity))), at: 0)
        return next
    }
}

public struct Cell: Sendable, Equatable, Identifiable {
    public var id: String
    public var view: ViewKind
    public var frame: CGRect
    public var scale: Double?
    public var focus: String?
    public var step: Int
    public var dims: Bool

    public init(id: String, view: ViewKind, frame: CGRect, scale: Double? = nil, focus: String? = nil, step: Int = 0, dims: Bool = true) {
        self.id = id; self.view = view; self.frame = frame; self.scale = scale
        self.focus = focus; self.step = step; self.dims = dims
    }
}

public struct Placed: Sendable, Equatable {
    public var id: String
    public var scale: Double
    public var fits: Bool
    public var steps: Int
}

public enum SheetLayout: String, Codable, Sendable, CaseIterable { case threeView, iso }

public enum Product: Sendable, Equatable {
    case plan
    case iso(ViewSpec)
    case steps(ViewSpec, [[String]])
    case customer(ViewSpec)
    case presentation
    case board([Cell], ViewSpec)
    case cover

    public static func named(_ name: String, distance: Double? = nil) -> Product? {
        switch name {
        case "plan": return .plan
        case "iso": return .iso(ViewSpec(kind: .iso))
        case "perspective": return .iso(ViewSpec(kind: .perspective, distance: distance))
        case "steps": return .steps(ViewSpec(kind: .iso), [])
        case "customer": return .customer(ViewSpec(kind: .iso))
        case "presentation": return .presentation
        case "cover": return .cover
        default: return nil
        }
    }

    public var key: String {
        switch self {
        case .plan: return "plan"
        case .iso(let v): return v.distance == nil ? "iso" : "perspective"
        case .steps: return "steps"
        case .customer: return "customer"
        case .presentation: return "presentation"
        case .board: return "board"
        case .cover: return "cover"
        }
    }
}

public struct Entry: Codable, Sendable, Equatable {
    public var label: String
    public var value: String

    public init(label: String, value: String) {
        self.label = label; self.value = value
    }
}

public struct Panel: Codable, Sendable, Equatable {
    public var title: String
    public var rows: [Entry]
    public var quota: Int?

    public init(title: String, rows: [Entry], quota: Int? = nil) {
        self.title = title; self.rows = rows; self.quota = quota
    }
}

public enum DimMode: String, Codable, Sendable, CaseIterable { case none, given }

public struct Job: Sendable {
    public var parts: [Part]
    public var ci: CIPack
    public var template: TemplatePack
    public var project: [String: String]
    public var products: [Product]
    public var style: IsoStyle?
    public var dimensions: Bool
    public var material: MaterialPack?
    public var variants: [Variant]
    public var dims: DimMode
    public var fonts: SheetFonts
    public var scale: Double?
    public var blocks: [Panel]
    public var units: [Unit]
    public var pose: [String: Double]

    public init(parts: [Part], ci: CIPack, template: TemplatePack, project: [String: String],
                products: [Product], style: IsoStyle? = nil, dimensions: Bool = true,
                material: MaterialPack? = nil, variants: [Variant] = [], dims: DimMode = .none, fonts: SheetFonts,
                scale: Double? = nil, blocks: [Panel] = [], units: [Unit] = [], pose: [String: Double] = [:]) {
        self.parts = parts; self.ci = ci; self.template = template; self.project = project
        self.products = products; self.style = style; self.dimensions = dimensions
        self.material = material; self.variants = variants; self.dims = dims; self.fonts = fonts; self.scale = scale
        self.blocks = blocks; self.units = units; self.pose = pose
    }
}

public struct Request: Sendable {
    public var parts: [Part]
    public var ci: CIPack
    public var template: TemplatePack
    public var project: [String: String]
    public var layout: SheetLayout
    public var iso: ViewSpec
    public var dimensions: Bool
    public var style: IsoStyle?
    public var fonts: SheetFonts
    var highlight: Set<String> = []
    var fit: [Part]?
    var product = ""
    var scale: Double?
    var step = (0, 0)
    var blocks: [Panel] = []
    var number = 1
    var units: [Unit] = []
    var pose: [String: Double] = [:]

    public init(parts: [Part], ci: CIPack, template: TemplatePack, project: [String: String],
                layout: SheetLayout, iso: ViewSpec = ViewSpec(kind: .iso), dimensions: Bool = true, style: IsoStyle? = nil, fonts: SheetFonts) {
        self.parts = parts; self.ci = ci; self.template = template; self.project = project
        self.layout = layout; self.iso = iso; self.dimensions = dimensions; self.style = style; self.fonts = fonts
    }
}
