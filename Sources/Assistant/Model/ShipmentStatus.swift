public struct ShipmentStatus: Sendable, Equatable {
    public let number: String
    public let statusLabel: String
    public let detail: String?

    public init(number: String, statusLabel: String, detail: String? = nil) {
        self.number = number
        self.statusLabel = statusLabel
        self.detail = detail
    }
}
