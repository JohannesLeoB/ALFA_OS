import CoreGraphics
import Foundation

public enum TextAnchor: String, Sendable { case start, middle, end }

public enum SheetItem: Sendable {
    case line(CGPoint, CGPoint, width: Double, color: String)
    case rect(CGRect, fill: String?, stroke: String?, width: Double)
    case polygon([CGPoint], fill: String?, stroke: String?, width: Double)
    case text(String, at: CGPoint, size: Double, anchor: TextAnchor, weight: Int, color: String, rotation: Double)
}

public struct PlacedDimension: Sendable {
    public var view: ViewKind
    public var dimension: Dimension
}

public struct Sheet: Sendable {
    public var width: Double
    public var height: Double
    public var scale: Double
    public var font: String
    public var pdfFont: String
    public var paper: String
    public var items: [SheetItem]
    public var dimensions: [PlacedDimension]
    public var defects: [String]
    public var product = ""
}

public enum SheetLayout: String, Codable, Sendable, CaseIterable { case threeView, iso }

public enum Product: Sendable, Equatable {
    case plan
    case iso(ViewSpec)
    case steps(ViewSpec, [[String]])
    case customer(ViewSpec)

    public static func named(_ name: String, distance: Double? = nil) -> Product? {
        switch name {
        case "plan": return .plan
        case "iso": return .iso(ViewSpec(kind: .iso))
        case "perspective": return .iso(ViewSpec(kind: .perspective, distance: distance))
        case "steps": return .steps(ViewSpec(kind: .iso), [])
        case "customer": return .customer(ViewSpec(kind: .iso))
        default: return nil
        }
    }

    public var key: String {
        switch self {
        case .plan: return "plan"
        case .iso(let v): return v.distance == nil ? "iso" : "perspective"
        case .steps: return "steps"
        case .customer: return "customer"
        }
    }
}

public struct Job: Sendable {
    public var parts: [Part]
    public var ci: CIPack
    public var template: TemplatePack
    public var project: [String: String]
    public var products: [Product]
    public var style: IsoStyle?
    public var dimensions: Bool

    public init(parts: [Part], ci: CIPack, template: TemplatePack, project: [String: String],
                products: [Product], style: IsoStyle? = nil, dimensions: Bool = true) {
        self.parts = parts; self.ci = ci; self.template = template; self.project = project
        self.products = products; self.style = style; self.dimensions = dimensions
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
    var highlight: Set<String> = []
    var fit: [Part]?
    var product = ""
    var step = (0, 0)

    public init(parts: [Part], ci: CIPack, template: TemplatePack, project: [String: String],
                layout: SheetLayout, iso: ViewSpec = ViewSpec(kind: .iso), dimensions: Bool = true, style: IsoStyle? = nil) {
        self.parts = parts; self.ci = ci; self.template = template; self.project = project
        self.layout = layout; self.iso = iso; self.dimensions = dimensions; self.style = style
    }
}
