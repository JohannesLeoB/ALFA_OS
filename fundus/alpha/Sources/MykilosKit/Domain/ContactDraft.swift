import Foundation

public struct ContactDraft: Codable, Sendable, Equatable {
    public var givenName: String
    public var familyName: String?
    public var email: String?
    public var phone: String?
    public var organization: String?

    public init(givenName: String, familyName: String? = nil, email: String? = nil,
                phone: String? = nil, organization: String? = nil) {
        self.givenName = givenName
        self.familyName = familyName
        self.email = email
        self.phone = phone
        self.organization = organization
    }

    public var displayName: String {
        [givenName, familyName].compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.isEmpty == false }
            .joined(separator: " ")
    }
}

public enum ContactCreateOutcome: Sendable, Equatable {
    case created(String)
    case failed(String)
}
