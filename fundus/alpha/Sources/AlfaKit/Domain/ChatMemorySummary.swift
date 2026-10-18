import Foundation

public struct ChatMemorySummary: Sendable, Equatable {
    public let scopeKey: String
    public let summaryText: String

    public let coveredThroughMessageID: String
    public let updatedAt: Date

    public init(scopeKey: String, summaryText: String, coveredThroughMessageID: String, updatedAt: Date) {
        self.scopeKey = scopeKey
        self.summaryText = summaryText
        self.coveredThroughMessageID = coveredThroughMessageID
        self.updatedAt = updatedAt
    }
}
