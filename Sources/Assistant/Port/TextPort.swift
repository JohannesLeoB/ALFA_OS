public protocol TextPort: Sendable {
    func text(_ key: String, _ arguments: [String]) -> String
}
