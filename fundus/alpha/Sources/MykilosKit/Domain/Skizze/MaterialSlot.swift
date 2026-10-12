import Foundation

public enum SlotFarbe: String, Codable, CaseIterable, Sendable {
    case ultramarin, terracotta, salbei, ocker, graphit, taube

    public var display: String {
        switch self {
        case .ultramarin: return "Ultramarin"
        case .terracotta: return "Terracotta"
        case .salbei:     return "Salbei"
        case .ocker:      return "Ocker"
        case .graphit:    return "Graphit"
        case .taube:      return "Taube"
        }
    }
}

public enum MaterialArt: String, Codable, CaseIterable, Sendable {
    case material
    case geraet
    case stilAnker
    case upload

    public var label: String {
        switch self {
        case .material:  return "Material"
        case .geraet:    return "Gerät"
        case .stilAnker: return "Stil-Anker"
        case .upload:    return "Eigenes Bild"
        }
    }
    public var symbol: String {
        switch self {
        case .material:  return "square.stack.3d.up"
        case .geraet:    return "oven"
        case .stilAnker: return "photo.artframe"
        case .upload:    return "square.and.arrow.up"
        }
    }
}

public struct MaterialRef: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, displayName = "anzeigeName", promptText, bildRef, art }

    public let id: UUID
    public var displayName: String
    public var promptText: String
    public var bildRef: String?
    public var art: MaterialArt

    public init(id: UUID = UUID(), displayName: String, promptText: String,
                bildRef: String? = nil, art: MaterialArt) {
        self.id = id
        self.displayName = displayName
        self.promptText = promptText
        self.bildRef = bildRef
        self.art = art
    }
}

public struct MaterialSlot: Identifiable, Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case id, label, color = "farbe", zugeordnetesMaterial }

    public let id: UUID
    public var label: String
    public var color: SlotFarbe
    public var zugeordnetesMaterial: MaterialRef?

    public init(id: UUID = UUID(), label: String, color: SlotFarbe, zugeordnetesMaterial: MaterialRef? = nil) {
        self.id = id
        self.label = label
        self.color = color
        self.zugeordnetesMaterial = zugeordnetesMaterial
    }

    public static func standardSatz() -> [MaterialSlot] {
        let labels = ["Slot A", "Slot B", "Slot C", "Slot D", "Slot E", "Slot F"]
        return zip(labels, SlotFarbe.allCases).map { MaterialSlot(label: $0.0, color: $0.1) }
    }
}
