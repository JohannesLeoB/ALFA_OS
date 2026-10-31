import Foundation

public struct AppointmentDraft: Codable, Sendable, Equatable {
    var title: String
    var start: Date
    var end: Date
    var allDay: Bool
    var location: String?
    var details: String?
    var guests: [String]

    init(title: String, start: Date, end: Date, allDay: Bool = false, location: String? = nil,
         details: String? = nil, guests: [String] = []) {
        self.title = title
        self.start = start
        self.end = end
        self.allDay = allDay
        self.location = location
        self.details = details
        self.guests = guests
    }
}

public struct CartDraft: Codable, Sendable, Equatable {
    enum Source: String, Codable, Sendable { case catalog, stock }

    var label: String
    var articleNumber: String
    var quantity: Int
    var purchaseNet: Double?
    var saleNet: Double?
    var source: Source
    var recordID: String?

    init(label: String, articleNumber: String, quantity: Int = 1, purchaseNet: Double? = nil,
         saleNet: Double? = nil, source: Source, recordID: String? = nil) {
        self.label = label
        self.articleNumber = articleNumber
        self.quantity = quantity
        self.purchaseNet = purchaseNet
        self.saleNet = saleNet
        self.source = source
        self.recordID = recordID
    }
}

public struct FileDraft: Codable, Sendable, Equatable {
    enum Format: String, Codable, Sendable, CaseIterable {
        case text, csv, pdf

        var fileExtension: String { self == .text ? "txt" : rawValue }

        var mimeType: String {
            switch self {
            case .text: "text/plain"
            case .csv: "text/csv"
            case .pdf: "application/pdf"
            }
        }
    }

    var fileName: String
    var format: Format
    var title: String
    var content: String
    var projectNumber: String?
    var savedPath: String?

    init(fileName: String, format: Format, title: String, content: String, projectNumber: String? = nil,
         savedPath: String? = nil) {
        self.fileName = fileName
        self.format = format
        self.title = title
        self.content = content
        self.projectNumber = projectNumber
        self.savedPath = savedPath
    }

    var rows: [[String]] {
        content.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                line.split(separator: ";", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            .filter { $0.contains(where: { $0.isEmpty == false }) }
    }

    var fullName: String {
        fileName.lowercased().hasSuffix(".\(format.fileExtension)") ? fileName : "\(fileName).\(format.fileExtension)"
    }
}

public struct AirtableContactDraft: Codable, Sendable, Equatable {
    enum Intent: String, Codable, Sendable, Equatable {
        case create
        case update
    }

    var intent: Intent
    var recordID: String?
    var name: String
    var organization: String?
    var email: String?
    var phone: String?
    var address: String?
    var category: String?
    var project: String?

    init(intent: Intent, recordID: String? = nil, name: String, organization: String? = nil,
         email: String? = nil, phone: String? = nil, address: String? = nil, category: String? = nil,
         project: String? = nil) {
        self.intent = intent
        self.recordID = recordID
        self.name = name
        self.organization = organization
        self.email = email
        self.phone = phone
        self.address = address
        self.category = category
        self.project = project
    }
}

public struct ClickUpChangeDraft: Codable, Sendable, Equatable {
    public enum Intent: String, Codable, Sendable { case create, status, dueDate, assign }

    public var intent: Intent
    public var listID: String
    public var projectNumber: String
    public var taskID: String?
    public var taskName: String
    public var status: String?
    public var dueDate: Date?
    public var memberID: String?
    var memberName: String?

    public init(intent: Intent, listID: String, projectNumber: String, taskID: String? = nil, taskName: String,
                status: String? = nil, dueDate: Date? = nil, memberID: String? = nil, memberName: String? = nil) {
        self.intent = intent
        self.listID = listID
        self.projectNumber = projectNumber
        self.taskID = taskID
        self.taskName = taskName
        self.status = status
        self.dueDate = dueDate
        self.memberID = memberID
        self.memberName = memberName
    }
}

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

public struct MailDraft: Codable, Sendable, Equatable {
    var to: String?
    var cc: String?
    var bcc: String?
    var subject: String
    var body: String

    init(to: String? = nil, cc: String? = nil, bcc: String? = nil, subject: String, body: String) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
    }
}
