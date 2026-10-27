public struct Article: Sendable, Equatable {
    public let id: String
    public let articleNumber: String
    public let manufacturer: String?
    public let summary: String?
    public let purchaseNet: Double?
    public let saleNet: Double?

    public init(id: String, articleNumber: String, manufacturer: String? = nil, summary: String? = nil,
                purchaseNet: Double? = nil, saleNet: Double? = nil) {
        self.id = id
        self.articleNumber = articleNumber
        self.manufacturer = manufacturer
        self.summary = summary
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
    }

    public var label: String { summary ?? articleNumber }
}
