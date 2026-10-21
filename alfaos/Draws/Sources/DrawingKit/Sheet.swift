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
}

public enum SheetLayout: String, Codable, Sendable, CaseIterable { case threeView, iso }

public struct Request: Sendable {
    public var parts: [Part]
    public var ci: CIPack
    public var template: TemplatePack
    public var project: [String: String]
    public var layout: SheetLayout
    public var iso: ViewSpec
    public var dimensions: Bool

    public init(parts: [Part], ci: CIPack, template: TemplatePack, project: [String: String],
                layout: SheetLayout, iso: ViewSpec = ViewSpec(kind: .iso), dimensions: Bool = true) {
        self.parts = parts; self.ci = ci; self.template = template; self.project = project
        self.layout = layout; self.iso = iso; self.dimensions = dimensions
    }
}
