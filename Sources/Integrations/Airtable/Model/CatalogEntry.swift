struct CatalogEntry: Equatable, Sendable {
    let id: String
    let articleNumber: String
    let manufacturer: String?
    let category: String?
    let summary: String?
    let detailText: String?
    let ean: String?
    let purchaseNet: Double?
    let saleNet: Double?
    let review: ReviewState?

    init(id: String, articleNumber: String, manufacturer: String? = nil, category: String? = nil,
         summary: String? = nil, detailText: String? = nil, ean: String? = nil, purchaseNet: Double? = nil,
         saleNet: Double? = nil, review: ReviewState? = nil) {
        self.id = id
        self.articleNumber = articleNumber
        self.manufacturer = manufacturer
        self.category = category
        self.summary = summary
        self.detailText = detailText
        self.ean = ean
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
        self.review = review
    }
}
