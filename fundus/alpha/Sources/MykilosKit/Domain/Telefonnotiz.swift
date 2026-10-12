import Foundation

public enum TelefonRichtung: String, Codable, CaseIterable, Sendable {
    case eingehend, ausgehend

    public var label: String {
        switch self {
        case .eingehend: "hat angerufen"
        case .ausgehend: "angerufen"
        }
    }
}

public struct Telefonnotiz: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, projectNumber = "projektNummer", kontakt, richtung, content = "inhalt", folgeAufgabe, erfasstVon, date = "datum" }

    public let id: String
    public let projectNumber: String

    public var kontakt: String
    public var richtung: TelefonRichtung

    public var content: String

    public var folgeAufgabe: String?
    public let erfasstVon: String
    public let date: Date

    public init(id: String = UUID().uuidString, projectNumber: String, kontakt: String,
                richtung: TelefonRichtung = .eingehend, content: String,
                folgeAufgabe: String? = nil, erfasstVon: String, date: Date = Date()) {
        self.id = id
        self.projectNumber = projectNumber
        self.kontakt = kontakt
        self.richtung = richtung
        self.content = content
        self.folgeAufgabe = folgeAufgabe
        self.erfasstVon = erfasstVon
        self.date = date
    }

    public var kurzfassung: String {
        let ersteZeile = content
            .split(separator: "\n", omittingEmptySubsequences: true)
            .first.map(String.init)?.trimmingCharacters(in: .whitespaces) ?? ""
        if let folge = folgeAufgabe, folge.isEmpty == false {
            return ersteZeile.isEmpty ? "→ \(folge)" : "\(ersteZeile) · → \(folge)"
        }
        return ersteZeile
    }
}
