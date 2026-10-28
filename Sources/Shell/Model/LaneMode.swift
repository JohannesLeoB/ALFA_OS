public struct LaneMode: Sendable, Codable, Equatable {
    var preferred: [Double]
    var folded: [Bool]
    public var maximized: LaneKind?

    init(rest: Double) {
        preferred = [rest, 0, rest]
        folded = [false, false, false]
        maximized = nil
    }
}
