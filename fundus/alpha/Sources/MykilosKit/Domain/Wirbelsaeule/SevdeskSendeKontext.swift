import Foundation

public struct SevdeskSendeKontext: Sendable, Equatable, Codable {
    public let orderNumber: String?

    public let contactPersonID: Int

    public let addressCountryID: Int

    public let taxRuleID: String

    public let taxRate: Double

    public let taxText: String

    public let standardUnityID: Int

    public let adresse: String?

    public let showNet: Bool

    public let taxType: String

    public let fussText: String?

    public let einheiten: [String: Int]?

    public func unityID(fuerEinheit name: String?) -> Int {
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines),
              name.isEmpty == false,
              let match = einheiten?.first(where: {
                  $0.key.caseInsensitiveCompare(name) == .orderedSame
              })
        else { return standardUnityID }
        return match.value
    }

    public init(
        orderNumber: String? = nil,
        contactPersonID: Int,
        addressCountryID: Int,
        taxRuleID: String = "1",
        taxRate: Double,
        taxText: String,
        standardUnityID: Int,
        adresse: String? = nil,
        showNet: Bool = true,
        taxType: String = "default",
        fussText: String? = nil,
        einheiten: [String: Int]? = nil
    ) {
        self.orderNumber = orderNumber
        self.contactPersonID = contactPersonID
        self.addressCountryID = addressCountryID
        self.taxRuleID = taxRuleID
        self.taxRate = taxRate
        self.taxText = taxText
        self.standardUnityID = standardUnityID
        self.adresse = adresse
        self.showNet = showNet
        self.taxType = taxType
        self.fussText = fussText
        self.einheiten = einheiten
    }
}
