public protocol GoogleContactsPort: Sendable {
    func search(query: String) async throws -> [GoogleContact]
}
