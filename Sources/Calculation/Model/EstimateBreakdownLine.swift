public struct EstimateBreakdownLine: Codable, Sendable, Equatable {
    public enum Kind: String, Codable, Sendable, Equatable {
        case estimated
        case fixed
        case open
    }

    public let label: Notice
    public let amountNet: Double?
    public let kind: Kind

    public init(label: Notice, amountNet: Double?, kind: Kind) {
        self.label = label
        self.amountNet = amountNet
        self.kind = kind
    }
}
