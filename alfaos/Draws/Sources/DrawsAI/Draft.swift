import Assist
import CoreGraphics
import DrawingKit
import DrawsRender
import Foundation

public struct Dials: Sendable, Equatable {
    public var azimuth: ClosedRange<Double>
    public var elevation: ClosedRange<Double>
    public var edge: ClosedRange<Double>
    public var outline: ClosedRange<Double>
    public var shadow: ClosedRange<Double>

    public init(azimuth: ClosedRange<Double>, elevation: ClosedRange<Double>, edge: ClosedRange<Double>,
                outline: ClosedRange<Double>, shadow: ClosedRange<Double>) {
        self.azimuth = azimuth; self.elevation = elevation; self.edge = edge; self.outline = outline; self.shadow = shadow
    }
}

public struct Bench: Sendable {
    public var ci: CIPack
    public var template: TemplatePack
    public var material: MaterialPack?
    public var fonts: SheetFonts
    public var project: [String: String]
    public var variants: [Variant]
    public var blocks: [Panel]
    public var kinds: [String]
    public var distance: Double
    public var dials: Dials
    public var dpi: Double
    public var preset: @Sendable (String, [Part]) -> [Cell]

    public init(ci: CIPack, template: TemplatePack, material: MaterialPack?, fonts: SheetFonts, project: [String: String],
                variants: [Variant], blocks: [Panel], kinds: [String], distance: Double, dials: Dials, dpi: Double,
                preset: @escaping @Sendable (String, [Part]) -> [Cell]) {
        self.ci = ci; self.template = template; self.material = material; self.fonts = fonts; self.project = project
        self.variants = variants; self.blocks = blocks; self.kinds = kinds; self.distance = distance; self.dials = dials
        self.dpi = dpi; self.preset = preset
    }
}

public struct Draft: Sendable, Equatable {
    public var parts: [Part]
    public var units: [DrawingKit.Unit]
    public var pose: [String: Double]
    public var layout: String
    public var cells: [Cell]
    public var azimuth: Double
    public var elevation: Double
    public var faces: [String]
    public var tone: Bool
    public var edge: Double
    public var outline: Double
    public var shadow: Double
    public var accent: String?
    public var accentColor: String?
    public var dimensions: Bool
    public var look = Look()

    public init(parts: [Part], units: [DrawingKit.Unit], pose: [String: Double], layout: String, cells: [Cell],
                azimuth: Double, elevation: Double, faces: [String], tone: Bool, edge: Double, outline: Double,
                shadow: Double, accent: String?, accentColor: String?, dimensions: Bool) {
        self.parts = parts; self.units = units; self.pose = pose; self.layout = layout; self.cells = cells
        self.azimuth = azimuth; self.elevation = elevation; self.faces = faces; self.tone = tone; self.edge = edge
        self.outline = outline; self.shadow = shadow; self.accent = accent; self.accentColor = accentColor
        self.dimensions = dimensions
    }

    public func seeded(by master: StyleMaster, dials: Dials) -> Draft {
        var next = self
        func pick(_ key: String, _ range: ClosedRange<Double>) -> Double? {
            master.number(key).map { min(range.upperBound, max(range.lowerBound, $0)) }
        }
        next.azimuth = pick("azimuth", dials.azimuth) ?? next.azimuth
        next.elevation = pick("elevation", dials.elevation) ?? next.elevation
        next.edge = pick("edge", dials.edge) ?? next.edge
        next.outline = pick("outline", dials.outline) ?? next.outline
        next.shadow = pick("shadow", dials.shadow) ?? next.shadow
        if let color = master.text("accentColor"), Self.isColor(color) { next.accentColor = color }
        if let dims = master.text("dims") { next.dimensions = dims == DimMode.given.rawValue }
        if let fill = master.text("fill") { next.tone = fill != "material" }
        return next
    }

    static func isColor(_ value: String) -> Bool {
        value.count == 7 && value.hasPrefix("#") && value.dropFirst().allSatisfy(\.isHexDigit)
    }

    func isoStyle(_ ci: CIPack) -> IsoStyle {
        var s = ci.iso
        s.edge = edge
        s.outline = outline
        s.shadow = shadow / 100
        s.accent = accent
        s.accentColor = accentColor
        s.faces = tone ? faces : nil
        return s
    }

    func job(_ bench: Bench) -> Job {
        let size = parts.reduce(0.0) { max($0, $1.w, $1.d, $1.h) }
        let product: Product
        switch layout {
        case "presentation": product = .presentation
        case "cover": product = .cover
        default:
            product = .board(cells, ViewSpec(kind: .iso, azimuth: azimuth, elevation: elevation, distance: bench.distance * size))
        }
        return Job(parts: parts, ci: bench.ci, template: bench.template, project: bench.project, products: [product],
                   style: isoStyle(bench.ci), dimensions: dimensions, material: bench.material, variants: bench.variants,
                   dims: dimensions ? .given : .none, fonts: bench.fonts, blocks: bench.blocks, units: units,
                   pose: pose.filter { entry in units.contains { $0.id == entry.key } })
    }
}
