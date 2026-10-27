public struct StockItem: Sendable, Equatable {
    public let id: String
    public let label: String
    public let manufacturer: String?
    public let category: String?
    public let articleNumber: String?
    public let quantity: Int?
    public let purchaseNet: Double?
    public let saleNet: Double?

    public init(id: String, label: String, manufacturer: String? = nil, category: String? = nil,
                articleNumber: String? = nil, quantity: Int? = nil, purchaseNet: Double? = nil, saleNet: Double? = nil) {
        self.id = id
        self.label = label
        self.manufacturer = manufacturer
        self.category = category
        self.articleNumber = articleNumber
        self.quantity = quantity
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
    }
}
