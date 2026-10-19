import Foundation

public enum SheetValues {
    public static let previewScreen = Size(width: 1512, height: 982)
    public static let pressScale = 0.96
    public static let releaseSamples = 6
    public static let releaseSpan = 0.016
    public static let pointerStep = 0.001
    public static let stretchPerSpeed = 0.00012
    public static let lidRestScale = 0.45
    public static let blinkScale = 0.1
    public static let winkScale = 0.08
    public static let winkCloseAt = 0.44
    public static let winkOpenAt = 0.68
    public static let labelMaxWidth = 200.0
    public static let iconSize = 14.0
    public static let iconBox = 16.0
    public static let iconStroke = 1.3
    public static let smallIconStroke = 1.5
    public static let iconOpacity = 0.8
    public static let placeholderOpacity = 0.45
    public static let mutedOpacity = 0.6
    public static let fieldOpacity = 0.8
    public static let tapeFadeAt = 0.4
    public static let pulseScale = 2.0
    public static let orbSpot = 0.58
    public static let orbOrbit = 0.24
    public static let orbGlossX = 0.35
    public static let orbGlossY = 0.28
    public static let orbGlossStop = 0.45
    public static let syncTurns = 2.0
    public static let syncErrorArc = 0.25
    public static let initialsTracking = 0.08
    public static let settingsTileHeight = 112.0
    public static let cardMetaOpacity = 0.72
    public static let cardCloseOpacity = 0.7
    public static let disabledOpacity = 0.4
    public static let gripCurve = CubicBezier(x1: 0.25, y1: 0.1, x2: 0.25, y2: 1)
    public static let searchGlyph = SearchGlyph(center: Point(x: 7, y: 7), radius: 5.5, from: Point(x: 11, y: 11), to: Point(x: 14.5, y: 14.5))
}

public struct SearchGlyph: Sendable, Equatable {
    public let center: Point
    public let radius: Double
    public let from: Point
    public let to: Point
}
