import Foundation

public enum LayerArt: String, Codable, CaseIterable, Sendable {
    case stock, neu, entfernen, notiz

    public var label: String {
        switch self {
        case .stock:   return "Bestand"
        case .neu:       return "Neu"
        case .entfernen: return "Entfernen"
        case .notiz:     return "Notiz"
        }
    }

    public var symbol: String {
        switch self {
        case .stock:   return "square.dashed"
        case .neu:       return "plus.square.on.square"
        case .entfernen: return "minus.square"
        case .notiz:     return "note.text"
        }
    }

    public var wirdExportiert: Bool { self != .notiz }
}

public struct SkizzenLayer: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, name, art, isVisible = "sichtbar", gesperrt, deckkraft, objekte }

    public let id: UUID
    public var name: String
    public var art: LayerArt
    public var isVisible: Bool
    public var gesperrt: Bool
    public var deckkraft: Double
    public var objekte: [SkizzenObjekt]

    public init(id: UUID = UUID(), name: String, art: LayerArt, isVisible: Bool = true,
                gesperrt: Bool = false, deckkraft: Double = 1, objekte: [SkizzenObjekt] = []) {
        self.id = id
        self.name = name
        self.art = art
        self.isVisible = isVisible
        self.gesperrt = gesperrt
        self.deckkraft = deckkraft
        self.objekte = objekte
    }

    public static func standardSatz() -> [SkizzenLayer] {
        [
            SkizzenLayer(name: "Neu", art: .neu),
            SkizzenLayer(name: "Bestand", art: .stock, isVisible: true),
            SkizzenLayer(name: "Entfernen", art: .entfernen),
            SkizzenLayer(name: "Notizen", art: .notiz)
        ]
    }

    public static func neu(name: String, art: LayerArt = .neu, vorhandene: [SkizzenLayer]) -> SkizzenLayer {
        let sauber = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalerName = sauber.isEmpty ? "Layer \(vorhandene.count + 1)" : sauber
        return SkizzenLayer(name: finalerName, art: art)
    }
}
