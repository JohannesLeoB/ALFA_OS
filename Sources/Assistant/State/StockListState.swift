public enum StockListState: Sendable, Equatable {
    case loading
    case items([StockItem])
    case empty
    case notConnected
    case failed(String)
}
