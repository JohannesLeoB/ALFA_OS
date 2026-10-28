public struct LaneWidths: Sendable, Equatable {
    public let leading: Double
    public let center: Double
    public let trailing: Double

    public var all: [Double] { [leading, center, trailing] }

    public func width(_ lane: LaneKind) -> Double {
        all[lane.index]
    }
}
