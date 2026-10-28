import Foundation

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
