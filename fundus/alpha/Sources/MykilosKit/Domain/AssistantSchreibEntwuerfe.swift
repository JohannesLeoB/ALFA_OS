import Foundation

public struct TerminDraft: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case title = "titel", start, ende, ganztaegig, ort, beschreibung, gaeste }

    public var title: String
    public var start: Date
    public var ende: Date
    public var ganztaegig: Bool
    public var ort: String?
    public var beschreibung: String?
    public var gaeste: [String]

    public init(title: String, start: Date, ende: Date, ganztaegig: Bool = false,
                ort: String? = nil, beschreibung: String? = nil, gaeste: [String] = []) {
        self.title = title; self.start = start; self.ende = ende
        self.ganztaegig = ganztaegig; self.ort = ort
        self.beschreibung = beschreibung; self.gaeste = gaeste
    }
}

public enum TerminOutcome: Sendable, Equatable {
    case done(String)
    case failed(String)
}

public struct WarenkorbDraft: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case label = "bezeichnung", articleNumber = "artikelnummer", quantity = "menge", ekNetto, vkNetto, source = "quelle", artikelRecordID }

    public var label: String
    public var articleNumber: String
    public var quantity: Int
    public var ekNetto: Double?
    public var vkNetto: Double?
    public var source: String
    public var artikelRecordID: String?

    public init(label: String, articleNumber: String, quantity: Int = 1,
                ekNetto: Double? = nil, vkNetto: Double? = nil,
                source: String, artikelRecordID: String? = nil) {
        self.label = label; self.articleNumber = articleNumber
        self.quantity = quantity; self.ekNetto = ekNetto; self.vkNetto = vkNetto
        self.source = source; self.artikelRecordID = artikelRecordID
    }
}

public enum WarenkorbOutcome: Sendable, Equatable {
    case done(String)
    case failed(String)
}

public struct DateiDraft: Codable, Sendable, Equatable {
    enum CodingKeys: String, CodingKey { case fileName = "dateiname", format, title = "titel", content = "inhalt", projectNumber = "projektNummer" }

    public enum Format: String, Codable, Sendable, CaseIterable {
        case text, csv, pdf

        public var endung: String { self == .text ? "txt" : rawValue }

        public var mimeType: String {
            switch self {
            case .text: "text/plain"
            case .csv:  "text/csv"
            case .pdf:  "application/pdf"
            }
        }

        public var display: String {
            switch self {
            case .text: "Textdatei"
            case .csv:  "Tabelle (CSV)"
            case .pdf:  "PDF"
            }
        }
    }

    public var fileName: String
    public var format: Format
    public var title: String
    public var content: String

    public var projectNumber: String?

    public init(fileName: String, format: Format, title: String, content: String,
                projectNumber: String? = nil) {
        self.fileName = fileName; self.format = format
        self.title = title; self.content = content
        self.projectNumber = projectNumber
    }

    public var tabelle: [[String]] {
        content.split(separator: "\n", omittingEmptySubsequences: false)
            .map { rowItem in
                rowItem.split(separator: ";", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
            }
            .filter { $0.contains(where: { $0.isEmpty == false }) }
    }

    public var vollerName: String {
        fileName.lowercased().hasSuffix(".\(format.endung)")
            ? fileName
            : "\(fileName).\(format.endung)"
    }
}

public enum DateiOutcome: Sendable, Equatable {
    case done(String)
    case failed(String)
}
