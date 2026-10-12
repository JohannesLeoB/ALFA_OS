import Foundation

public struct LagerItem: Codable, Sendable, Equatable, Identifiable {
    enum CodingKeys: String, CodingKey { case id, label = "bezeichnung", kategorie, hersteller, articleNumber = "artikelnummer", stock = "bestand", ekNetto, vkNetto, source = "quelle", notiz }

    public let id: String

    public let label: String

    public let kategorie: String?

    public let hersteller: String?

    public let articleNumber: String?

    public let stock: Int?

    public let ekNetto: Double?

    public let vkNetto: Double?

    public let source: String?

    public let notiz: String?

    public init(
        id: String,
        label: String,
        kategorie: String? = nil,
        hersteller: String? = nil,
        articleNumber: String? = nil,
        stock: Int? = nil,
        ekNetto: Double? = nil,
        vkNetto: Double? = nil,
        source: String? = nil,
        notiz: String? = nil
    ) {
        self.id = id
        self.label = label
        self.kategorie = kategorie
        self.hersteller = hersteller
        self.articleNumber = articleNumber
        self.stock = stock
        self.ekNetto = ekNetto
        self.vkNetto = vkNetto
        self.source = source
        self.notiz = notiz
    }

    public var normalisierteArtikelnummer: String {
        Self.normalisiereArtikelnummer(articleNumber ?? "")
    }

    public static func normalisiereArtikelnummer(_ nr: String) -> String {
        nr.uppercased()
            .filter { $0.isLetter || $0.isNumber }
    }
}
