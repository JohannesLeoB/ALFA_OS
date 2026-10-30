public struct ContactSource: Identifiable, Equatable, Sendable {
    public let id: String
    public let kind: ContactSourceKind
    public let account: String

    public init(id: String, kind: ContactSourceKind, account: String = "") {
        self.id = id
        self.kind = kind
        self.account = account
    }

    public static let airtable = ContactSource(id: ContactSourceKind.airtable.rawValue, kind: .airtable)

    public static let mail = ContactSource(id: ContactSourceKind.mail.rawValue, kind: .mail)

    public static func googleID(_ inlet: Inlet.ID) -> String { ContactSourceKind.google.rawValue + "." + inlet }

    public static func google(_ inlet: Inlet) -> ContactSource {
        ContactSource(id: googleID(inlet.id), kind: .google, account: inlet.account)
    }
}
