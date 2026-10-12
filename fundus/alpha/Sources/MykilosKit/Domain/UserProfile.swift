import Foundation

public struct UserProfile: Equatable, Sendable, Codable {
    public var displayName: String
    public var role: String
    public var updatedAt: Date

    public var clockodoUserID: String?
    public var googleDomain: String?

    public var userID: String?

    public var birthDate: Date?
    public var phone: String?
    public var department: String?
    public var bio: String?

    public init(
        displayName: String,
        role: String,
        updatedAt: Date = Date(),
        clockodoUserID: String? = nil,
        googleDomain: String? = nil,
        userID: String? = nil,
        birthDate: Date? = nil,
        phone: String? = nil,
        department: String? = nil,
        bio: String? = nil
    ) {
        self.displayName = displayName
        self.role = role
        self.updatedAt = updatedAt
        self.clockodoUserID = clockodoUserID
        self.googleDomain = googleDomain
        self.userID = userID
        self.birthDate = birthDate
        self.phone = phone
        self.department = department
        self.bio = bio
    }

    public static let empty = UserProfile(displayName: "", role: "", updatedAt: .distantPast)

    public var isComplete: Bool {
        displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
