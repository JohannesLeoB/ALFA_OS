import ALFAcolorCore

/// Where the context bar sits beside the selection. Plain geometry in canvas points.
public enum ContextBarPlacement {
    /// The box around all frames. Nil when there are none.
    public static func box(of frames: [Rect]) -> Rect? {
        guard let first = frames.first else { return nil }
        let minX = frames.reduce(first.x) { min($0, $1.x) }
        let minY = frames.reduce(first.y) { min($0, $1.y) }
        let maxX = frames.reduce(first.maxX) { max($0, $1.maxX) }
        let maxY = frames.reduce(first.maxY) { max($0, $1.maxY) }
        return Rect(x: minX, y: minY, w: maxX - minX, h: maxY - minY)
    }

    /// The center of a bar of the given size. The bar sits above the box, or below it when there is
    /// no room above, and stays inside the container at the sides.
    public static func center(of box: Rect, barWidth: Double, barHeight: Double,
                              containerWidth: Double, gap: Double) -> (x: Double, y: Double) {
        var top = box.y - gap - barHeight
        if top < 0 { top = box.maxY + gap }
        let left = min(max(box.center.x - barWidth / 2, 0), max(containerWidth - barWidth, 0))
        return (left + barWidth / 2, top + barHeight / 2)
    }
}
