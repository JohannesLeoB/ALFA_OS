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
