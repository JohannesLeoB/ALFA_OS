public struct Participant: Identifiable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let address: String

    public var initials: String { PersonName.initials(name) }

    public var label: String { name.isEmpty ? PersonName.middle(address, limit: NameLimit.person) : name }

    public var chipLabel: String { name.isEmpty ? PersonName.middle(address, limit: NameLimit.chip) : name }

    public var detail: String { name.isEmpty ? "" : PersonName.middle(address, limit: NameLimit.personAddress) }

    public var full: String { name.isEmpty ? address : name + " \u{00B7} " + address }

    public var first: String {
        name.isEmpty ? PersonName.middle(address, limit: NameLimit.firstName)
            : String(name.split(whereSeparator: { $0.isWhitespace }).first ?? "")
    }
}

public enum RecipientGroup: Equatable, Sendable {
    case to
    case cc
    case none
}

public struct Recipients: Equatable, Sendable {
    public let to: [Participant]
    public let cc: [Participant]

    public var all: [Participant] { to + cc }

    public var summary: String { RecipientEngine.summary(all) }

    public var more: Int? { all.count > NameLimit.recipientsInline ? all.count - 1 : nil }

    public func group(at index: Int) -> RecipientGroup {
        if index == 0 { return .to }
        return index == to.count && !cc.isEmpty ? .cc : .none
    }
}

public enum RecipientField: String, CaseIterable, Sendable {
    case to
    case cc
    case bcc
}

public struct Suggestion: Identifiable, Equatable, Sendable {
    public var id: String { address.lowercased() }
    public let name: String
    public let address: String
    public let tag: SuggestionTag

    public var initials: String { PersonName.initials(name) }

    public var shown: String { PersonName.middle(address, limit: NameLimit.suggestionAddress) }
}

public enum SuggestionTag: Equatable, Sendable {
    case contact
    case sender

    public var key: String { self == .contact ? "mail.suggest.contact" : "mail.suggest.sender" }
}

public struct Contact: Identifiable, Equatable, Sendable, Codable {
    public var id: String
    public var name: String
    public var address: String
}
