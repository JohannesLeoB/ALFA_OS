import Foundation

public struct SevdeskMandantBefund: Sendable, Equatable {
    public let buchhaltungsVersion: String?

    public struct Vorlage: Sendable, Equatable {
        public let orderID: String
        public let orderNumber: String?

        public let contactID: String?
        public let contactPersonID: String?
        public let addressCountryID: String?
        public let taxRuleID: String?
        public let taxRate: Double?
        public let taxType: String?
        public let currency: String?

        public init(orderID: String, orderNumber: String? = nil, contactID: String? = nil,
                    contactPersonID: String? = nil,
                    addressCountryID: String? = nil, taxRuleID: String? = nil, taxRate: Double? = nil,
                    taxType: String? = nil, currency: String? = nil) {
            self.orderID = orderID; self.orderNumber = orderNumber
            self.contactID = contactID
            self.contactPersonID = contactPersonID; self.addressCountryID = addressCountryID
            self.taxRuleID = taxRuleID; self.taxRate = taxRate; self.taxType = taxType
            self.currency = currency
        }
    }
    public let template: Vorlage?

    public struct Einheit: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public init(id: String, name: String) { self.id = id; self.name = name }
    }
    public let einheiten: [Einheit]

    public let positionsSteuersatz: Double?

    public let naechsteBelegnummer: String?

    public let gaps: [String]

    public init(buchhaltungsVersion: String? = nil, template: Vorlage? = nil,
                einheiten: [Einheit] = [], positionsSteuersatz: Double? = nil,
                naechsteBelegnummer: String? = nil, gaps: [String] = []) {
        self.buchhaltungsVersion = buchhaltungsVersion
        self.template = template
        self.einheiten = einheiten
        self.positionsSteuersatz = positionsSteuersatz
        self.naechsteBelegnummer = naechsteBelegnummer
        self.gaps = gaps
    }

    public var wirksamerSteuersatz: Double? { positionsSteuersatz ?? template?.taxRate }

    public var istVollstaendig: Bool { gaps.isEmpty }
}

public enum SevdeskSendeKontextVorschlag {
    public static func aus(
        befund: SevdeskMandantBefund, einheitName: String, orderNumber: String? = nil,
        adresse: String? = nil
    ) -> SevdeskSendeKontext? {
        guard let template = befund.template,
              let contactPersonID = template.contactPersonID.flatMap(Int.init),
              let addressCountryID = template.addressCountryID.flatMap(Int.init),
              let taxRate = befund.wirksamerSteuersatz,
              let einheit = befund.einheiten.first(where: { $0.name.caseInsensitiveCompare(einheitName) == .orderedSame }),
              let unityID = Int(einheit.id)
        else { return nil }

        var einheiten: [String: Int] = [:]
        for einheit in befund.einheiten {
            if let id = Int(einheit.id) { einheiten[einheit.name] = id }
        }

        return SevdeskSendeKontext(

            orderNumber: orderNumber,
            contactPersonID: contactPersonID,
            addressCountryID: addressCountryID,
            taxRuleID: template.taxRuleID ?? "1",
            taxRate: taxRate,
            taxText: taxTextAus(taxRate: taxRate),
            standardUnityID: unityID,
            adresse: adresse,
            showNet: true,
            taxType: template.taxType ?? "default",
            einheiten: einheiten.isEmpty ? nil : einheiten
        )
    }

    static func taxTextAus(taxRate: Double) -> String {
        "Umsatzsteuer \(satzText(taxRate: taxRate))%"
    }

    public static func steuerKontextID(taxRate: Double) -> String {
        "DE_STANDARD_\(satzText(taxRate: taxRate))"
    }

    static func satzText(taxRate: Double) -> String {
        taxRate == taxRate.rounded() ? String(Int(taxRate)) : String(taxRate)
    }
}
