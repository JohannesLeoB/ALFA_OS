import Foundation

public struct ThemeKey: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

public struct TextKey: Hashable, Sendable, ExpressibleByStringLiteral {
    public let rawValue: String
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
}

public enum TokenMode: Sendable, Hashable {
    case light
    case dark
}

public struct RGB: Sendable, Equatable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(_ red: Double, _ green: Double, _ blue: Double, _ alpha: Double) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let missing = RGB(1, 0, 1, 1)
}

public struct ShadowLayer: Sendable, Equatable {
    public let inset: Bool
    public let x: Double
    public let y: Double
    public let blur: Double
    public let spread: Double
    public let color: RGB

    public var isContour: Bool { !inset && blur == 0 && spread != 0 }
}

public struct CubicBezier: Sendable, Equatable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double
}

public struct TextStyle: Sendable, Equatable {
    public let size: Double
    public let lineHeight: Double
    public let weight: Int
    public let tracking: Double
    public let family: String
}
