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
    /// Name of the colour field that the fill follows. `fill` keeps the last known value for when the field is gone.
    public var fillToken: String?
    /// Name of the colour field that the stroke follows. `stroke` keeps the last known value.
    public var strokeToken: String?
    public init(fill: String? = nil, stroke: String? = nil, strokeWidth: Double = 1, cornerRadius: Double = 0,
                fillToken: String? = nil, strokeToken: String? = nil) {
        self.fill = fill; self.stroke = stroke; self.strokeWidth = strokeWidth; self.cornerRadius = cornerRadius
        self.fillToken = fillToken; self.strokeToken = strokeToken
    }
}

/// Column grid of a frame, as in InDesign: columns, gutter, margins and a baseline grid.
/// It lives in the core because a frame stores it. The math is in `Geometry`.
public struct ColumnGrid: Codable, Hashable, Sendable {
    public var columns: Int
    public var gutter: Double
    public var marginLeft: Double, marginRight: Double, marginTop: Double, marginBottom: Double
    /// Distance between baselines. 0 turns the baseline grid off.
    public var baseline: Double
    /// Distance of the first baseline below the top margin.
    public var baselineStart: Double
    public init(columns: Int, gutter: Double, margin: Double, baseline: Double = 0, baselineStart: Double = 0) {
        self.columns = max(1, columns); self.gutter = gutter
        marginLeft = margin; marginRight = margin; marginTop = margin; marginBottom = margin
        self.baseline = baseline; self.baselineStart = baselineStart
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
    /// `grid` is the column grid of the frame, nil for none. `gridID` names a grid template.
    /// `guides` are the guides of the frame, nil for none.
    case frame(deviceID: String?, gridID: String?, scale: Double? = nil, grid: ColumnGrid? = nil, guides: [Guide]? = nil)
    /// A group with a title (zone). Its children lie geometrically inside it.
    /// `tint` names a zone colour token (`zone-*`); nil means the standard zone colour. Files without the field read as nil.
    case group(title: String, tint: String? = nil)
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
    /// Name of the colour field that a swatch follows. Its hex keeps the last known value. Only swatches use it.
    public var colorToken: String?
    public var tags: [String] = []
    public var source: Source?
    /// Notes pinned to the item or to a place on it. A file without the field reads as no notes.
    public var notes: [ItemNote] = []
    public init(id: ItemID = ItemID(), title: String, content: Content, rect: Rect, z: Int = 0, layerID: String = "standard", source: Source? = nil) {
        self.id = id; self.title = title; self.content = content; self.rect = rect; self.z = z; self.layerID = layerID; self.source = source
    }
    public var isContainer: Bool {
        switch content { case .frame, .group: true; default: false }
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, content, rect, z, layerID, locked, hidden, colorToken, tags, source, notes
    }

    /// Writes the fields as the synthesized encoder did. `notes` is written only when there are notes, so files
    /// without notes stay as they were.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(content, forKey: .content)
        try c.encode(rect, forKey: .rect)
        try c.encode(z, forKey: .z)
        try c.encode(layerID, forKey: .layerID)
        try c.encode(locked, forKey: .locked)
        try c.encode(hidden, forKey: .hidden)
        try c.encodeIfPresent(colorToken, forKey: .colorToken)
        try c.encode(tags, forKey: .tags)
        try c.encodeIfPresent(source, forKey: .source)
        if !notes.isEmpty { try c.encode(notes, forKey: .notes) }
    }

    /// Reads the fields as the synthesized decoder did, except `notes`, which may be missing in older files.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(ItemID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        content = try c.decode(Content.self, forKey: .content)
        rect = try c.decode(Rect.self, forKey: .rect)
        z = try c.decode(Int.self, forKey: .z)
        layerID = try c.decode(String.self, forKey: .layerID)
        locked = try c.decode(Bool.self, forKey: .locked)
        hidden = try c.decode(Bool.self, forKey: .hidden)
        colorToken = try c.decodeIfPresent(String.self, forKey: .colorToken)
        tags = try c.decode([String].self, forKey: .tags)
        source = try c.decodeIfPresent(Source.self, forKey: .source)
        notes = try c.decodeIfPresent([ItemNote].self, forKey: .notes) ?? []
    }
}

/// Who wrote a note. The assistant's notes show its name in the app; the user's notes show "you".
public enum NoteAuthor: String, Codable, Equatable, Sendable, CaseIterable {
    case user, assistant
}

/// The place of a note on its item: a point in fractions of the item's rectangle, from 0 to 1, origin at the top left.
/// A value outside 0 to 1 is cut to it when the anchor is made or read. NaN becomes 0.
public struct NoteAnchor: Codable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = Self.cut(x)
        self.y = Self.cut(y)
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.init(x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y))
    }

    static func cut(_ value: Double) -> Double {
        value.isNaN ? 0 : min(1, max(0, value))
    }
}

/// A note on an item. It is pinned to the item as a whole (`anchor` nil) or to a place on it.
/// The text is cut to `maxTextLength` characters and an item keeps at most `maxPerItem` notes when a file is read.
public struct ItemNote: Codable, Hashable, Sendable, Identifiable {
    /// Most notes that one item keeps. Notes beyond this are dropped when a file is read.
    public static let maxPerItem = 100
    /// Most characters of one note text. A longer text is cut when a file is read.
    public static let maxTextLength = 4000

    public var id: UUID
    public var text: String
    public var author: NoteAuthor
    public var createdAt: Date
    /// A resolved note stays on the item, shown as done.
    public var resolved: Bool
    /// The place on the item. nil means the item as a whole.
    public var anchor: NoteAnchor?

    public init(id: UUID = UUID(), text: String, author: NoteAuthor, createdAt: Date, resolved: Bool = false, anchor: NoteAnchor? = nil) {
        self.id = id; self.text = text; self.author = author; self.createdAt = createdAt; self.resolved = resolved; self.anchor = anchor
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
    /// Library folders, in the order of the list. They span all spaces.
    public var folders: [Folder] = []
    public init(title: String, spaces: [Space] = [Space(id: "start", name: "Start")], documentID: UUID = UUID(), createdAt: Date = Board.currentTime()) {
        self.title = title; self.spaces = spaces; self.documentID = documentID; self.createdAt = createdAt
    }
    /// Now, rounded down to whole milliseconds, so that a time written to a file and read back is equal.
    public static func currentTime() -> Date {
        Date(timeIntervalSince1970: (Date.now.timeIntervalSince1970 * 1000).rounded(.down) / 1000)
    }
}
