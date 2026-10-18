import Foundation

public enum ArtikelReviewStatus: String, CaseIterable, Sendable, Equatable, Codable {
    case ungeprueft
    case verifiziert
    case beanstandet

    public var airtableWert: String {
        switch self {
        case .ungeprueft:  return "Ungeprüft"
        case .verifiziert: return "Verifiziert"
        case .beanstandet: return "Beanstandet"
        }
    }

    public init?(airtable roh: String) {
        switch roh.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "ungeprüft", "ungeprueft": self = .ungeprueft
        case "verifiziert":             self = .verifiziert
        case "beanstandet":             self = .beanstandet
        default:                        return nil
        }
    }
}

public struct ArtikelReviewZustand: Sendable, Equatable, Codable {
    public let status: ArtikelReviewStatus
    public let konfidenz: Double?
    public let quellBeleg: String?
    public let fundstelle: String?
    public let belegRohtext: String?
    public let klaerungOffen: String?

    public init(
        status: ArtikelReviewStatus, konfidenz: Double? = nil, quellBeleg: String? = nil,
        fundstelle: String? = nil, belegRohtext: String? = nil, klaerungOffen: String? = nil
    ) {
        self.status = status
        self.konfidenz = konfidenz
        self.quellBeleg = quellBeleg
        self.fundstelle = fundstelle
        self.belegRohtext = belegRohtext
        self.klaerungOffen = klaerungOffen
    }
}

public enum ArtikelReviewEntscheidung: Sendable, Equatable {
    case bereitsGeprueft

    case autoBestaetigen

    case dialogNoetig

    case beanstandet
}

public enum ArtikelReviewGate {
    public static let standardSchwelle: Double = 0.9

    public static func entscheide(
        _ status: ArtikelReviewZustand, schwelle: Double = standardSchwelle
    ) -> ArtikelReviewEntscheidung {
        switch status.status {
        case .verifiziert:
            return .bereitsGeprueft
        case .beanstandet:
            return .beanstandet
        case .ungeprueft:
            if let k = status.konfidenz, k >= schwelle { return .autoBestaetigen }
            return .dialogNoetig
        }
    }
}
