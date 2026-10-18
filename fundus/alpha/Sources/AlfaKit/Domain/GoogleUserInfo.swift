import Foundation

public struct GoogleUserInfo: Equatable, Sendable, Codable {
    public var email: String
    public var displayName: String

    public init(email: String, displayName: String) {
        self.email = email
        self.displayName = displayName
    }

    public var domain: String? {
        let parts = email.components(separatedBy: "@")
        return parts.count == 2 ? parts[1] : nil
    }
}
