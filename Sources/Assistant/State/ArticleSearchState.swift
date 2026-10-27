public enum ArticleSearchState: Sendable, Equatable {
    case loading(Int)
    case matches([Article])
    case empty
    case notConnected
    case failed(String)
}
