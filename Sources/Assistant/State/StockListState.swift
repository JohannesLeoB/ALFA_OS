public enum StockListState: Sendable, Equatable {
    case loading
    case items([StockItem])
    case empty
    case notConnected
    case failed(String)
}

public enum ArticleSearchState: Sendable, Equatable {
    case loading(Int)
    case matches([Article])
    case empty
    case notConnected
    case failed(String)
}
