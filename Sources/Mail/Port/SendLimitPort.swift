public protocol SendLimitPort: Sendable {
    func sendLimit() async throws -> Int?
}
