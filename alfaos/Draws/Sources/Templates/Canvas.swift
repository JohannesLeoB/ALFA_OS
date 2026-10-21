import CoreGraphics
import Foundation
import Intake

public enum Role: String, Sendable, Codable { case image, text, caption }

public enum Fit: String, Sendable, Codable { case fill, fit }

public struct Ink: Sendable, Equatable, Codable {
    public var size: Double
    public var color: String
    public var weight: Int?
    public var leading: Double?
    public var align: String?

    public init(size: Double, color: String, weight: Int? = nil, leading: Double? = nil, align: String? = nil) {
        self.size = size; self.color = color; self.weight = weight; self.leading = leading; self.align = align
    }
}

public struct Zone: Sendable, Equatable, Codable {
    public var name: String
    public var x: Double
    public var y: Double
    public var w: Double
    public var h: Double
    public var role: Role
    public var fit: Fit?
    public var ink: Ink?

    public init(name: String, x: Double, y: Double, w: Double, h: Double, role: Role, fit: Fit? = nil, ink: Ink? = nil) {
        self.name = name; self.x = x; self.y = y; self.w = w; self.h = h; self.role = role; self.fit = fit; self.ink = ink
    }

    public var rect: CGRect { CGRect(x: x, y: y, width: w, height: h) }
}

public struct Canvas: Sendable, Equatable, Codable {
    public var width: Double
    public var height: Double
    public var background: String?
    public var zones: [Zone]

    public init(width: Double, height: Double, background: String? = nil, zones: [Zone] = []) {
        self.width = width; self.height = height; self.background = background; self.zones = zones
    }

    public init?(book: Book) {
        guard let folio = book.spreads.first?.pages.first else { return nil }
        var zones: [Zone] = []
        for (index, frame) in folio.frames.enumerated() {
            let role: Role
            switch frame.kind {
            case .image: role = .image
            case .text: role = .text
            case .rect: continue
            }
            let name = frame.id.isEmpty ? "\(frame.kind.rawValue)\(index)" : frame.id
            zones.append(Zone(name: name, x: frame.rect.minX, y: frame.rect.minY, w: frame.rect.width, h: frame.rect.height, role: role,
                              fit: role == .image ? .fill : nil))
        }
        self.init(width: folio.size.width, height: folio.size.height, zones: zones)
    }

    public init?(_ item: Ingested) {
        switch item.kind {
        case .idml:
            guard let book = item.layout else { return nil }
            self.init(book: book)
        case .json:
            guard let loaded = try? JSONDecoder().decode(Canvas.self, from: Data(item.text.utf8)) else { return nil }
            self = loaded
        default:
            return nil
        }
    }

    public func ink(_ ink: Ink) -> Canvas {
        var out = self
        for index in out.zones.indices where out.zones[index].role != .image && out.zones[index].ink == nil { out.zones[index].ink = ink }
        return out
    }
}
