protocol ContactsFetchPort: Sendable {
    func searchContacts(query: String?) async throws -> [Contact]
}
