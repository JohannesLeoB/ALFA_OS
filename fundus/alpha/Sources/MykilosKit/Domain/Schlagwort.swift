import Foundation

public enum SchlagwortAchse: String, Codable, Sendable, CaseIterable {
    case trade
    case material
    case raum
    case stil
    case cluster
    case frei

    public var title: String {
        switch self {
        case .trade:   return "Gewerk"
        case .material: return "Material"
        case .raum:     return "Raum"
        case .stil:     return "Stil"
        case .cluster:  return "Cluster"
        case .frei:     return "Freitext"
        }
    }
}

public enum SchlagwortQuelle: String, Codable, Sendable {
    case katalog
    case regel
    case claude
    case frei
}

public struct Schlagwort: Codable, Sendable, Identifiable, Hashable {
    enum CodingKeys: String, CodingKey { case id, name, achse, source = "quelle", synonymVon }

    public let id: String
    public var name: String
    public var achse: SchlagwortAchse
    public var source: SchlagwortQuelle

    public var synonymVon: String?

    public init(id: String, name: String, achse: SchlagwortAchse,
                source: SchlagwortQuelle, synonymVon: String? = nil) {
        self.id = id
        self.name = name
        self.achse = achse
        self.source = source
        self.synonymVon = synonymVon
    }

    public init(name: String, achse: SchlagwortAchse, source: SchlagwortQuelle,
                synonymVon: String? = nil) {
        self.init(id: Schlagwort.slug(achse: achse, name: name),
                  name: name, achse: achse, source: source, synonymVon: synonymVon)
    }

    public static func slug(achse: SchlagwortAchse, name: String) -> String {
        let isFolded = name
            .replacingOccurrences(of: "ä", with: "ae")
            .replacingOccurrences(of: "ö", with: "oe")
            .replacingOccurrences(of: "ü", with: "ue")
            .replacingOccurrences(of: "ß", with: "ss")
            .folding(options: .diacriticInsensitive, locale: .init(identifier: "de_DE"))
            .lowercased()
        var out = ""
        var letztesTrenn = false
        for ch in isFolded {
            if ch.isLetter || ch.isNumber {
                out.append(ch); letztesTrenn = false
            } else if !letztesTrenn {
                out.append("-"); letztesTrenn = true
            }
        }
        let kern = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return "\(achse.rawValue):\(kern.isEmpty ? "unbenannt" : kern)"
    }
}

public struct ArtikelSchlagwort: Codable, Sendable, Hashable {
    enum CodingKeys: String, CodingKey { case artikelID, schlagwortID, score, source = "quelle" }

    public let artikelID: String
    public let schlagwortID: String
    public var score: Double
    public var source: SchlagwortQuelle

    public init(artikelID: String, schlagwortID: String,
                score: Double = 1.0, source: SchlagwortQuelle) {
        self.artikelID = artikelID
        self.schlagwortID = schlagwortID
        self.score = score
        self.source = source
    }
}

public struct SchlagwortFacette: Sendable, Identifiable, Hashable {
    public let schlagwort: Schlagwort
    public let count: Int
    public var id: String { schlagwort.id }

    public init(schlagwort: Schlagwort, count: Int) {
        self.schlagwort = schlagwort
        self.count = count
    }
}
