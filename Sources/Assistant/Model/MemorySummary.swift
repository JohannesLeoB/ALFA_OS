import Foundation

public struct MemorySummary: Sendable, Equatable {
    let scopeKey: String
    let summaryText: String
    let coveredThroughMessageID: String
    let updatedAt: Date

    init(scopeKey: String, summaryText: String, coveredThroughMessageID: String, updatedAt: Date) {
        self.scopeKey = scopeKey
        self.summaryText = summaryText
        self.coveredThroughMessageID = coveredThroughMessageID
        self.updatedAt = updatedAt
    }
}
