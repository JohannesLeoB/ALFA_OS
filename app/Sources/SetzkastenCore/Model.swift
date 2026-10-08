import Foundation

/// Ein Rechteck in Punkten (pt). Ursprung oben links, wie in SwiftUI.
public struct Rect: Codable, Hashable, Sendable {
    public var x: Double, y: Double, w: Double, h: Double
    public init(x: Double, y: Double, w: Double, h: Double) { self.x = x; self.y = y; self.w = w; self.h = h }
    public var maxX: Double { x + w }
    public var maxY: Double { y + h }
    public var center: (x: Double, y: Double) { (x + w / 2, y + h / 2) }
    public func contains(x px: Double, y py: Double) -> Bool { px >= x && px <= maxX && py >= y && py <= maxY }
    public func intersects(_ o: Rect) -> Bool { x < o.maxX && maxX > o.x && y < o.maxY && maxY > o.y }
}

/// Sprachen, die eine Code-Karte tragen kann. Neue Sprachen kommen über einen Renderer dazu.
public enum CodeLanguage: String, Codable, Sendable, CaseIterable {
    case html, css, javascript, react, tailwind, swiftui, compose, flutter, java, other
}

/// Woher ein Stück kommt. Pflicht für alles Fremde: Herkunft und Lizenz bleiben am Stück.
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

/// Der Inhalt eines Elements. Ein Element hat genau eine Art.
public enum Content: Codable, Hashable, Sendable {
    case code(language: CodeLanguage, files: [String: String], previewWidth: Double?)
    case image(assetID: String, crop: Rect?)
    case note(text: String)
    case swatch(hex: String, name: String?)
    case link(url: URL, note: String?)
    /// Ein Rahmen: Ansichtsfläche in Gerätegröße mit optionalem Raster.
    case frame(deviceID: String?, gridID: String?)
    /// Eine Gruppe mit Titel (Zone). Ihre Kinder liegen geometrisch in ihr.
    case group(title: String)
}

public struct ItemID: Codable, Hashable, Sendable, CustomStringConvertible {
    public let raw: String
    public init(_ raw: String = UUID().uuidString) { self.raw = raw }
    public var description: String { raw }
}

/// Ein Element auf der Leinwand.
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

/// Ein Themenraum (Tab). Er hat eigene Ebenen und Elemente.
public struct Space: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var name: String
    public var layers: [Layer]
    public var items: [Item]
    public init(id: String, name: String, layers: [Layer] = [Layer(id: "standard", name: "Standard")], items: [Item] = []) {
        self.id = id; self.name = name; self.layers = layers; self.items = items
    }
}

/// Das Dokument. Auf der Platte ein Paket: Ordner mit manifest.json, items/, assets/.
public struct Board: Codable, Hashable, Sendable {
    public static let formatVersion = 1
    public var format = Board.formatVersion
    public var title: String
    public var spaces: [Space]
    public init(title: String, spaces: [Space] = [Space(id: "start", name: "Start")]) { self.title = title; self.spaces = spaces }
}
