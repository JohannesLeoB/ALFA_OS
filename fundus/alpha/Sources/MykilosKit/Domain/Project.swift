import Foundation

public enum ProjectKind: String, Codable, Sendable, CaseIterable {
    case kitchen
    case lighting
    case addendum
    case lead
    case quote
    case studioInternal
}

public struct ProjectLinks: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case driveFolderID, driveFolderPath, driveFolderName = "driveOrdnername", clickUpListID, calendarQuery, contactsQuery, mailQuery, sevdeskRef, budget }

    public var driveFolderID: String?
    public var driveFolderPath: String?

    public var driveFolderName: String?
    public var clickUpListID: String?
    public var calendarQuery: String?
    public var contactsQuery: String?
    public var mailQuery: String?
    public var sevdeskRef: String?
    public var budget: Double?

    public init(driveFolderID: String? = nil, driveFolderPath: String? = nil,
                driveFolderName: String? = nil,
                clickUpListID: String? = nil, calendarQuery: String? = nil,
                contactsQuery: String? = nil, mailQuery: String? = nil,
                sevdeskRef: String? = nil, budget: Double? = nil) {
        self.driveFolderID = driveFolderID
        self.driveFolderPath = driveFolderPath
        self.driveFolderName = driveFolderName
        self.clickUpListID = clickUpListID
        self.calendarQuery = calendarQuery
        self.contactsQuery = contactsQuery
        self.mailQuery = mailQuery
        self.sevdeskRef = sevdeskRef
        self.budget = budget
    }
}

public struct Project: Codable, Identifiable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, projectNumber, title, kind, customerNumber, parentProjectNumber, links, phase, source = "quelle", airtableRecordID, updatedAt }

    public let id: UUID
    public var projectNumber: String
    public var title: String
    public var kind: ProjectKind
    public var customerNumber: String
    public var parentProjectNumber: String?
    public var links: ProjectLinks
    public var phase: String?

    public var source: String?
    public var airtableRecordID: String?
    public var updatedAt: Date

    public var isAddendum: Bool { kind == .addendum || parentProjectNumber != nil }

    public init(id: UUID = UUID(), projectNumber: String, title: String,
                kind: ProjectKind, customerNumber: String,
                parentProjectNumber: String? = nil, links: ProjectLinks = .init(),
                phase: String? = nil, source: String? = nil,
                airtableRecordID: String? = nil,
                updatedAt: Date = Date()) {
        self.id = id
        self.projectNumber = projectNumber
        self.title = title
        self.kind = kind
        self.customerNumber = customerNumber
        self.parentProjectNumber = parentProjectNumber
        self.links = links
        self.phase = phase
        self.source = source
        self.airtableRecordID = airtableRecordID
        self.updatedAt = updatedAt
    }
}
