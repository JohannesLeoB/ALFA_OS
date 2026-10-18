import Foundation

public enum PlanElementArt: String, Codable, CaseIterable, Sendable {
    case line
    case polylinie
    case rechteck
    case text
    case bemassung

    public var displayName: String {
        switch self {
        case .line:     "Linie"
        case .polylinie: "Polylinie"
        case .rechteck:  "Rechteck"
        case .text:      "Text"
        case .bemassung: "Bemaßung"
        }
    }
}

public struct PlanElement: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, art, points = "punkte", layerID, text }

    public let id: String
    public var art: PlanElementArt

    public var points: [PlanPunkt]
    public var layerID: String

    public var text: String?

    public init(id: String = UUID().uuidString, art: PlanElementArt,
                points: [PlanPunkt], layerID: String, text: String? = nil) {
        self.id = id
        self.art = art
        self.points = points
        self.layerID = layerID
        self.text = text
    }

    public var eckPunkte: [PlanPunkt] {
        guard art == .rechteck, points.count == 2 else { return points }
        let a = points[0], b = points[1]
        return [
            a,
            PlanPunkt(x: b.x, y: a.y, z: a.z),
            b,
            PlanPunkt(x: a.x, y: b.y, z: b.z)
        ]
    }
}

public struct PlanLayer: Codable, Equatable, Sendable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, name, color = "farbe", isVisible = "sichtbar" }

    public let id: String
    public var name: String

    public var color: String
    public var isVisible: Bool

    public init(id: String = UUID().uuidString, name: String, color: String, isVisible: Bool = true) {
        self.id = id
        self.name = name
        self.color = color
        self.isVisible = isVisible
    }
}

public struct PlanDokument: Codable, Equatable, Sendable {
    enum CodingKeys: String, CodingKey { case title = "titel", projectNumber = "projektNummer", projektion, layer, elemente }

    public var title: String
    public var projectNumber: String?

    public var projektion: PlanProjektion
    public var layer: [PlanLayer]
    public var elemente: [PlanElement]

    public init(title: String = "", projectNumber: String? = nil,
                projektion: PlanProjektion = .elevation,
                layer: [PlanLayer] = PlanDokument.standardLayer,
                elemente: [PlanElement] = []) {
        self.title = title
        self.projectNumber = projectNumber
        self.projektion = projektion
        self.layer = layer
        self.elemente = elemente
    }

    public static var standardLayer: [PlanLayer] {
        [
            PlanLayer(name: "Gesamtmaße", color: "critical"),
            PlanLayer(name: "Wasser/Installation", color: "cash"),
            PlanLayer(name: "Details", color: "positive")
        ]
    }

    public var sichtbareElemente: [PlanElement] {
        let sichtbareIDs = Set(layer.filter(\.isVisible).map(\.id))
        return elemente.filter { sichtbareIDs.contains($0.layerID) }
    }

    public var papierRahmen: PlanPapierRahmen? {
        let points = sichtbareElemente.flatMap(\.eckPunkte)
        return PlanProjektor.papierRahmen(points, projektion: projektion)
    }
}
