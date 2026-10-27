public struct GoogleContact: Sendable, Equatable {
    public let displayName: String
    public let organization: String?
    public let email: String?
    public let phone: String?

    public init(displayName: String, organization: String? = nil, email: String? = nil, phone: String? = nil) {
        self.displayName = displayName
        self.organization = organization
        self.email = email
        self.phone = phone
    }
}
