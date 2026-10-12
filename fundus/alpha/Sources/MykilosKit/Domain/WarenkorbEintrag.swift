import Foundation

public struct WarenkorbEintrag: Sendable, Equatable, Identifiable {
    public let id: String

    public let label: String

    public let projekt: String?

    public let status: String

    public let version: Int

    public let erstelltAm: Date?

    public let anzahlPositionen: Int?

    public let totalEK: Double?

    public let totalVk: Double?

    public let positionenJSON: String?

    public var istAktuell: Bool { status == "Aktuell" }

    public init(
        id: String,
        label: String,
        projekt: String? = nil,
        status: String = "Aktuell",
        version: Int = 1,
        erstelltAm: Date? = nil,
        anzahlPositionen: Int? = nil,
        totalEK: Double? = nil,
        totalVk: Double? = nil,
        positionenJSON: String? = nil
    ) {
        self.id = id
        self.label = label
        self.projekt = projekt
        self.status = status
        self.version = version
        self.erstelltAm = erstelltAm
        self.anzahlPositionen = anzahlPositionen
        self.totalEK = totalEK
        self.totalVk = totalVk
        self.positionenJSON = positionenJSON
    }

    public func decodedItems() -> [WarenkorbItem]? {
        guard let json = positionenJSON,
              let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([WarenkorbItem].self, from: data)
    }
}
