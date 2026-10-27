public struct WorkshopFactors: Equatable, Sendable {
    public var values: [String: Double]

    public init(_ values: [String: Double] = [:]) {
        self.values = values
    }
}
