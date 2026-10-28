public struct AreaLimits: Sendable, Equatable {
    let minimum: [LaneKind: Double]
    let maximum: [LaneKind: Double]

    public init(minimum: [LaneKind: Double] = [:], maximum: [LaneKind: Double] = [:]) {
        self.minimum = minimum
        self.maximum = maximum
    }
}
