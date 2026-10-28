import Foundation

public struct DraftSummary: Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        case mail
        case contact
        case task
        case appointment
        case cart
        case file
        case calendar
    }

    public let kind: Kind
    public let title: String
    public let line: String?

    init(kind: Kind, title: String, line: String? = nil) {
        self.kind = kind
        self.title = title
        self.line = line.flatMap { $0.isEmpty ? nil : $0 }
    }
}
