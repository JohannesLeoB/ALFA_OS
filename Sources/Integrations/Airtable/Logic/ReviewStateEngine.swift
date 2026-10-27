import Foundation

enum ReviewStateEngine {
    static let statusField = "Review-Status"
    static let confidenceField = "Konfidenz"
    static let sourceField = "Quell-Beleg"
    static let locationField = "Fundstelle"
    static let rawTextField = "Beleg-Rohtext"
    static let questionField = "Kl\u{00E4}rung offen"

    static func state(from fields: [String: FieldValue]) -> ReviewState? {
        guard let raw = fields[statusField]?.anyStringValue, let status = status(of: raw) else { return nil }
        return ReviewState(
            status: status,
            confidence: fields[confidenceField]?.numberValue,
            sourceDocument: trimmed(fields[sourceField]?.anyStringValue),
            location: trimmed(fields[locationField]?.anyStringValue),
            rawText: trimmed(fields[rawTextField]?.anyStringValue),
            openQuestion: trimmed(fields[questionField]?.anyStringValue))
    }

    static func status(of raw: String) -> ReviewState.Status? {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ungepr\u{00FC}ft", "ungeprueft": .unchecked
        case "verifiziert": .verified
        case "beanstandet": .disputed
        default: nil
        }
    }

    private static func trimmed(_ text: String?) -> String? {
        guard let text = text?.trimmingCharacters(in: .whitespacesAndNewlines), text.isEmpty == false else { return nil }
        return text
    }
}

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
