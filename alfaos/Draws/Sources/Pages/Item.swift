import CoreGraphics
import Foundation

public enum Anchor: String, Sendable { case start, middle, end }

public enum Align: String, Sendable { case left, center, right }

public enum FontRole: String, Sendable { case sans, mono }

public struct Paint: Sendable, Equatable {
    public var fill: String?
    public var stroke: String?
    public var width: Double
    public var dash: [Double]
    public var rotation: Double

    public init(fill: String? = nil, stroke: String? = nil, width: Double = 0, dash: [Double] = [], rotation: Double = 0) {
        self.fill = fill; self.stroke = stroke; self.width = width; self.dash = dash; self.rotation = rotation
    }
}

public enum Step: Sendable, Equatable {
    case move(CGPoint)
    case line(CGPoint)
    case curve(CGPoint, CGPoint, CGPoint)
    case close
}

public struct Run: Sendable, Equatable {
    public var text: String
    public var origin: CGPoint
    public var size: Double
    public var weight: Int
    public var color: String
    public var anchor: Anchor
    public var rotation: Double
    public var role: FontRole

    public init(_ text: String, origin: CGPoint, size: Double, weight: Int = 400, color: String,
                anchor: Anchor = .start, rotation: Double = 0, role: FontRole = .sans) {
        self.text = text; self.origin = origin; self.size = size; self.weight = weight; self.color = color
        self.anchor = anchor; self.rotation = rotation; self.role = role
    }
}

public struct Block: Sendable, Equatable {
    public var text: String
    public var frame: CGRect
    public var size: Double
    public var weight: Int
    public var color: String
    public var leading: Double
    public var align: Align
    public var role: FontRole

    public init(_ text: String, frame: CGRect, size: Double, weight: Int = 400, color: String,
                leading: Double = 0, align: Align = .left, role: FontRole = .sans) {
        self.text = text; self.frame = frame; self.size = size; self.weight = weight; self.color = color
        self.leading = leading; self.align = align; self.role = role
    }
}

public struct Picture: Sendable, Equatable {
    public var data: Data?
    public var url: URL?
    public var frame: CGRect
    public var opacity: Double

    public init(data: Data? = nil, url: URL? = nil, frame: CGRect, opacity: Double = 1) {
        self.data = data; self.url = url; self.frame = frame; self.opacity = opacity
    }

    var bytes: Data? {
        if let data { return data }
        guard let url, url.isFileURL else { return nil }
        return try? Data(contentsOf: url)
    }
}

public struct Transform: Sendable, Equatable {
    public var dx: Double
    public var dy: Double
    public var rotation: Double
    public var scale: Double
    public var clip: CGRect?

    public init(dx: Double = 0, dy: Double = 0, rotation: Double = 0, scale: Double = 1, clip: CGRect? = nil) {
        self.dx = dx; self.dy = dy; self.rotation = rotation; self.scale = scale; self.clip = clip
    }

    var matrix: CGAffineTransform {
        CGAffineTransform(translationX: dx, y: dy).rotated(by: rotation * .pi / 180).scaledBy(x: scale, y: scale)
    }
}

public enum Item: Sendable {
    case line(CGPoint, CGPoint, Paint)
    case rect(CGRect, Paint)
    case polygon([CGPoint], Paint)
    case path([Step], Paint)
    case text(Run)
    case textBlock(Block)
    case image(Picture)
    indirect case group(Transform, [Item])
}
