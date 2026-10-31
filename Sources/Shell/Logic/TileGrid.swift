import Design

public enum TileGrid {
    public static func columns(width: Double, minimum: Double, gap: Double) -> Int {
        guard width.isFinite, minimum > 0 else { return 1 }
        return max(1, Int(((width + gap) / (minimum + gap)).rounded(.down)))
    }

    public static func columnWidth(width: Double, count: Int, gap: Double) -> Double {
        (width - Double(count - 1) * gap) / Double(count)
    }

    public static func rowTops(top: Double, count: Int, columns: Int, height: Double, gap: Double) -> [Double] {
        let rows = columns > 0 ? (max(0, count) + columns - 1) / columns : 0
        return (0..<rows).map { top + Double($0) * (height + gap) }
    }

    public static func snap(_ proposed: Double, rows: [Double], inset: Double, limit: Double) -> Double {
        let ceiling = max(0, limit)
        return rows.map { min(ceiling, max(0, $0 - inset)) }.reduce(0) { abs($1 - proposed) < abs($0 - proposed) ? $1 : $0 }
    }

    public static func active(tops: [Double], offset: Double, reach: Double, viewport: Double, content: Double) -> Int {
        guard !tops.isEmpty else { return 0 }
        if offset > 0, offset + viewport >= content - 2 { return tops.count - 1 }
        return tops.lastIndex { $0 - offset <= reach } ?? 0
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

public enum CardStackEngine {
    public static func tops(count: Int) -> [Double] {
        var result: [Double] = []
        var next = Tokens.Spacing.step8
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
