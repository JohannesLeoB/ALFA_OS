public struct ContactDraft: Codable, Sendable, Equatable {
    var givenName: String
    var familyName: String?
    var email: String?
    var phone: String?
    var organization: String?

    init(givenName: String, familyName: String? = nil, email: String? = nil, phone: String? = nil,
         organization: String? = nil) {
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
        self.phone = phone
        self.organization = organization
    }

    var displayName: String {
        [givenName, familyName].compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}
