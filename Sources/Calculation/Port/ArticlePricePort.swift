public protocol ArticlePricePort: Sendable {
    func purchaseNet(matching term: String) async -> Double?
}
