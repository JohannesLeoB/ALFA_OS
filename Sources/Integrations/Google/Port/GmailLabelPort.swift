protocol GmailLabelPort: Sendable {
    func modifyLabels(messageID: String, add: [String], remove: [String]) async throws
    func trashMessage(messageID: String) async throws
    func listLabels() async throws -> [GmailLabel]
}

extension GmailLabelPort {
    func markSpam(messageID: String) async throws {
        try await modifyLabels(messageID: messageID, add: [GmailSystemLabel.spam], remove: [GmailSystemLabel.inbox])
    }
}
