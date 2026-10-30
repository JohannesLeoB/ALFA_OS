import Foundation

public struct MailboxSignature: Equatable, Sendable {
    public var text: String
    public var onNew: Bool
    public var aboveQuote: Bool

    public init(text: String, onNew: Bool = true, aboveQuote: Bool = false) {
        self.text = text
        self.onNew = onNew
        self.aboveQuote = aboveQuote
    }

    public var block: String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public var name: String? {
        block?.split(whereSeparator: \.isNewline).first.map(String.init)
    }
}
