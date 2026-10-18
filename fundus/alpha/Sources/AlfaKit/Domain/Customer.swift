import Foundation

public struct Customer: Codable, Identifiable, Equatable, Sendable {
    public let id: UUID
    public var customerNumber: String
    public var name: String
    public var airtableRecordID: String?

    public var clockodoCustomerID: Int?

    public var sevDeskKontaktID: String?
    public var updatedAt: Date

    public init(id: UUID = UUID(), customerNumber: String, name: String,
                airtableRecordID: String? = nil, clockodoCustomerID: Int? = nil,
                sevDeskKontaktID: String? = nil,
                updatedAt: Date = Date()) {
        self.id = id
        self.customerNumber = customerNumber
        self.name = name
        self.airtableRecordID = airtableRecordID
        self.clockodoCustomerID = clockodoCustomerID
        self.sevDeskKontaktID = sevDeskKontaktID
        self.updatedAt = updatedAt
    }
}
