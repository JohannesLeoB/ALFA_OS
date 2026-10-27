public protocol MailSearchPort: Sendable {
    func search(query: String, limit: Int) async throws -> [MailHit]
    func body(messageID: String) async throws -> String
}
