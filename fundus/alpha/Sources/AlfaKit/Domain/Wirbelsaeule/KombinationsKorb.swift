import Foundation

public extension CatalogMatrix {
    var inhaltsArt: InhaltsArt {
        switch self {
        case .customer:           .kontakte
        case .projekt:         .gemischt
        case .artikel:         .artikel
        case .material:        .material
        case .lager:           .artikel
        case .image:            .images
        case .zeichnung:       .zeichnungen
        case .textblock:       .textbausteine
        case .notiz:           .textbausteine
        case .dienstleistung:  .artikel
        case .eingangsangebot: .dokumente
        case .angebot:         .dokumente
        case .aufgabe:         .aufgaben
        case .sonstige:        .gemischt
        }
    }
}

public extension InhaltsArt {
    static func abgeleitet(aus matrizen: Set<CatalogMatrix>) -> InhaltsArt {
        let arten = Set(matrizen.map(\.inhaltsArt))
        if arten.count == 1, let einzige = arten.first { return einzige }
        return .gemischt
    }
}

public extension WorkBasket {
    var abgeleiteteInhaltsArt: InhaltsArt {
        InhaltsArt.abgeleitet(aus: Set(picks.map(\.matrix)))
    }

    var inhaltsArtWeichtAb: Bool { inhaltsArt != abgeleiteteInhaltsArt }
}

public extension CatalogMatrix {
    init(source: String) {
        switch source {
        case "katalog":           self = .artikel
        case "angebot-eingehend": self = .eingangsangebot
        case "angebot-ausgehend": self = .angebot
        default:                  self = CatalogMatrix(rawValue: source) ?? .sonstige
        }
    }
}
