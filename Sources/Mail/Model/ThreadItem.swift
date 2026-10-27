public struct ThreadItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let address: String
    public let date: ThreadDate?
    public let text: String
    public let quote: Quote?
    public let quoteOpen: Bool
    public let current: Bool
}

public struct Quote: Equatable, Sendable {
    public let text: String
    public let lines: Int
}
