import Foundation

public enum TileGrid {
    public static func columns(width: Double, minimum: Double, gap: Double) -> Int {
        guard width.isFinite, minimum > 0 else { return 1 }
        return max(1, Int(((width + gap) / (minimum + gap)).rounded(.down)))
    }

    public static func columnWidth(width: Double, count: Int, gap: Double) -> Double {
        (width - Double(count - 1) * gap) / Double(count)
    }
}
