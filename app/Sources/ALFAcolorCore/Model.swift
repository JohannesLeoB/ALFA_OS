import Foundation

/// A rectangle in points (pt). The origin is at the top left, as in SwiftUI.
public struct Rect: Codable, Hashable, Sendable {
    public var x: Double, y: Double, w: Double, h: Double
    public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var center: (x: Double, y: Double) { (x + w / 2, y + h / 2) }
    public func contains(x px: Double, y py: Double) -> Bool { px >= x && px <= maxX && py >= y && py <= maxY }
    public func intersects(_ o: Rect) -> Bool { x < o.maxX && maxX > o.x && y < o.maxY && maxY > o.y }
}

/// Languages that a code card can carry. New languages come in through a renderer.
public enum CodeLanguage: String, Codable, Sendable, CaseIterable {
    case html, css, javascript, react, tailwind, swiftui, compose, flutter, java, other
}

/// Where an item comes from. Required for everything foreign: source and license stay with the item.
public struct Source: Codable, Hashable, Sendable {
    public var url: URL?
    public var file: String?
    public var license: String?
    public var via: String          // "paste", "pinterest", "screenshot", "bookmark", "file", "claude" …
    public var importedAt: Date
    public init(url: URL? = nil, file: String? = nil, license: String? = nil, via: String, importedAt: Date = .now) {
        self.url = url; self.file = file; self.license = license; self.via = via; self.importedAt = importedAt
    }
}

/// How an image sits in its area.
public enum ImageFit: String, Codable, Equatable, Sendable {
    /// All of the image is visible. Space may be left over on two sides.
    case fit
    /// The image covers the area. Parts of it may be cut off.
    case fill
}

/// The outline of a shape. An ellipse in a square is a circle. A line runs from the top left to the bottom right
/// corner of its rectangle.
public enum ShapeKind: String, Codable, Sendable, CaseIterable {
    case rectangle, capsule, ellipse, line
}

/// How a shape is painted. Colors are hex strings, as in `Content.swatch`; nil means none.
public struct ShapeStyle: Codable, Hashable, Sendable {
    public var fill: String?
    public var stroke: String?
    /// Width of the stroke in points.
    public var strokeWidth: Double
    /// Corner radius in points. Only a rectangle has corners.
    public var cornerRadius: Double
    public init(fill: String? = nil, stroke: String? = nil, strokeWidth: Double = 1, cornerRadius: Double = 0) {
        self.fill = fill; self.stroke = stroke; self.strokeWidth = strokeWidth; self.cornerRadius = cornerRadius
    }
}

/// The content of an item. An item has exactly one kind.
public enum Content: Codable, Hashable, Sendable {
    case code(language: CodeLanguage, files: [String: String], previewWidth: Double?)
    /// An image. `fit` is nil for the rule "no crop: fit, crop: fill"; the inspector sets it per image.
    case image(assetID: String, crop: Rect?, fit: ImageFit? = nil)
    case note(text: String)
    case swatch(hex: String, name: String?)
    case link(url: URL, note: String?)
    /// A frame: a view area at device size with an optional grid. `deviceID` may end in `-landscape` or `-portrait`.
    /// `scale` is the pixels per point of the frame (1 to 3). nil uses the first scale of the device.
    case frame(deviceID: String?, gridID: String?, scale: Double? = nil)
    /// A group with a title (zone). Its children lie geometrically inside it.
    case group(title: String)
    /// A drawn shape: rectangle, capsule, ellipse or line.
    case shape(kind: ShapeKind, style: ShapeStyle)
    /// Free text on the canvas. `style` names a text style: "heading", "body" or "caption". Another name reads as "body".
    case text(text: String, style: String)
}

/// The identity of an item. In JSON it is a plain string.
public struct ItemID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let raw: String
    public init(_ raw: String = UUID().uuidString) { self.raw = raw }
    public var description: String { raw }

    public init(from decoder: Decoder) throws {
        raw = try decoder.singleValueContainer().decode(String.self)
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(raw)
    }
}

/// An item on the canvas.
public struct Item: Identifiable, Codable, Hashable, Sendable {
    public var id: ItemID
    public var title: String
    public var content: Content
    public var rect: Rect
    public var z: Int
    public var layerID: String
    public var locked: Bool = false
    public var hidden: Bool = false
    public var tags: [String] = []
    public var source: Source?
    public init(id: ItemID = ItemID(), title: String, content: Content, rect: Rect, z: Int = 0, layerID: String = "standard", source: Source? = nil) {
        self.id = id; self.title = title; self.content = content; self.rect = rect; self.z = z; self.layerID = layerID; self.source = source
    }
    public var isContainer: Bool {
        switch content { case .frame, .group: true; default: false }
    }
}

public struct Layer: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var visible = true
    public var locked = false
    public init(id: String, name: String) { self.id = id; self.name = name }
}

/// A topic space (tab). It has its own layers and items.
public struct Space: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var layers: [Layer]
    public var items: [Item]
    public init(id: String, name: String, layers: [Layer] = [Layer(id: "standard", name: "Standard")], items: [Item] = []) {
        self.id = id; self.name = name; self.layers = layers; self.items = items
    }
}

/// The document. On disk it is a folder package. See `DocumentPackage` in the Document module.
public struct Board: Codable, Hashable, Sendable {
    public static let formatVersion = 2
    public var format = Board.formatVersion
    /// Stays the same for the life of the document, across saves, copies of the file and sync.
    public var documentID: UUID
    /// When the document was made. The file keeps whole milliseconds.
    public var createdAt: Date
    public var title: String
    public var spaces: [Space]
    public init(title: String, spaces: [Space] = [Space(id: "start", name: "Start")], documentID: UUID = UUID(), createdAt: Date = Board.currentTime()) {
        self.title = title; self.spaces = spaces; self.documentID = documentID; self.createdAt = createdAt
    }
    /// Now, rounded down to whole milliseconds, so that a time written to a file and read back is equal.
    public static func currentTime() -> Date {
        Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 * 1000).rounded(.down) / 1000)
    }
}
