import Foundation

struct ReviewState: Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case unchecked
        case verified
        case disputed
    }

    let status: Status
    let confidence: Double?
    let sourceDocument: String?
    let location: String?
    let rawText: String?
    let openQuestion: String?

    init(status: Status, confidence: Double? = nil, sourceDocument: String? = nil, location: String? = nil,
         rawText: String? = nil, openQuestion: String? = nil) {
        self.status = status
        self.confidence = confidence
        self.sourceDocument = sourceDocument
        self.location = location
        self.rawText = rawText
        self.openQuestion = openQuestion
    }
}
