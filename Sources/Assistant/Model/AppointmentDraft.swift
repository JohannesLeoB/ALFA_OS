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
