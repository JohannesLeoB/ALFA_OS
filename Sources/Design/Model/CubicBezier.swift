public struct CubicBezier: Sendable, Equatable {
    public let x1: Double
    public let y1: Double
    public let x2: Double
    public let y2: Double

    public init(x1: Double, y1: Double, x2: Double, y2: Double) {
        self.x1 = x1
        self.y1 = y1
        self.x2 = x2
        self.y2 = y2
    }
}

public struct ColorValue: Sendable, Equatable {
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
}

public struct ShadowLayer: Sendable, Equatable {
    public let inset: Bool
    public let x: Double
    public let y: Double
    public let blur: Double
    public let spread: Double
    public let color: ColorValue

    public var isContour: Bool { !inset && blur == 0 && spread != 0 }

    public var reach: Double { inset ? 0 : blur + max(abs(x), abs(y)) + max(0, spread) }

    public static func reach(_ layers: [ShadowLayer]) -> Double { layers.map(\.reach).max() ?? 0 }
}
