public protocol StockPort: Sendable {
    func current() async -> StockListState
}
