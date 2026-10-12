import Foundation

public struct ResidentIdentity: Equatable, Sendable, Codable {
    public var googleEmail: String

    public var userID: String

    public var displayName: String?

    public var clockodoUserID: String?

    public var clockodoEntwurfsTabelle: String?

    public var clickUpMemberID: String?

    public var airtableRecordID: String?
    public var updatedAt: Date

    public init(
        googleEmail: String,
        userID: String,
        displayName: String? = nil,
        clockodoUserID: String? = nil,
        clockodoEntwurfsTabelle: String? = nil,
        clickUpMemberID: String? = nil,
        airtableRecordID: String? = nil,
        updatedAt: Date = Date()
    ) {
        self.googleEmail = googleEmail
        self.userID = userID
        self.displayName = displayName
        self.clockodoUserID = clockodoUserID
        self.clockodoEntwurfsTabelle = clockodoEntwurfsTabelle
        self.clickUpMemberID = clickUpMemberID
        self.airtableRecordID = airtableRecordID
        self.updatedAt = updatedAt
    }

    public var hasValidKey: Bool {
        googleEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
    }
}
