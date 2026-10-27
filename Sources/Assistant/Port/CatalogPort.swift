public protocol CatalogPort: Sendable {
    func search(term: String, limit: Int) async -> ArticleSearchState
}
