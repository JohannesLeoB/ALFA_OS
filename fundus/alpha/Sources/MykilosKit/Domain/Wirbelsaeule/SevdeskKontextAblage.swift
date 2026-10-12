import Foundation

public struct SevdeskKontextAblage: Sendable, Equatable, Codable {
    public let kontext: SevdeskSendeKontext
    public let sondiertAm: Date

    public let buchhaltungsVersion: String?

    public init(kontext: SevdeskSendeKontext, sondiertAm: Date, buchhaltungsVersion: String? = nil) {
        self.kontext = kontext
        self.sondiertAm = sondiertAm
        self.buchhaltungsVersion = buchhaltungsVersion
    }
}

public struct SevdeskKontextSpeicher: Sendable {
    public static let key = "sevdesk.sendekontext"

    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    public func save(_ store: SevdeskKontextAblage) throws {
        defaults.set(try JSONEncoder().encode(store), forKey: Self.key)
    }

    public func load() -> SevdeskKontextAblage? {
        guard let data = defaults.data(forKey: Self.key) else { return nil }

        return try? JSONDecoder().decode(SevdeskKontextAblage.self, from: data)
    }

    public func loesche() { defaults.removeObject(forKey: Self.key) }

    public func kontextFuerNeuenBeleg(adresse: String?, fussText: String?) -> SevdeskSendeKontext? {
        load().map { Self.fuerNeuenBeleg($0.kontext, adresse: adresse, fussText: fussText) }
    }

    public static func fuerNeuenBeleg(
        _ kontext: SevdeskSendeKontext, adresse: String?, fussText: String?
    ) -> SevdeskSendeKontext {
        SevdeskSendeKontext(
            orderNumber: nil,
            contactPersonID: kontext.contactPersonID,
            addressCountryID: kontext.addressCountryID,
            taxRuleID: kontext.taxRuleID,
            taxRate: kontext.taxRate,
            taxText: kontext.taxText,
            standardUnityID: kontext.standardUnityID,
            adresse: adresse,
            showNet: kontext.showNet,
            taxType: kontext.taxType,
            fussText: fussText,
            einheiten: kontext.einheiten
        )
    }
}
