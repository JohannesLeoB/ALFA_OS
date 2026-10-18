import Foundation

public enum DriveFolderCategory: String, CaseIterable, Sendable, Identifiable, Hashable {
    case angebote
    case zeichnungen
    case praesentation
    case infos

    public var id: String { rawValue }

    public var chipLabel: String {
        switch self {
        case .angebote:      "ANGEBOTE"
        case .zeichnungen:   "ZEICHNUNGEN"
        case .praesentation: "PRÄSENTATION"
        case .infos:         "INFOS"
        }
    }

    var keywords: [String] {
        switch self {
        case .angebote:      ["angebot", "rechnung", "kostenvoranschlag", "offer", "invoice"]
        case .zeichnungen:   ["plan", "plane", "plaene", "werkszeichnung", "werkzeichnung",
                              "zeichnung", "cad", "layout"]
        case .praesentation: ["prasentation", "praesentation", "presentation",
                              "rendering", "moodboard", "moodbord"]
        case .infos:         ["info", "schriftverkehr", "korrespondenz", "vorplanung"]
        }
    }

    static let matchOrder: [DriveFolderCategory] = [
        .angebote, .zeichnungen, .praesentation, .infos
    ]

    static func folded(_ name: String) -> String {
        name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                     locale: Locale(identifier: "de_DE"))
    }

    public static func category(forFolderName name: String?) -> DriveFolderCategory? {
        guard let name, name.isEmpty == false else { return nil }
        let folded = folded(name)
        for candidate in matchOrder
        where candidate.keywords.contains(where: { folded.contains($0) }) {
            return candidate
        }
        return nil
    }
}
