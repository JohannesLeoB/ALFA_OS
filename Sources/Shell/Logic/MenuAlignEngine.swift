public enum MenuAlignEngine {
    public static func left(anchor: Double, anchorWidth: Double, width: Double, lanes: LaneWidths, measure: Measure, windowWidth: Double) -> Double {
        let all = lanes.all
        let lefts = measure.lefts(lanes)
        let index = measure.lane(at: anchor, lanes).index
        let start = lefts[index]
        let end = start + all[index]
        var x = anchor + anchorWidth / 2 < (start + end) / 2 ? anchor : anchor + anchorWidth - width
        if x < start && start + width <= end { x = start }
        if x + width > end && end - width >= start { x = end - width }
        return max(measure.margin, min(x, windowWidth - width - measure.margin))
    }
}
