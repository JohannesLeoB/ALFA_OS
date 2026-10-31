import Foundation

public enum ExportValue: Hashable, Sendable {
    case null
    case integer(Int64)
    case real(Double)
    case text(String)
    case blob(Data)
}

public typealias ExportRow = [String: ExportValue]

public struct ExportRawMail: Equatable, Sendable {
    public var inlet: String
    public var id: String
    public var data: Data

    public init(inlet: String, id: String, data: Data) {
        self.inlet = inlet
        self.id = id
        self.data = data
    }
}

public struct ExportFile: Equatable, Sendable {
    public var path: String
    public var data: Data

    public init(path: String, data: Data) {
        self.path = path
        self.data = data
    }
}

public struct ExportSource: Sendable {
    public var generatedAt: Date
    public var settings: [String: Data]
    public var contacts: Data?
    public var templates: [String]
    public var tables: [ExportTable: [ExportRow]]
    public var rawMails: [ExportRawMail]

    public init(generatedAt: Date, settings: [String: Data] = [:], contacts: Data? = nil, templates: [String] = [],
                tables: [ExportTable: [ExportRow]] = [:], rawMails: [ExportRawMail] = []) {
        self.generatedAt = generatedAt
        self.settings = settings
        self.contacts = contacts
        self.templates = templates
        self.tables = tables
        self.rawMails = rawMails
    }
}

public enum ExportFailure: Error, Equatable, Sendable {
    case unreadable
    case tooLarge
    case unwritable
}
