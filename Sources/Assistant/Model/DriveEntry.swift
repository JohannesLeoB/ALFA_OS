import Foundation

public struct DriveEntry: Sendable, Equatable {
    public let id: String
    public let name: String
    public let mimeType: String
    public let isFolder: Bool
    public let typeLabel: String
    public let modifiedAt: Date?
    public let webViewLink: String?

    public init(id: String, name: String, mimeType: String = "", isFolder: Bool = false, typeLabel: String = "",
                modifiedAt: Date? = nil, webViewLink: String? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.isFolder = isFolder
        self.typeLabel = typeLabel
        self.modifiedAt = modifiedAt
        self.webViewLink = webViewLink
    }
}

public struct OfferListing: Sendable, Equatable {
    public struct Offer: Sendable, Equatable {
        public let file: DriveEntry
        public let typeLabel: String
        public let documentNumber: String?

        public init(file: DriveEntry, typeLabel: String, documentNumber: String? = nil) {
            self.file = file
            self.typeLabel = typeLabel
            self.documentNumber = documentNumber
        }
    }

    public let outgoing: [Offer]
    let incoming: [Offer]

    public init(outgoing: [Offer] = [], incoming: [Offer] = []) {
        self.outgoing = outgoing
        self.incoming = incoming
    }
}

public struct DriveLink: Codable, Sendable, Equatable, Identifiable {
    public let id: String
    var name: String
    var mimeType: String
    var webViewLink: String?
    var subtitle: Phrase?

    init(id: String, name: String, mimeType: String, webViewLink: String? = nil, subtitle: Phrase? = nil) {
        self.id = id
        self.name = name
        self.mimeType = mimeType
        self.webViewLink = webViewLink
        self.subtitle = subtitle
    }
}

public struct CalendarEntry: Sendable, Equatable {
    public let id: String
    public let title: String
    let startsAt: Date?
    public let isAllDay: Bool
    let location: String?
    var calendarTitle: String

    public init(id: String, title: String, startsAt: Date?, isAllDay: Bool = false, location: String? = nil,
                calendarTitle: String = "") {
        self.id = id
        self.title = title
        self.startsAt = startsAt
        self.isAllDay = isAllDay
        self.location = location
        self.calendarTitle = calendarTitle
    }
}

public struct CalendarRef: Sendable, Equatable {
    public let id: String
    public let title: String

    public init(id: String, title: String) {
        self.id = id
        self.title = title
    }
}

public struct MailHit: Sendable, Equatable {
    public let id: String
    let subject: String
    public let from: String
    let receivedAt: Date?
    let labels: [String]
    public let snippet: String
    public let attachmentNames: [String]

    public init(id: String, subject: String, from: String, receivedAt: Date?, labels: [String] = [],
                snippet: String = "", attachmentNames: [String] = []) {
        self.id = id
        self.subject = subject
        self.from = from
        self.receivedAt = receivedAt
        self.labels = labels
        self.snippet = snippet
        self.attachmentNames = attachmentNames
    }
}

struct Contact: Sendable, Equatable, Identifiable {
    public let id: String
    public var name: String
    var organization: String?
    var email: String?
    var phone: String?
    var address: String?
    var category: String?
    var project: String?

    init(id: String, name: String, organization: String? = nil, email: String? = nil, phone: String? = nil,
                address: String? = nil, category: String? = nil, project: String? = nil) {
        self.id = id
        self.name = name
        self.organization = organization
        self.email = email
        self.phone = phone
        self.address = address
        self.category = category
        self.project = project
    }

    func matches(_ query: String) -> Bool {
        let lowered = query.lowercased()
        return name.lowercased().contains(lowered)
            || (organization?.lowercased().contains(lowered) ?? false)
            || (project?.lowercased().contains(lowered) ?? false)
    }
}

public struct GoogleContact: Sendable, Equatable {
    let displayName: String
    let organization: String?
    let email: String?
    let phone: String?

    public init(displayName: String, organization: String? = nil, email: String? = nil, phone: String? = nil) {
        self.displayName = displayName
        self.organization = organization
        self.email = email
        self.phone = phone
    }
}
