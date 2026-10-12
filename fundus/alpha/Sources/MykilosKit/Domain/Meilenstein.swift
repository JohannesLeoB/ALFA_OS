import Foundation

public enum MeilensteinStatus: String, Codable, CaseIterable, Sendable, Identifiable {
    case offen
    case erreicht
    case verschoben
    case entfaellt

    public var id: String { rawValue }
    public var label: String {
        switch self {
        case .offen:      return "Offen"
        case .erreicht:   return "Erreicht"
        case .verschoben: return "Verschoben"
        case .entfaellt:  return "Entfällt"
        }
    }

    public var istOffen: Bool { self == .offen || self == .verschoben }
}

public struct Meilenstein: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", title = "titel", notiz, date = "datum", status, erstelltAm, aktualisiertAm }

    public let id: String
    public let projectNumber: String
    public var title: String
    public var notiz: String?
    public var date: Date
    public var status: MeilensteinStatus
    public var erstelltAm: Date
    public var aktualisiertAm: Date

    public init(
        id: String = UUID().uuidString,
        projectNumber: String,
        title: String,
        notiz: String? = nil,
        date: Date,
        status: MeilensteinStatus = .offen,
        erstelltAm: Date = Date(),
        aktualisiertAm: Date = Date()
    ) {
        self.id = id
        self.projectNumber = projectNumber
        self.title = title
        self.notiz = notiz
        self.date = date
        self.status = status
        self.erstelltAm = erstelltAm
        self.aktualisiertAm = aktualisiertAm
    }
}

public enum MeilensteinAuswertung {
    public static func chronologisch(_ m: [Meilenstein]) -> [Meilenstein] {
        m.sorted { $0.date < $1.date }
    }

    public static func offeneAnzahl(_ m: [Meilenstein]) -> Int {
        m.filter { $0.status.istOffen }.count
    }

    public static func next(_ m: [Meilenstein], jetzt: Date = Date()) -> Meilenstein? {
        chronologisch(m.filter { $0.status.istOffen && $0.date >= jetzt }).first
    }

    public static func ueberfaellig(_ m: [Meilenstein], jetzt: Date = Date()) -> [Meilenstein] {
        m.filter { $0.status.istOffen && $0.date < jetzt }
    }
}
