import Foundation

public struct SevdeskOrderDraft: Sendable, Equatable, Codable {
    public struct Position: Sendable, Equatable, Codable {
        enum CodingKeys: String, CodingKey { case positionsnummer, label = "bezeichnung", quantity = "menge", vkNettoEinzel, herkunftsMatrix }

        public let positionsnummer: Int
        public let label: String
        public let quantity: Int
        public let vkNettoEinzel: Double
        public let herkunftsMatrix: String

        public init(positionsnummer: Int, label: String, quantity: Int, vkNettoEinzel: Double, herkunftsMatrix: String) {
            self.positionsnummer = positionsnummer
            self.label = label
            self.quantity = quantity
            self.vkNettoEinzel = vkNettoEinzel
            self.herkunftsMatrix = herkunftsMatrix
        }

        public var summeNetto: Double { Double(quantity) * vkNettoEinzel }
    }

    public let projectNumber: String
    public let kontaktReferenz: String
    public let title: String
    public let positionen: [Position]

    public init(projectNumber: String, kontaktReferenz: String, title: String, positionen: [Position]) {
        self.projectNumber = projectNumber
        self.kontaktReferenz = kontaktReferenz
        self.title = title
        self.positionen = positionen
    }

    public var summeNettoGesamt: Double {
        positionen.reduce(0) { $0 + $1.summeNetto }
    }
}

public enum SevdeskOrderDraftMapper {
    public static func draft(
        from basket: WorkBasket, kontaktReferenz: String, title: String
    ) -> (draft: SevdeskOrderDraft, ausgelasseneMenge: Int) {
        var positionen: [SevdeskOrderDraft.Position] = []
        var ausgelassen = 0
        for (index, pick) in basket.picks.enumerated() {
            guard let vk = pick.snapshot.vkEinzel else {
                ausgelassen += 1
                continue
            }
            positionen.append(SevdeskOrderDraft.Position(
                positionsnummer: index + 1,
                label: pick.snapshot.label,
                quantity: pick.snapshot.quantity,
                vkNettoEinzel: vk,
                herkunftsMatrix: pick.matrix.rawValue
            ))
        }
        let draft = SevdeskOrderDraft(
            projectNumber: basket.projectNumber, kontaktReferenz: kontaktReferenz,
            title: title, positionen: positionen)
        return (draft, ausgelassen)
    }
}
