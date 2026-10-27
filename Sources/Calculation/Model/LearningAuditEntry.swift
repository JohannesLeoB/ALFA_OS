import Foundation

struct LearningAuditEntry: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let entityID: String
    let entityTable: String
    let action: String
    let detail: String

    init(id: String = UUID().uuidString, createdAt: Date = Date(), entityID: String, entityTable: String, action: String, detail: String = "") {
        self.id = id
        self.createdAt = createdAt
        self.entityID = entityID
        self.entityTable = entityTable
        self.action = action
        self.detail = detail
    }
}
