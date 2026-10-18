import Foundation

public enum Versanddienst: String, Codable, Sendable, CaseIterable, Equatable {
    case dhl, hermes, unbekannt

    public var label: String {
        switch self {
        case .dhl:       return "DHL"
        case .hermes:    return "Hermes"
        case .unbekannt: return "?"
        }
    }
}

public enum SendungsStatus: String, Codable, Sendable, CaseIterable, Equatable {
    case erfasst
    case imTransport
    case inZustellung
    case zugestellt
    case ausnahme
    case unbekannt

    public var fortschritt: Int {
        switch self {
        case .erfasst:      return 0
        case .imTransport:  return 1
        case .inZustellung: return 2
        case .zugestellt:   return 3
        case .ausnahme, .unbekannt: return -1
        }
    }

    public var label: String {
        switch self {
        case .erfasst:      return "Erfasst"
        case .imTransport:  return "Im Transport"
        case .inZustellung: return "In Zustellung"
        case .zugestellt:   return "Zugestellt"
        case .ausnahme:     return "Problem"
        case .unbekannt:    return "Unbekannt"
        }
    }
}

public struct Sendung: Codable, Sendable, Equatable, Identifiable {
    enum CodingKeys: String, CodingKey { case trackingNummer, dienst, label = "bezeichnung", status, statusText, projectNumber = "projektNummer" }

    public var trackingNummer: String
    public var dienst: Versanddienst

    public var label: String
    public var status: SendungsStatus

    public var statusText: String?

    public var projectNumber: String?

    public var id: String { trackingNummer }

    public init(trackingNummer: String, dienst: Versanddienst, label: String,
                status: SendungsStatus = .unbekannt, statusText: String? = nil,
                projectNumber: String? = nil) {
        self.trackingNummer = trackingNummer
        self.dienst = dienst
        self.label = label
        self.status = status
        self.statusText = statusText
        self.projectNumber = projectNumber
    }
}

public enum SendungsErkennung {
    public static func erkenneDienst(_ roh: String) -> Versanddienst {
        let n = roh.filter { !$0.isWhitespace }.uppercased()
        guard n.isEmpty == false else { return .unbekannt }
        if n.hasPrefix("JJD") || n.hasPrefix("GM") || n.hasPrefix("LX") { return .dhl }
        if n.hasPrefix("H"), n.dropFirst().allSatisfy(\.isNumber), n.count >= 8 { return .hermes }
        if n.allSatisfy(\.isNumber), (12...22).contains(n.count) { return .dhl }
        return .unbekannt
    }

    public static func normalisiere(_ roh: String) -> String {
        roh.filter { !$0.isWhitespace }.uppercased()
    }
}

public enum DHLStatusMapping {
    public static func status(ausCode code: String, text: String? = nil) -> SendungsStatus {
        if let t = text?.lowercased() {
            if t.contains("zustellung") || t.contains("out for delivery") || t.contains("in delivery") {
                return .inZustellung
            }
        }
        switch code.lowercased() {
        case "pre-transit":         return .erfasst
        case "transit":             return .imTransport
        case "delivered":           return .zugestellt
        case "failure":             return .ausnahme
        default:                    return .unbekannt
        }
    }
}
