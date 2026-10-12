import Foundation
import GRDB
import MykilosKit

struct ProfileRecord: Codable, FetchableRecord, PersistableRecord {
    static let databaseTableName = "userProfile"
    static let localID = "local"

    var id: String
    var displayName: String
    var role: String
    var updatedAt: Double
    var clockodoUserID: String?
    var googleDomain: String?

    var userID: String?

    var birthDate: Double?
    var phone: String?
    var department: String?
    var bio: String?

    init(from profile: UserProfile) {
        self.id = Self.localID
        self.displayName = profile.displayName
        self.role = profile.role
        self.updatedAt = profile.updatedAt.timeIntervalSince1970
        self.clockodoUserID = profile.clockodoUserID
        self.googleDomain = profile.googleDomain
        self.userID = profile.userID
        self.birthDate = profile.birthDate?.timeIntervalSince1970
        self.phone = profile.phone
        self.department = profile.department
        self.bio = profile.bio
    }

    func withUserID(_ newUserID: String) -> ProfileRecord {
        var copy = self
        copy.userID = newUserID
        return copy
    }

    func toDomain() -> UserProfile {
        UserProfile(
            displayName: displayName,
            role: role,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            clockodoUserID: clockodoUserID,
            googleDomain: googleDomain,
            userID: userID,
            birthDate: birthDate.map { Date(timeIntervalSince1970: $0) },
            phone: phone,
            department: department,
            bio: bio
        )
    }
}
