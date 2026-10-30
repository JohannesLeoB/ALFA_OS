public enum ContactSourceKind: String, CaseIterable, Sendable {
    case google
    case airtable
    case mail

    public var key: String { "settings.contacts.source." + rawValue }
}
