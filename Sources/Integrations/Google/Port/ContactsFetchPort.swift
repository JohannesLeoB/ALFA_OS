protocol ContactsFetchPort: Sendable {
    func searchContacts(query: String?) async throws -> [Contact]
    func allContacts() async throws -> [Contact]
}
