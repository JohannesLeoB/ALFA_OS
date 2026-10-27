import Foundation

struct EstimateSession: Equatable, Identifiable, Sendable {
    let id: String
    let createdAt: Date
    let requestText: String
    let baseLowNet: Decimal
    let baseMidNet: Decimal
    let baseHighNet: Decimal
    let laborValueNet: Decimal
    let evidenceIDs: [String]
    let status: LearningStatus

    init(id: String = UUID().uuidString, createdAt: Date = Date(), requestText: String, baseLowNet: Decimal, baseMidNet: Decimal, baseHighNet: Decimal, laborValueNet: Decimal, evidenceIDs: [String], status: LearningStatus = .active) {
        self.id = id
        self.createdAt = createdAt
        self.requestText = requestText
        self.baseLowNet = baseLowNet
        self.baseMidNet = baseMidNet
        self.baseHighNet = baseHighNet
        self.laborValueNet = laborValueNet
        self.evidenceIDs = evidenceIDs
        self.status = status
    }
}
