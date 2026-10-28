struct AreaRules: Sendable, Equatable {
    let minimum: [Double]
    let maximum: [Double?]
    let yield: [Int]

    init(minimum: [Double], maximum: [Double?] = [nil, nil, nil], yield: [Int] = [0, 1, 2]) {
        self.minimum = minimum
        self.maximum = maximum
        self.yield = yield
    }

    init(measure: Measure, limits: AreaLimits) {
        self.init(minimum: LaneKind.allCases.map { limits.minimum[$0] ?? measure.minimum[$0.index] },
                  maximum: LaneKind.allCases.map { limits.maximum[$0] })
    }
}
