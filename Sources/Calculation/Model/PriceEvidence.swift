public struct PriceEvidence: Sendable, Equatable {
    public let supplier: String
    public let document: String
    public let page: Int?
    public let originalQuote: String
    public let netPrice: Double

    public init(supplier: String, document: String, page: Int?, originalQuote: String, netPrice: Double) {
        self.supplier = supplier
        self.document = document
        self.page = page
        self.originalQuote = originalQuote
        self.netPrice = netPrice
    }
}
