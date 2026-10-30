import Design

public enum CardStackEngine {
    public static func tops(count: Int, start: Double = Tokens.Spacing.step8) -> [Double] {
        var result: [Double] = []
        var next = start
        for index in 0..<count {
            result.append(next)
            next += (count - 1 - index) > Tokens.Count.stackHeads ? Tokens.Spacing.step8 : Tokens.Size.headerHeight
        }
        return result
    }

    public static func levelIndex(depth: Int) -> Int {
        min(depth, Tokens.stackLight.count) - 1
    }

    public static func metaOpacity(depth: Int) -> Double {
        levelIndex(depth: depth) >= Tokens.stackLight.count - 2 ? Tokens.Opacity.cardMetaDeep : Tokens.Opacity.cardMeta
    }
}

public enum OverviewSize: Equatable, Sendable, CaseIterable {
    case small
    case medium
    case large

    public var tileHeight: Double {
        switch self {
        case .small: Tokens.Size.overviewTileHeightSmall
        case .medium: Tokens.Size.overviewTileHeightMedium
        case .large: Tokens.Size.overviewTileHeightLarge
        }
    }

    public var tileMinWidth: Double {
        switch self {
        case .small: Tokens.Size.overviewTileMinWidthSmall
        case .medium: Tokens.Size.overviewTileMinWidthMedium
        case .large: Tokens.Size.overviewTileMinWidthLarge
        }
    }

    public var lines: Int {
        switch self {
        case .small: Tokens.Count.overviewLinesSmall
        case .medium: Tokens.Count.overviewLinesMedium
        case .large: Tokens.Count.overviewLinesLarge
        }
    }
}
