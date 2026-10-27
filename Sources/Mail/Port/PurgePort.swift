protocol PurgePort: Sendable {
    func supportsPurge() async throws -> Bool
    func purge(messageID: String) async throws
}
