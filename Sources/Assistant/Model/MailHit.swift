import Foundation

public struct MailHit: Sendable, Equatable {
    public let id: String
    public let subject: String
    public let from: String
    public let receivedAt: Date?
    public let labels: [String]
    public let snippet: String
    public let attachmentNames: [String]

    public init(id: String, subject: String, from: String, receivedAt: Date?, labels: [String] = [],
                snippet: String = "", attachmentNames: [String] = []) {
        self.id = id
        self.subject = subject
        self.from = from
        self.receivedAt = receivedAt
        self.labels = labels
        self.snippet = snippet
        self.attachmentNames = attachmentNames
    }
}
