public enum CardStack {
    public static func tops(count: Int) -> [Double] {
        var result: [Double] = []
        var next = Design.Spacing.step8
        for index in 0..<count {
            result.append(next)
            next += (count - 1 - index) > 3 ? Design.Spacing.step8 : Design.Size.headerHeight
        }
        return result
    }

    public static func levelIndex(depth: Int) -> Int {
        min(depth, 5) - 1
    }
}

public enum OverviewSize: Equatable, Sendable, CaseIterable {
    case small
    case medium
    case large

    public var tileHeight: Double {
        switch self {
        case .small: Design.Size.overviewTileHeightSmall
        case .medium: Design.Size.overviewTileHeightMedium
        case .large: Design.Size.overviewTileHeightLarge
        }
    }

    public var tileMinWidth: Double {
        switch self {
        case .small: Design.Size.overviewTileMinWidthSmall
        case .medium: Design.Size.overviewTileMinWidthMedium
        case .large: Design.Size.overviewTileMinWidthLarge
        }
    }

    public var lines: Int {
        switch self {
        case .small: Design.Count.overviewLinesSmall
        case .medium: Design.Count.overviewLinesMedium
        case .large: Design.Count.overviewLinesLarge
        }
    }
}
